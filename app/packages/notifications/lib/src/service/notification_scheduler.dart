import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:notifications/src/data/notifications_repository.dart';
import 'package:notifications/src/models/notification_plan.dart';
import 'package:notifications/src/service/notification_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// {@template notification_tap}
/// A reminder the user tapped.
/// {@endtemplate}
class NotificationTap {
  /// {@macro notification_tap}
  const NotificationTap({
    this.threadSlug,
    this.eventId,
    this.title,
    this.confirmStart = false,
  });

  /// The conversation it was about, when it had one.
  final String? threadSlug;

  /// The block it was about, when it was about one.
  final String? eventId;

  /// What the reminder said, which for a block is the block's name.
  final String? title;

  /// Whether it asked the user to begin a block, which a tap answers.
  final bool confirmStart;
}

/// {@template notification_scheduler}
/// Keeps the device's notification queue a mirror of the server's plan.
///
/// The server decides when to fire and what to say. This only moves the
/// queue to match, and [sync] is safe to call as often as anything likes:
/// calls that land while one is running fold into a single rerun.
///
/// The queue is moved by difference rather than cleared and refilled. A
/// clear leaves a window with nothing queued, and if the fetch meant to
/// refill it fails the user silently gets no reminders until the next
/// launch. The difference never has that window: a failed sync leaves the
/// last good queue exactly where it was.
/// {@endtemplate}
class NotificationScheduler {
  /// {@macro notification_scheduler}
  NotificationScheduler({
    required this._repository,
    NotificationQueue? queue,
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
    bool? supported,
  }) : _queue = queue ?? LocalNotificationQueue(),
       _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now,
       _supported = supported ?? _platformSupported();

  /// How many reminders are queued at most.
  ///
  /// iOS keeps the 64 soonest per app and silently drops the rest. Sixty
  /// leaves headroom, and the plan is trimmed from the far end.
  static const maxQueued = 60;

  /// Whether the user has been asked for permission, so they never are twice.
  static const askedKey = 'notifications.permissionAsked';

  final NotificationsRepository _repository;
  final NotificationQueue _queue;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  final bool _supported;

  final _taps = StreamController<NotificationTap>.broadcast();

  Future<void>? _initialized;
  Future<void>? _running;
  bool _again = false;

  /// Reminders tapped while the app is running.
  Stream<NotificationTap> get taps => _taps.stream;

  /// Sets up the queue and the time zone database. Asks for nothing.
  Future<void> initialize() => _initialized ??= _initialize();

  Future<void> _initialize() async {
    if (!_supported) return;

    tz_data.initializeTimeZones();
    await _queue.initialize(
      onTap: (payload) => _taps.add(tapOf(payload)),
    );
  }

  /// The reminder that launched the app, if one did.
  Future<NotificationTap?> launchTap() async {
    if (!_supported) return null;
    await initialize();

    final payload = await _queue.launchPayload();
    return payload == null ? null : tapOf(payload);
  }

  /// Whether the user has not been asked yet and could be.
  Future<bool> shouldAskPermission() async {
    if (!_supported) return false;

    final preferences = await _preferences();
    return !(preferences.getBool(askedKey) ?? false);
  }

  /// Asks the user once, and syncs straight away if they said yes.
  ///
  /// Remembered whatever the answer, so a no is never asked again. Asking
  /// twice is how a no becomes permanent.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await initialize();

    final preferences = await _preferences();
    await preferences.setBool(askedKey, true);

    final granted = await _queue.requestPermission();
    if (granted) await sync();

