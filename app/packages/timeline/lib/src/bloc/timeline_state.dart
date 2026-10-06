part of 'timeline_bloc.dart';

/// The status of the timeline.
enum TimelineStatus {
  /// Nothing has been requested yet.
  initial,

  /// The list is being fetched.
  loading,

  /// The list is available.
  success,

  /// The list could not be fetched.
  failure,
}

/// {@template timeline_state}
/// The state of the timeline.
/// {@endtemplate}
final class TimelineState extends Equatable {
  /// {@macro timeline_state}
  const TimelineState({
    this.status = TimelineStatus.initial,
    this.cards = const [],
    this.tasks = const [],
    this.days = initialDays,
    this.extending = false,
    this.guard,
    this.guardBusy = false,
    this.failure,
  });

  /// How many days the calendar draws before it is scrolled.
  static const initialDays = 7;

  /// How many more days each scroll to the end of the calendar draws.
  static const daysPerPage = 7;

  /// The furthest the calendar goes, which is as far as the server draws.
  static const maxDays = 120;

  /// The status of the list.
  final TimelineStatus status;

  /// Everything the calendar draws, earliest first: the events, and the
  /// tasks at the hours the queue gives them.
  ///
  /// One list, in clock order, exactly as the server sent it. The headings
  /// the screen draws are cut out of this rather than stored alongside it,
  /// which is why nothing here ever has to be kept in step with anything.
  final List<TimelineEvent> cards;

  /// Every task still to do, in queue order: what is running first, then
  /// the queue. All of them, however far ahead the calendar would put them.
  final List<TimelineEvent> tasks;

  /// How many days the calendar draws, counting today.
  final int days;

  /// Whether more days are on their way.
  final bool extending;

  /// The question a move raised, if one is still open.
  ///
  /// While this is set nothing about the move has happened on the server.
  final StartNowGuard? guard;

  /// Whether the guard's last answer is still in flight.
  final bool guardBusy;

  /// Why the last thing the screen tried did not happen.
  ///
  /// Carries the server's own sentence when there was one; the screen words
  /// the rest.
  final TimelineFailure? failure;

  /// The card with [id], or null if the day does not have it.
  ///
  /// The list first, because it has every task and the calendar only the
  /// ones that fall in the days it draws.
  TimelineEvent? byId(String id) {
    for (final card in tasks) {
      if (card.id == id) return card;
    }
    for (final card in cards) {
      if (card.id == id) return card;
    }

    return null;
  }

  /// Whether the first load is still in flight.
  ///
  /// A reload with cards already on screen is not a loading state: replacing
  /// the list with a spinner every time the user comes back to it would
  /// flash the screen for no reason.
  bool get isInitialLoad =>
      status == TimelineStatus.loading && cards.isEmpty && tasks.isEmpty;

  /// Returns a copy with the given fields replaced.
  ///
  /// [clearGuard] takes the guard away, which a null [guard] cannot: the
  /// whole point of most of these copies is to leave it exactly as it is.
  TimelineState copyWith({
    TimelineStatus? status,
    List<TimelineEvent>? cards,
    List<TimelineEvent>? tasks,
    int? days,
    bool? extending,
    StartNowGuard? guard,
    bool? guardBusy,
    TimelineFailure? failure,
    bool clearGuard = false,
    bool clearFailure = false,
  }) {
    return TimelineState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      tasks: tasks ?? this.tasks,
      days: days ?? this.days,
      extending: extending ?? this.extending,
      guard: clearGuard ? null : guard ?? this.guard,
      guardBusy: guardBusy ?? this.guardBusy,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    cards,
    tasks,
    days,
    extending,
    guard,
    guardBusy,
    failure,
  ];
}
