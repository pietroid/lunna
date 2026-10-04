import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// {@template queued_notification}
/// One reminder as the operating system's queue holds it.
/// {@endtemplate}
class QueuedNotification {
  /// {@macro queued_notification}
  const QueuedNotification({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.timeSensitive,
    required this.daily,
    required this.payload,
  });

  /// The queue's own integer id.
  final int id;

  /// When it fires, on the wall clock of the user's calendar.
  final tz.TZDateTime fireAt;

  /// Final text.
  final String title;

  /// Final text.
  final String body;

  /// Whether it should break through a Focus mode.
  final bool timeSensitive;

  /// Whether it is one of the morning or evening reminders rather than a
  /// block's. Android files the two under separate channels.
  final bool daily;

  /// What comes back when it is tapped.
  final String payload;
}

/// The device's notification queue, reduced to what the scheduler needs.
///
/// An interface so the reconciliation can be tested without a platform
/// channel. [LocalNotificationQueue] is the one real implementation.
abstract interface class NotificationQueue {
  /// Sets the queue up, without asking for permission. [onTap] receives the
  /// payload of a reminder tapped while the app is running.
  Future<void> initialize({required void Function(String? payload) onTap});

  /// The payload of the reminder that launched the app, if one did.
  Future<String?> launchPayload();

  /// Whether reminders may be shown at all.
  Future<bool> isPermitted();

  /// Asks the user, and answers whether they said yes.
  Future<bool> requestPermission();

  /// The ids of every reminder still waiting to fire.
  Future<Set<int>> pendingIds();

  /// Queues [notification].
  Future<void> schedule(QueuedNotification notification);

  /// Takes the reminder with [id] off the queue.
  Future<void> cancel(int id);
}

/// {@template local_notification_queue}
/// [NotificationQueue] over `flutter_local_notifications`.
///
/// The only code in the app that touches the plugin.
/// {@endtemplate}
class LocalNotificationQueue implements NotificationQueue {
  /// {@macro local_notification_queue}
  LocalNotificationQueue({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _blocksChannel = AndroidNotificationChannel(
    'blocks',
    'Blocos',
    description: 'Quando um bloco começa e quando está perto de terminar.',
    importance: Importance.high,
  );

  static const _dailyChannel = AndroidNotificationChannel(
    'daily',
    'Bom dia e boa noite',
    description: 'Um recado no começo e no fim do dia.',
  );

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Nothing is asked for here. The prompt waits for the moment the
        // user does something a reminder would be for.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );

    await _android?.createNotificationChannel(_blocksChannel);
    await _android?.createNotificationChannel(_dailyChannel);
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;

    return details.notificationResponse?.payload;
  }

  @override
  Future<bool> isPermitted() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final options = await _ios?.checkPermissions();
      return options?.isEnabled ?? false;
    }

    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Critical alerts are not asked for: that entitlement is paid.
      return await _ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<Set<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return {for (final request in pending) request.id};
  }

  @override
  Future<void> schedule(QueuedNotification notification) async {
    final channel = notification.daily ? _dailyChannel : _blocksChannel;
    final exact = await _android?.canScheduleExactNotifications() ?? false;

    await _plugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      scheduledDate: notification.fireAt,
      payload: notification.payload,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: notification.daily
              ? Priority.defaultPriority
              : Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          // Shown while the app is open too: the app is not the only place
          // the user is looking.
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          interruptionLevel: notification.timeSensitive
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
