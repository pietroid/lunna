import 'package:equatable/equatable.dart';

/// What a reminder is for.
///
/// [confirmStart], [starting] and [almostFinishing] follow a block.
/// [morning] and [evening] follow the clock, once each every day.
enum NotificationKind {
  /// A flexible block's hour came, and it waits for the user to begin it.
  confirmStart,

  /// A fixed block begins.
  starting,

  /// A block ends in a few minutes.
  almostFinishing,

  /// The day begins.
  morning,

  /// The day is nearly over.
  evening;

  /// The kind named [name] on the wire, or null for one this build does not
  /// know, which is skipped rather than guessed at.
  static NotificationKind? fromName(Object? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// {@template planned_notification}
/// One reminder the device should have queued, exactly as the server wrote
/// it.
///
/// Nothing about it is decided on the phone. The title and body are final
/// text, and [id] is what the queue is reconciled by.
/// {@endtemplate}
class PlannedNotification extends Equatable {
  /// {@macro planned_notification}
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.fireAt,
    required this.title,
    required this.body,
    this.timeSensitive = false,
    this.threadSlug,
    this.eventId,
  });

  /// Reads one item of the plan, or null when it is unusable.
  static PlannedNotification? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final kind = NotificationKind.fromName(json['kind']);
    final fireAt = DateTime.tryParse(json['fireAt'] as String? ?? '');
    final title = json['title'];
    final body = json['body'];

    if (id is! String || id.isEmpty) return null;
    if (kind == null || fireAt == null) return null;
    if (title is! String || body is! String) return null;

    final slug = json['threadSlug'];
    final eventId = json['eventId'];
    return PlannedNotification(
      id: id,
      kind: kind,
      fireAt: fireAt.toUtc(),
      title: title,
      body: body,
      timeSensitive: json['timeSensitive'] == true,
      threadSlug: slug is String && slug.isNotEmpty ? slug : null,
      eventId: eventId is String && eventId.isNotEmpty ? eventId : null,
    );
  }

  /// Stable across syncs. Anything that changes what it says or when it
  /// fires changes it.
  final String id;

  /// What it is for.
  final NotificationKind kind;

  /// The instant it fires, in UTC.
  final DateTime fireAt;

  /// Final text.
  final String title;

  /// Final text.
  final String body;

  /// Whether it should break through a Focus mode.
  final bool timeSensitive;

  /// The conversation a tap opens, when there is one.
  final String? threadSlug;

  /// The block it is about, when it is about one.
  final String? eventId;

  @override
  List<Object?> get props => [
    id,
    kind,
    fireAt,
    title,
    body,
    timeSensitive,
    threadSlug,
    eventId,
  ];
}

/// {@template notification_plan}
/// Every reminder ahead, soonest first, and the zone they were written in.
/// {@endtemplate}
class NotificationPlan extends Equatable {
  /// {@macro notification_plan}
  const NotificationPlan({required this.timeZone, required this.items});

  /// Reads the server's plan, dropping any item that does not parse.
  factory NotificationPlan.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = <PlannedNotification>[
      if (raw is List)
        for (final item in raw)
          if (item is Map<String, dynamic>) ?PlannedNotification.fromJson(item),
    ];

    return NotificationPlan(
      timeZone: json['timeZone'] as String? ?? 'UTC',
      items: items,
    );
  }

  /// The IANA zone of the user's calendar.
  final String timeZone;

  /// Every reminder, soonest first.
  final List<PlannedNotification> items;

  @override
  List<Object?> get props => [timeZone, items];
}
