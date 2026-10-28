import 'package:equatable/equatable.dart';

/// What a reminder is for.
///
/// [askStart], [askEnd] and [headsUp] follow a block, and ask: their
/// buttons answer for it. [morning] and [evening] follow the clock, once
/// each every day.
enum NotificationKind {
  /// A block's hour came: a task waits to be begun, a fixed block started.
  askStart,

  /// A block's end came: is it over?
  askEnd,

  /// A fixed block is a quarter of an hour away, and something runs right
  /// up to it.
  headsUp,

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

/// Whether the card a reminder asks about is a task or a fixed block, which
/// picks the route its buttons post to.
enum NotificationCard {
  /// A task, begun or not.
  task,

  /// A fixed block.
  event;

  /// The card named [name] on the wire, or null.
  static NotificationCard? fromName(Object? name) {
    for (final card in values) {
      if (card.name == name) return card;
    }
    return null;
  }
}

/// Which end of the block a reminder asks about.
enum NotificationEdge {
  /// Its start: Confirmar begins it, +10 min puts it off.
  start,

  /// Its end: Confirmar ticks it off, +10 min gives it more time.
  end;

  /// The edge named [name] on the wire, or null.
  static NotificationEdge? fromName(Object? name) {
    for (final edge in values) {
      if (edge.name == name) return edge;
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
    this.eventId,
    this.card,
    this.edge,
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

    final eventId = json['eventId'];
    return PlannedNotification(
      id: id,
      kind: kind,
      fireAt: fireAt.toUtc(),
      title: title,
      body: body,
      timeSensitive: json['timeSensitive'] == true,
      eventId: eventId is String && eventId.isNotEmpty ? eventId : null,
      card: NotificationCard.fromName(json['card']),
      edge: NotificationEdge.fromName(json['edge']),
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

  /// The block it is about, when it is about one.
  final String? eventId;

  /// Whether [eventId] is a task or a fixed block, on an ask.
  final NotificationCard? card;

  /// Which end of the block it asks about, on an ask.
  final NotificationEdge? edge;

  /// Whether its buttons have something to answer for.
  bool get asks => eventId != null && card != null && edge != null;

  @override
  List<Object?> get props => [
    id,
    kind,
    fireAt,
    title,
    body,
    timeSensitive,
    eventId,
    card,
    edge,
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
