import 'package:bloc/bloc.dart';
import 'package:chat/src/data/chat_failure.dart';
import 'package:chat/src/data/timeline_repository.dart';
import 'package:chat/src/models/models.dart';
import 'package:equatable/equatable.dart';

part 'timeline_event.dart';
part 'timeline_state.dart';

/// {@template timeline_bloc}
/// Holds the day.
///
/// Every card is a block of time on the calendar, and everything about when
/// things happen is worked out on the server, so this mostly forwards and
/// redraws. There is one optimistic write left, finishing a block, because
/// the card has already flown off the screen by the time the request goes
/// out.
/// {@endtemplate}
class TimelineBloc extends Bloc<TimelineBlocEvent, TimelineState> {
  /// {@macro timeline_bloc}
  TimelineBloc({required this._repository}) : super(const TimelineState()) {
    on<TimelineRequested>(_onRequested);
    on<EventCreated>(_onCreated);
    on<EventMoved>(_onMoved);
    on<EventStarted>(_onStarted);
    on<EventSnoozed>(_onSnoozed);
    on<EventFinished>(_onFinished);
    on<EventDeleted>(_onDeleted);
    on<EventPauseToggled>(_onPauseToggled);
    on<EventExtended>(_onExtended);
    on<EventEdited>(_onEdited);
    on<GuardAnswered>(_onGuardAnswered);
    on<GuardDismissed>(_onGuardDismissed);
    on<SyncWatched>(_onSyncWatched);
    on<SyncRetried>(_onSyncRetried);
  }

  final TimelineRepository _repository;