    return granted;
  }

  /// Remembers that the user turned reminders down before the system was
  /// asked, so the question is not put to them again.
  Future<void> declinePermission() async {
    final preferences = await _preferences();
    await preferences.setBool(askedKey, true);
  }

  /// Moves the queue to match the server's plan.
  ///
  /// A no-op when reminders are not permitted. Errors are logged and
  /// swallowed: the queue is left as it was, which is the right place to
  /// leave it.
  Future<void> sync() {
    if (_running != null) {
      _again = true;
      return _running!;
    }

    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      try {
        await _syncOnce();
      } on Object catch (error, stackTrace) {
        log(
          'sync failed',
          name: 'notifications',
          error: error,
          stackTrace: stackTrace,
        );
      }
    } while (_again);
  }

  Future<void> _syncOnce() async {
    if (!_supported) return;
    await initialize();
    if (!await _queue.isPermitted()) return;

    final plan = await _repository.fetchPlan();
    final pending = await _queue.pendingIds();
    final location = locationOf(plan.timeZone);
    final diff = reconcile(plan.items, pending, _now());

    for (final id in diff.cancel) {
      await _queue.cancel(id);
    }

    for (final item in diff.schedule) {
      await _queue.schedule(
        QueuedNotification(
          id: queueIdOf(item.id),
          fireAt: tz.TZDateTime.from(item.fireAt, location),
          title: item.title,
          body: item.body,
          timeSensitive: item.timeSensitive,
          daily:
              item.kind == NotificationKind.morning ||
              item.kind == NotificationKind.evening,
          payload: payloadOf(item),
        ),
      );
    }

    log(
      'synced: ${diff.schedule.length} added, ${diff.cancel.length} removed',
      name: 'notifications',
    );
  }

  /// Stops listening. Only tests need this.
  Future<void> dispose() => _taps.close();

  static bool _platformSupported() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }
}

/// {@template queue_diff}
/// What has to change for the queue to match a plan.
/// {@endtemplate}
@immutable
class QueueDiff {
  /// {@macro queue_diff}
  const QueueDiff({required this.cancel, required this.schedule});

  /// Queued ids the plan no longer has.
  final Set<int> cancel;

  /// Planned reminders not yet queued.
  final List<PlannedNotification> schedule;
}

/// The change that makes [pending] match [items] at [now].
///
/// The plan is trimmed first: anything already past is skipped, and only
/// the [NotificationScheduler.maxQueued] soonest are kept. Anything queued
/// and still planned is left alone.
QueueDiff reconcile(
  List<PlannedNotification> items,
  Set<int> pending,
  DateTime now,
) {
  final ahead = items.where((item) => item.fireAt.isAfter(now)).toList()
    ..sort((a, b) => a.fireAt.compareTo(b.fireAt));

  final planned = <int, PlannedNotification>{};
  for (final item in ahead) {
    if (planned.length == NotificationScheduler.maxQueued) break;
    planned.putIfAbsent(queueIdOf(item.id), () => item);
  }

  return QueueDiff(
    cancel: pending.difference(planned.keys.toSet()),
    schedule: [
      for (final entry in planned.entries)
        if (!pending.contains(entry.key)) entry.value,
    ],
  );
}

/// The queue's integer id for the plan's string [id].
///
/// FNV-1a, because the queue wants a 32-bit integer and `String.hashCode`
/// is not promised to be the same from one launch to the next. The top bit
/// is dropped so the id stays positive, which Android asks for.
int queueIdOf(String id) {
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(id)) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }

  return hash & 0x7fffffff;
}

/// What a reminder carries back when it is tapped.
String payloadOf(PlannedNotification item) {
  return jsonEncode({
    'id': item.id,
    'kind': item.kind.name,
    'title': item.title,
    if (item.threadSlug != null) 'threadSlug': item.threadSlug,
    if (item.eventId != null) 'eventId': item.eventId,
  });
}

/// A tap, read off a reminder's payload.
NotificationTap tapOf(String? payload) {
  if (payload == null || payload.isEmpty) return const NotificationTap();

  try {
    final json = jsonDecode(payload);
    if (json is! Map<String, dynamic>) return const NotificationTap();

    final slug = json['threadSlug'];
    final eventId = json['eventId'];
    final title = json['title'];
    return NotificationTap(
      threadSlug: slug is String ? slug : null,
      eventId: eventId is String ? eventId : null,
      title: title is String ? title : null,
      confirmStart: json['kind'] == NotificationKind.confirmStart.name,
    );
  } on FormatException {
    return const NotificationTap();
  }
}

/// The zone named [name], or UTC when the database does not know it.
///
/// UTC is wrong for almost everyone, but the instants in a plan are absolute,
/// so a reminder still fires at the right moment. Only a trip across zones
/// would show the difference.
tz.Location locationOf(String name) {
  try {
    return tz.getLocation(name);
  } on tz.LocationNotFoundException {
    return tz.UTC;
  }
}
