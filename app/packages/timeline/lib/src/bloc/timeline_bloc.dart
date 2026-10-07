import 'package:bloc/bloc.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:timeline/src/data/timeline_failure.dart';
import 'package:timeline/src/data/timeline_repository.dart';
import 'package:timeline/src/models/models.dart';

part 'timeline_event.dart';
part 'timeline_state.dart';

/// {@template timeline_bloc}
/// Holds the day: the list of tasks and the calendar.
///
/// Everything about when things happen is worked out on the server, so this
/// mostly forwards and redraws. Every write answers with both views, for as
/// many days as the calendar is drawing, so the two never disagree. The few
/// writes drawn before the server answers are the ones whose card has
/// already moved under the finger.
/// {@endtemplate}
class TimelineBloc extends Bloc<TimelineBlocEvent, TimelineState> {
  /// {@macro timeline_bloc}
  TimelineBloc({required this._repository}) : super(const TimelineState()) {
    on<TimelineRequested>(_onRequested);
    on<TimelineExtended>(_onExtended);
    on<EventCreated>(_onCreated);
    on<EventMoved>(_onMoved);
    on<EventStarted>(_onStarted);
    on<EventSnoozed>(_onSnoozed);
    on<EventFinished>(_onFinished);
    on<EventDeleted>(_onDeleted);
    on<EventPauseToggled>(_onPauseToggled);
    on<EventExtended>(_onAdjusted);
    on<EventEdited>(_onEdited);
    on<GuardAnswered>(_onGuardAnswered);
    on<GuardDismissed>(_onGuardDismissed);
  }

  final TimelineRepository _repository;

  int get _days => state.days;

  /// What [id] is. A card not on screen yet is a task: the only thing asked
  /// about before the day has loaded is a task a reminder named.
  CardKind _kindOf(String id) => state.byId(id)?.kind ?? CardKind.task;