  Future<void> _onRequested(
    TimelineRequested event,
    Emitter<TimelineState> emit,
  ) async {
    emit(state.copyWith(status: TimelineStatus.loading, clearFailure: true));

    try {
      emit(
        state.copyWith(
          status: TimelineStatus.success,
          cards: await _repository.fetchEvents(),
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      emit(_failed(error));
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
      failure: ChatFailure.from(error).message,
      guardBusy: false,
      clearGuard: true,
    );
  }

  /// Writes something down, and draws the day with it already in place.
  Future<void> _onCreated(
    EventCreated event,
    Emitter<TimelineState> emit,
  ) async {
    try {
      final cards = await _repository.createEvent(
        title: event.title,
        durationMinutes: event.durationMinutes,
        fixed: event.fixed,
        startTime: event.startTime,
        notBefore: event.notBefore,
      );

      emit(
        state.copyWith(
          status: TimelineStatus.success,
          cards: cards,
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      emit(_failed(error));
    }
  }

  /// Sends a drop and draws what the day became.
  ///
  /// Nothing is applied on screen first. A drop changes the hour of
  /// everything it displaced and only the server knows what those hours are,
  /// so guessing at them would mean drawing a day that is about to be
  /// replaced by a different one.
  Future<void> _onMoved(EventMoved event, Emitter<TimelineState> emit) async {
    final card = state.byId(event.id);
    if (card == null || !card.isInteractive) return;

    try {
      final outcome = await _repository.moveEvent(
        event.id,
        event.index,
        after: event.after,
        minutes: event.minutes,
      );

      _land(outcome, emit);
    } on Object catch (error) {
      emit(_failed(error));
    }
  }

  /// Draws what a move, or anything that answers like one, came back with.
  void _land(TimelineOutcome outcome, Emitter<TimelineState> emit) {
    // A guard means the server did not move anything, so the cards that
    // come back are the ones that were already on screen.
    emit(
      outcome.guard == null
          ? state.copyWith(cards: outcome.cards, clearFailure: true)
          : state.copyWith(
              cards: outcome.cards,
              guard: outcome.guard,
              clearFailure: true,
            ),
    );

    // The drop has landed. Whether it reached Google is a separate
    // question, asked behind the answer the finger was waiting for.
    if (outcome.guard == null) add(const SyncWatched());
  }

  /// Begins a block, drawing it as begun before the server answers.
  Future<void> _onStarted(
    EventStarted event,
    Emitter<TimelineState> emit,
  ) async {
    // A reminder tapped with the app closed answers before the day has
    // loaded, so a card that is not on screen yet is still asked about.
    final card = state.byId(event.id);
    if (card != null && !card.isInteractive) return;

    final before = state.cards;
    emit(
      state.copyWith(
        cards: [
          for (final it in state.cards)
            it.id == event.id ? it.copyWith(awaitingStart: false) : it,
        ],
      ),
    );

    try {
      _land(await _repository.startEvent(event.id), emit);
    } on Object catch (error) {
      emit(_failed(error).copyWith(cards: before));
    }
  }

  /// Lets a waiting block wait a little longer.
  Future<void> _onSnoozed(
    EventSnoozed event,
    Emitter<TimelineState> emit,
  ) async {
    final card = state.byId(event.id);
    if (card != null && !card.isInteractive) return;

    await _write(
      emit,
      () => _repository.snoozeEvent(event.id, minutes: event.minutes),
    );
  }

  /// Waits for the calendar and puts the popup up if it fell behind.
  ///
  /// Its own event so that it runs after the change it follows rather than
  /// inside it. Nothing on screen waits for this, and when it comes back with
  /// nothing to say, which is nearly always, it emits nothing at all.
  Future<void> _onSyncWatched(
    SyncWatched event,
    Emitter<TimelineState> emit,
  ) async {
    try {
      final outcome = await _repository.awaitSync();
      if (outcome.ok || outcome.guard == null) return;

      // Never over an open question. The user is in the middle of answering
      // one, and this one will still be true when they are done.
      if (state.guard != null) return;

      emit(state.copyWith(guard: outcome.guard));
    } on Object catch (_) {
      // A sync check that cannot be made says nothing. The day on screen is
      // right either way, and a popup about the popup helps nobody.
    }
  }

  /// Pushes the day at the calendar again, from the popup's one button.
  Future<void> _onSyncRetried(
    SyncRetried event,
    Emitter<TimelineState> emit,
  ) async {
    emit(state.copyWith(guardBusy: true));

    try {
      final outcome = await _repository.retrySync();

      emit(
        outcome.ok || outcome.guard == null
            ? state.copyWith(guardBusy: false, clearGuard: true)
            : state.copyWith(guard: outcome.guard, guardBusy: false),
      );
    } on Object catch (error) {
      emit(_failed(error).copyWith(guardBusy: false, clearGuard: true));
    }
  }

  /// Sends the button the user tapped on a guard, and draws what comes back.
  Future<void> _onGuardAnswered(
    GuardAnswered event,
    Emitter<TimelineState> emit,
  ) async {
    emit(state.copyWith(guardBusy: true));

    try {
      final outcome = await _repository.applyTiming(event.action);

      emit(
        outcome.guard == null
            ? state.copyWith(
                cards: outcome.cards,
                guardBusy: false,
                clearGuard: true,
              )
            : state.copyWith(guard: outcome.guard, guardBusy: false),
      );

      if (outcome.guard == null) add(const SyncWatched());
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

  /// Takes a block off the day, then writes it.
  ///
  /// This one lands on screen first: the card has already been thrown off by
  /// the time the request goes out, and a failure puts it back rather than
  /// leaving an hour the user thinks they gave back.
  Future<void> _onFinished(
    EventFinished event,
    Emitter<TimelineState> emit,
  ) async {
    final before = state.cards;
    final card = state.byId(event.id);
    if (card == null || !card.isInteractive) return;

    emit(
      state.copyWith(
        cards: before.where((it) => it.id != event.id).toList(),
      ),
    );

    try {
      emit(
        state.copyWith(
          cards: await _repository.finishEvent(event.id),
          clearFailure: true,
        ),
      );

      add(const SyncWatched());
    } on Object catch (error) {
      // Finishing is the one write that lands on screen first, so it is also
      // the one that has to be put back.
      emit(_failed(error).copyWith(cards: before));
    }
  }

  /// Takes a block off the calendar, drawn gone before the server answers.
  Future<void> _onDeleted(
    EventDeleted event,
    Emitter<TimelineState> emit,
  ) async {
    final card = state.byId(event.id);
    if (card == null || !card.isInteractive) return;

    await _write(
      emit,
      () => _repository.deleteEvent(event.id),
      drawn: state.cards.where((it) => it.id != event.id).toList(),
    );
  }

  /// Pauses or resumes, drawing the new state of the button straight away.
  Future<void> _onPauseToggled(
    EventPauseToggled event,
    Emitter<TimelineState> emit,
  ) async {
    final card = state.byId(event.id);
    if (card == null || !card.isInteractive) return;

    final toggled = card.isPaused
        ? card.copyWith(clearPause: true)
        : card.copyWith(pausedAt: DateTime.now());

    await _write(
      emit,
      () => card.isPaused
          ? _repository.resumeEvent(event.id)
          : _repository.pauseEvent(event.id),
      drawn: [
        for (final it in state.cards) it.id == event.id ? toggled : it,
      ],
    );
  }

  /// Gives a block more time. The rest of the day is the server's to move.
  Future<void> _onExtended(
    EventExtended event,
    Emitter<TimelineState> emit,
  ) async {
    await _write(
      emit,
      () => _repository.extendEvent(event.id, event.minutes),
    );
  }

  /// Sends what the detail screen changed.
  Future<void> _onEdited(EventEdited event, Emitter<TimelineState> emit) async {
    await _write(
      emit,
      () => _repository.editEvent(
        event.id,
        title: event.title,
        workMinutes: event.workMinutes,
        startTime: event.startTime,
      ),
    );
  }

  /// One write that answers with the whole day.
  ///
  /// [drawn], when given, goes on screen before the request does, and is
  /// taken back if the server refuses.
  Future<void> _write(
    Emitter<TimelineState> emit,
    Future<List<TimelineEvent>> Function() request, {
    List<TimelineEvent>? drawn,
  }) async {
    final before = state.cards;
    if (drawn != null) emit(state.copyWith(cards: drawn));

    try {
      emit(state.copyWith(cards: await request(), clearFailure: true));
      add(const SyncWatched());
    } on Object catch (error) {
      emit(_failed(error).copyWith(cards: before));
    }
  }
}
