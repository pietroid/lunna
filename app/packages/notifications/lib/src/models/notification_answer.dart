import 'package:equatable/equatable.dart';
import 'package:notifications/src/models/notification_plan.dart';

/// The step of a reminder's "+10 min": the server's `STEP_MINUTES`.
const notificationStepMinutes = 10;

/// A reminder's buttons, in the order they are drawn.
///
/// The ids are what the system hands back when one is chosen, so they are
/// part of the contract with the category registered on the device.
enum NotificationAction {
  /// Yes: it started, or it is over.
  confirm('confirm'),

  /// Not yet: ten minutes more before it starts, or before it ends.
  later('later'),

  /// Talk it over: opens the app with the agent asked about the card.
  talk('talk');

  const NotificationAction(this.id);

  /// What the system hands back when this button is chosen.
  final String id;

  /// The button whose id is [id], or null for a tap on the notification
  /// itself.
  static NotificationAction? fromId(String? id) {
    for (final action in values) {
      if (action.id == id) return action;
    }
    return null;
  }
}

/// {@template notification_answer}
/// The write one of a reminder's buttons makes: the same request the app's
/// own button on the card makes, so every rule stays on the server.
/// {@endtemplate}
class NotificationAnswer extends Equatable {
  /// {@macro notification_answer}
  const NotificationAnswer({required this.path, this.data});

  /// The answer to [action] on the [edge] of [card] [id], or null when the
  /// action writes nothing (talking it over opens the app instead).
  ///
  /// | | start | end |
  /// |---|---|---|
  /// | task, Confirmar | `/tasks/:id/start` | `/tasks/:id/done` |
  /// | task, +10 min | `/tasks/:id/snooze` | `/tasks/:id/extend` |
  /// | event, Confirmar | `/events/:id/start` | `/events/:id/done` |
  /// | event, +10 min | `/events/:id/delay` | `/events/:id/extend` |
  static NotificationAnswer? of({
    required NotificationCard card,
    required NotificationEdge edge,
    required String id,
    required NotificationAction action,
  }) {
    final base =
        '/${card == NotificationCard.task ? 'tasks' : 'events'}'
        '/${Uri.encodeComponent(id)}';
    const more = {'minutes': notificationStepMinutes};

    return switch ((action, edge)) {
      (NotificationAction.talk, _) => null,
      (NotificationAction.confirm, NotificationEdge.start) =>
        NotificationAnswer(path: '$base/start'),
      (NotificationAction.confirm, NotificationEdge.end) => NotificationAnswer(
        path: '$base/done',
      ),
      (NotificationAction.later, NotificationEdge.start) => NotificationAnswer(
        path: card == NotificationCard.task ? '$base/snooze' : '$base/delay',
        data: more,
      ),
      (NotificationAction.later, NotificationEdge.end) => NotificationAnswer(
        path: '$base/extend',
        data: more,
      ),
    };
  }

  /// The route, under `/api`.
  final String path;

  /// Its body, when it has one.
  final Map<String, Object?>? data;

  @override
  List<Object?> get props => [path, data];
}