  Future<void> _onRequested(
    TimelineRequested event,
    Emitter<TimelineState> emit,
  ) async {
    emit(state.copyWith(status: TimelineStatus.loading, clearFailure: true));

    try {
      final timeline = await _repository.fetch(days: _days);
      emit(
        state.copyWith(
          status: TimelineStatus.success,
          cards: timeline.cards,
          tasks: timeline.tasks,
          backlog: timeline.backlog,
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      emit(_failed(error));
    }
  }

  /// Draws a week more of the calendar, once at a time and only so far.
  Future<void> _onExtended(
    TimelineExtended event,
    Emitter<TimelineState> emit,
  ) async {
    if (state.extending || state.days >= TimelineState.maxDays) return;

    final days = (state.days + TimelineState.daysPerPage).clamp(
      1,
      TimelineState.maxDays,
    );
    emit(state.copyWith(extending: true));

    try {
      final timeline = await _repository.fetch(days: days);
      emit(
        state.copyWith(
          status: TimelineStatus.success,
          days: days,
          extending: false,
          cards: timeline.cards,
          tasks: timeline.tasks,
          backlog: timeline.backlog,
        ),
      );
    } on Object catch (error) {
      emit(_failed(error).copyWith(extending: false));
    }
  }

  /// The state after something the server refused.
  ///
  /// The refusal is kept as the server wrote it, because the server is the
  /// one that knows what went wrong. Every write on this screen is all or
  /// nothing, so the cards already on it are still the true ones.
  TimelineState _failed(Object error) {
    return state.copyWith(
      status: TimelineStatus.failure,
      failure: TimelineFailure.from(error),
      guardBusy: false,
      clearGuard: true,
    );
  }

  /// Draws what a write came back with, the guard included when it raised
  /// one. A guard means the server did not move anything, so the cards that
  /// come back are the ones that were already on screen.
  void _land(Timeline timeline, Emitter<TimelineState> emit) {
    emit(
      state.copyWith(
        status: TimelineStatus.success,
        cards: timeline.cards,
        tasks: timeline.tasks,
        backlog: timeline.backlog,
        guard: timeline.guard,
        clearFailure: true,
      ),
    );
  }

  /// Writes something down, and draws the day with it already in place.
  Future<void> _onCreated(
    EventCreated event,
    Emitter<TimelineState> emit,
  ) async {
    final startTime = event.startTime;

    await _write(
      emit,
      () => event.fixed && startTime != null
          ? _repository.createEvent(
              title: event.title,
              durationMinutes: event.durationMinutes,
              startTime: startTime,
              days: _days,
            )
          : _repository.createTask(
              title: event.title,
              minutes: event.durationMinutes,
              days: _days,
            ),
    );
  }

  /// Sends a drop and draws what the day became.
  ///
  /// Nothing is applied on screen first. A drop changes the hour of
  /// everything after it and only the server knows what those hours are, so
  /// guessing at them would mean drawing a day that is about to be replaced
  /// by a different one.
  Future<void> _onMoved(EventMoved event, Emitter<TimelineState> emit) async {
    final card = state.byId(event.id);
    if (card == null || !card.isTask) return;

    try {
      _land(
        await _repository.moveTask(
          event.id,
          event.index,
          backlog: event.backlog,
          start: event.start,
          after: event.after,
          minutes: event.minutes,
          days: _days,
        ),
        emit,
      );
    } on Object catch (error) {
      emit(_failed(error));
    }
  }

  /// Begins a task, drawing it as begun before the server answers.
  Future<void> _onStarted(
    EventStarted event,
    Emitter<TimelineState> emit,
  ) async {
    // A reminder tapped with the app closed answers before the day has
    // loaded, so a card that is not on screen yet is still asked about.
    final card = state.byId(event.id);
    if (card != null && !card.isTask) return;

    final before = state;
    emit(
      state.copyWith(
        cards: _replaced(state.cards, event.id, awaitingStart: false),
        tasks: _replaced(state.tasks, event.id, awaitingStart: false),
      ),
    );

    try {
      _land(await _repository.startTask(event.id, days: _days), emit);
    } on Object catch (error) {
      emit(_failed(error).copyWith(cards: before.cards, tasks: before.tasks));
    }
  }

  /// Lets a waiting task wait a little longer.
  Future<void> _onSnoozed(
    EventSnoozed event,
    Emitter<TimelineState> emit,
  ) async {
    final card = state.byId(event.id);
    if (card != null && !card.isTask) return;

    await _write(
      emit,
      () => _repository.snoozeTask(
        event.id,
        minutes: event.minutes,
        days: _days,
      ),
    );
  }

  /// Sends the user's answer to the open guard, and draws what comes back.
  Future<void> _onGuardAnswered(
    GuardAnswered event,
    Emitter<TimelineState> emit,
  ) async {
    final guard = state.guard;
    if (guard == null) return;

    emit(state.copyWith(guardBusy: true));

    try {
      final timeline = await _repository.applyTiming(
        guard.answer(event.decision),
        days: _days,
      );

      emit(
        state.copyWith(
          cards: timeline.cards,
          tasks: timeline.tasks,
          backlog: timeline.backlog,
          guard: timeline.guard,
          clearGuard: timeline.guard == null,
          guardBusy: false,
        ),
      );
    } on Object catch (error) {
      // The guard closes rather than sitting there looking live. Nothing was
      // applied, so the timeline on screen is still the true one.
      emit(_failed(error));
    }
  }

  /// Drops a guard without answering it, which changes nothing anywhere.
  void _onGuardDismissed(GuardDismissed event, Emitter<TimelineState> emit) {
    emit(state.copyWith(clearGuard: true, guardBusy: false));
  }

  /// Takes a card off the day, then writes it.
  ///
  /// This one lands on screen first: the card has already been thrown off by
  /// the time the request goes out, and a failure puts it back rather than
  /// leaving an hour the user thinks they gave back.
  Future<void> _onFinished(
    EventFinished event,
    Emitter<TimelineState> emit,
  ) async {
    final card = state.byId(event.id);
    if (card == null || !card.isInteractive) return;

    await _write(
      emit,
      () => _repository.finish(card.kind, event.id, days: _days),
      drawn: _without(event.id),
    );
  }

  /// Takes a card off entirely, drawn gone before the server answers.
  Future<void> _onDeleted(
    EventDeleted event,
    Emitter<TimelineState> emit,
  ) async {
    final card = state.byId(event.id);
    if (card == null || !card.isInteractive) return;

    await _write(
      emit,
      () => _repository.delete(card.kind, event.id, days: _days),
      drawn: _without(event.id),
    );
  }

  /// Pauses or resumes, drawing the new state of the button straight away.
  Future<void> _onPauseToggled(
    EventPauseToggled event,
    Emitter<TimelineState> emit,
  ) async {
    final card = state.byId(event.id);
    if (card == null || !card.isInteractive) return;

    final paused = !card.isPaused;
    final pausedAt = paused ? clock.now() : null;

    await _write(
      emit,
      () => paused
          ? _repository.pause(card.kind, event.id, days: _days)
          : _repository.resume(card.kind, event.id, days: _days),
      drawn: state.copyWith(
        cards: _replaced(state.cards, event.id, pausedAt: pausedAt),
        tasks: _replaced(state.tasks, event.id, pausedAt: pausedAt),
      ),
    );
  }

  /// Gives a card more time. The rest of the day is the server's to move.
  Future<void> _onAdjusted(
    EventExtended event,
    Emitter<TimelineState> emit,
  ) async {
    await _write(
      emit,
      () => _repository.extend(
        _kindOf(event.id),
        event.id,
        event.minutes,
        days: _days,
      ),
    );
  }

  /// Sends what the detail screen changed.
  Future<void> _onEdited(EventEdited event, Emitter<TimelineState> emit) async {
    await _write(
      emit,
      () => _repository.edit(
        _kindOf(event.id),
        event.id,
        title: event.title,
        notes: event.notes,
        workMinutes: event.workMinutes,
        startTime: event.startTime,
        days: _days,
      ),
    );
  }

  /// One write that answers with the whole day.
  ///
  /// [drawn], when given, goes on screen before the request does, and is
  /// taken back if the server refuses.
  Future<void> _write(
    Emitter<TimelineState> emit,
    Future<Timeline> Function() request, {
    TimelineState? drawn,
  }) async {
    final before = state;
    if (drawn != null) emit(drawn);

    try {
      _land(await request(), emit);
    } on Object catch (error) {
      emit(
        _failed(error).copyWith(
          cards: before.cards,
          tasks: before.tasks,
          backlog: before.backlog,
        ),
      );
    }
  }

  /// The state with [id] gone from every view.
  TimelineState _without(String id) => state.copyWith(
    cards: state.cards.where((it) => it.id != id).toList(),
    tasks: state.tasks.where((it) => it.id != id).toList(),
    backlog: state.backlog.where((it) => it.id != id).toList(),
  );

  /// [cards] with the one called [id] waiting or paused as asked.
  static List<TimelineEvent> _replaced(
    List<TimelineEvent> cards,
    String id, {
    bool? awaitingStart,
    DateTime? pausedAt,
  }) => [
    for (final card in cards)
      if (card.id != id)
        card
      else if (awaitingStart != null)
        card.copyWith(awaitingStart: awaitingStart)
      else
        card.copyWith(pausedAt: pausedAt, clearPause: pausedAt == null),
  ];
}
