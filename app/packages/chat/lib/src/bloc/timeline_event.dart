part of 'timeline_bloc.dart';

/// {@template timeline_bloc_event}
/// Base class for events handled by [TimelineBloc].
///
/// Named for the bloc rather than for the domain, because the domain already
/// has events: the blocks of time this draws. One of these is something that
/// happened to the screen, not something on the calendar.
/// {@endtemplate}
sealed class TimelineBlocEvent extends Equatable {
  /// {@macro timeline_bloc_event}
  const TimelineBlocEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the day, or reloads it after the user returns to home.
final class TimelineRequested extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const TimelineRequested();
}

/// Writes something down and puts it on the timeline.
///
/// No conversation. The sheet asked how long it takes and whether the hour is
/// the point of it, which is everything the server needs to give it one.
final class EventCreated extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventCreated({
    required this.title,
    required this.durationMinutes,
    required this.fixed,
    this.startTime,
    this.notBefore,
  });

  /// What the user wrote, which is what the block is called.
  final String title;

  /// How long it takes.
  final int durationMinutes;

  /// Whether the hour is the point of it.
  final bool fixed;

  /// The hour, when the user picked one. Only a fixed block does.
  final DateTime? startTime;

  /// The earliest a flexible block may start, when it was written down from
  /// empty room further down the day.
  final DateTime? notBefore;

  @override
  List<Object?> get props => [
    title,
    durationMinutes,
    fixed,
    startTime,
    notBefore,
  ];
}

/// Moves one card to [index] in the day's single list.
///
/// One number, because there is one list. The server turns it into hours for
/// everything the drop disturbed, so the app waits for the answer rather than
/// guessing at the new times itself.
final class EventMoved extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventMoved({
    required this.id,
    required this.index,
    this.after,
    this.minutes,
  });

  /// The card that was dragged.
  final String id;

  /// Where it was dropped, counted from the top with itself taken out.
  final int index;

  /// Where the free stretch it was dropped into starts, when it was.
  final DateTime? after;

  /// The length the user agreed to cut it to so it fits that stretch.
  final int? minutes;

  @override
  List<Object?> get props => [id, index, after, minutes];
}

/// The user began a block that was waiting for them.
///
/// Sent by the card's button and by the popup a reminder opens. A block that
/// has not reached its hour goes to the top of the day instead.
final class EventStarted extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventStarted(this.id);

  /// The block.
  final String id;

  @override
  List<Object?> get props => [id];
}

/// Not yet: the block waits [minutes] more before asking again.
final class EventSnoozed extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventSnoozed(this.id, {this.minutes = 15});

  /// The block.
  final String id;

  /// How much longer it waits.
  final int minutes;

  @override
  List<Object?> get props => [id, minutes];
}

/// Sends back the button the user tapped on a guard.
///
/// The action is the server's own object, posted verbatim. The app never
/// reads it: a guard's buttons are drawn from what the server sent and
/// answered with what it sent.
final class GuardAnswered extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const GuardAnswered(this.action);

  /// The action the tapped component carried.
  final Map<String, dynamic> action;

  @override
  List<Object?> get props => [action];
}

/// Asks whether the calendar kept up with the last change.
///
/// Fired after every change and awaited by nobody: the day is already on
/// screen, and this only decides whether a popup goes over it. The app never
/// works out the answer itself, because what is still queued for Google is
/// the server's to know.
final class SyncWatched extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const SyncWatched();
}

/// Pushes whatever did not reach the calendar at it again.
///
/// The one button on the sync popup. It names nothing: the retry is
/// everything that fell behind, whatever that turned out to be.
final class SyncRetried extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const SyncRetried();
}

/// Closes a guard without answering it.
///
/// Nothing was applied while it was open, so there is nothing to undo.
final class GuardDismissed extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const GuardDismissed();
}

/// Takes a block off the day.
///
/// The hour it had goes back to the day and the rest of it closes up over the
/// space. A conversation about the block, if there was one, is closed with
/// it: something the user is finished with is not something they still have
/// an open question about.
final class EventFinished extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventFinished(this.id);

  /// The card that was carried out of the timeline.
  final String id;

  @override
  List<Object?> get props => [id];
}

/// Takes a block off the calendar, keeping nothing of it.
///
/// Different from [EventFinished], which keeps the hour a running block
/// really took. This one was never going to happen.
final class EventDeleted extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventDeleted(this.id);

  /// The card to remove.
  final String id;

  @override
  List<Object?> get props => [id];
}

/// Pauses the running block, or runs it again if it already is paused.
///
/// One event for both, because it is one button: what it does depends on
/// the card, and the card is in the state.
final class EventPauseToggled extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventPauseToggled(this.id);

  /// The running card.
  final String id;

  @override
  List<Object?> get props => [id];
}

/// Gives a block more time, because the estimate was wrong.
final class EventExtended extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventExtended(this.id, {this.minutes = 15});

  /// The card to extend.
  final String id;

  /// How many more minutes it gets.
  final int minutes;

  @override
  List<Object?> get props => [id, minutes];
}

/// Changes what the detail screen edits: the name, the work, or the hour.
final class EventEdited extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventEdited(this.id, {this.title, this.workMinutes, this.startTime});

  /// The card being edited.
  final String id;

  /// The new name, when it changed.
  final String? title;

  /// How long the work takes now, when it changed.
  final int? workMinutes;

  /// The hour to pin it to, when one was picked.
  final DateTime? startTime;

  @override
  List<Object?> get props => [id, title, workMinutes, startTime];
}
