import 'package:equatable/equatable.dart';
import 'package:notifications/src/models/notification_plan.dart';

/// The step of a reminder's "+10 min": the server's `STEP_MINUTES`.
const notificationStepMinutes = 10;

/// The answers a tapped reminder's sheet offers, in the order they are
/// ranked.
enum NotificationAction {
  /// Yes: it started, or it is over.
  confirm,

  /// Not yet: ten minutes more before it starts, or before it ends.
  later,

  /// Talk it over: the agent's sheet, asked about the card.
  talk,
}

/// {@template notification_answer}
/// The write an answer to a reminder makes: the same request the app's own
/// button on the card makes, so every rule stays on the server.
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
