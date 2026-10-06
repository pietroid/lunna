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

/// Draws more days: the calendar was scrolled to its end.
final class TimelineExtended extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const TimelineExtended();
}

/// Writes something down.
///
/// The sheet asked how long it takes and whether the hour is the point of
/// it. A flexible one is a task, at the end of the queue; a fixed one is an
/// event, at its hour.
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

/// Moves one task to [index] in the list of tasks.
///
/// One number, because the queue is one list. The server turns it into hours
/// for everything the drop disturbed, so the app waits for the answer rather
/// than guessing at the new times itself.
final class EventMoved extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventMoved({
    required this.id,
    required this.index,
    this.start = false,
    this.after,
    this.minutes,
  });

  /// The task that was dragged.
  final String id;

  /// Where it was dropped in the list of tasks, counted from the top with
  /// itself taken out. What is running counts, at the top.
  final int index;

  /// Whether it was dropped at the very top of the day, which is doing it
  /// now.
  final bool start;

  /// Where the free stretch it was dropped into starts, when it was.
  final DateTime? after;

  /// The length the user agreed to cut it to so it fits that stretch.
  final int? minutes;

  @override
  List<Object?> get props => [id, index, start, after, minutes];
}

/// The user began a task that was waiting for them.
///
/// Sent by the card's button and by the popup a reminder opens. A task that
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

/// Answers the open guard.
final class GuardAnswered extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const GuardAnswered(this.decision);

  /// What the user decided about the block that was running.
  final TimingDecision decision;

  @override
  List<Object?> get props => [decision];
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
/// space.
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

/// Changes what the detail screen edits: the name, the notes, the work, or,
/// for an event, the hour.
final class EventEdited extends TimelineBlocEvent {
  /// {@macro timeline_bloc_event}
  const EventEdited(
    this.id, {
    this.title,
    this.notes,
    this.workMinutes,
    this.startTime,
  });

  /// The card being edited.
  final String id;

  /// The new name, when it changed.
  final String? title;

  /// The notes, when they changed.
  final String? notes;

  /// How long the work takes now, when it changed.
  final int? workMinutes;

  /// The new hour of an event, when one was picked.
  final DateTime? startTime;

  @override
  List<Object?> get props => [id, title, notes, workMinutes, startTime];
}
