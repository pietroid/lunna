import 'package:bloc/bloc.dart';
import 'package:chat/src/data/chat_failure.dart';
import 'package:chat/src/data/things_repository.dart';
import 'package:chat/src/models/models.dart';
import 'package:equatable/equatable.dart';

part 'things_event.dart';
part 'things_state.dart';

/// {@template things_bloc}
/// Holds Coisas: what has no hour yet, in the order the user means to do it.
///
/// Every change lands on screen first and is taken back if the server
/// refuses it. Nothing here is arithmetic the server has to do, so there is
/// nothing to wait for before drawing it.
/// {@endtemplate}
class ThingsBloc extends Bloc<ThingsEvent, ThingsState> {
  /// {@macro things_bloc}
  ThingsBloc({required this._repository}) : super(const ThingsState()) {
    on<ThingsRequested>(_onRequested);
    on<ThingAdded>(_onAdded);
    on<ThingEdited>(_onEdited);
    on<ThingMoved>(_onMoved);
    on<ThingFinished>(_onFinished);
    on<ThingDeleted>(_onDeleted);
    on<ThingScheduled>(_onScheduled);
  }

  final ThingsRepository _repository;

  Future<void> _onRequested(
    ThingsRequested event,
    Emitter<ThingsState> emit,
  ) async {
    emit(state.copyWith(status: ThingsStatus.loading, clearFailure: true));

    try {
      emit(
        state.copyWith(
          status: ThingsStatus.success,
          things: await _repository.fetchThings(),
        ),
      );
    } on Object catch (error) {
      emit(_failed(error));
    }
  }

  Future<void> _onAdded(ThingAdded event, Emitter<ThingsState> emit) => _write(
    emit,
    () => _repository.addThing(
      title: event.title,
      durationMinutes: event.durationMinutes,
    ),
  );

  Future<void> _onEdited(ThingEdited event, Emitter<ThingsState> emit) =>
      _write(
        emit,
        () => _repository.editThing(
          event.id,
          title: event.title,
          durationMinutes: event.durationMinutes,
        ),
        drawn: [
          for (final thing in state.things)
            thing.id == event.id
                ? Thing(
                    id: thing.id,
                    title: event.title ?? thing.title,
                    durationMinutes:
                        event.durationMinutes ?? thing.durationMinutes,
                  )
                : thing,
        ],
      );

  Future<void> _onMoved(ThingMoved event, Emitter<ThingsState> emit) {
    final rest = [...state.things];
    final from = rest.indexWhere((thing) => thing.id == event.id);
    if (from == -1) return Future.value();

    final moved = rest.removeAt(from);
    rest.insert(event.index.clamp(0, rest.length), moved);

    return _write(
      emit,
      () => _repository.moveThing(event.id, event.index),
      drawn: rest,
    );
  }

  Future<void> _onFinished(ThingFinished event, Emitter<ThingsState> emit) =>
      _write(
        emit,
        () => _repository.finishThing(event.id),
        drawn: _without(event.id),
      );

  Future<void> _onDeleted(ThingDeleted event, Emitter<ThingsState> emit) =>
      _write(
        emit,
        () => _repository.deleteThing(event.id),
        drawn: _without(event.id),
      );

  /// Moves a thing onto the timeline and says so, so the screen can too.
  Future<void> _onScheduled(
    ThingScheduled event,
    Emitter<ThingsState> emit,
  ) async {
    final before = state.things;
    final thing = before.where((it) => it.id == event.id).firstOrNull;
    if (thing == null) return;

    emit(state.copyWith(things: _without(event.id)));

    try {
      final result = await _repository.scheduleThing(event.id);
      emit(
        state.copyWith(
          things: result.things,
          scheduled: thing,
          scheduledCount: state.scheduledCount + 1,
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      emit(_failed(error).copyWith(things: before));
    }
  }

  List<Thing> _without(String id) =>
      state.things.where((thing) => thing.id != id).toList();

  ThingsState _failed(Object error) {
    return state.copyWith(
      status: ThingsStatus.failure,
      failure: ChatFailure.from(error).message,
    );
  }

  /// One write that answers with the whole list.
  ///
  /// [drawn], when given, goes on screen before the request does, and is
  /// taken back if the server refuses.
  Future<void> _write(
    Emitter<ThingsState> emit,
    Future<List<Thing>> Function() request, {
    List<Thing>? drawn,
  }) async {
    final before = state.things;
    if (drawn != null) emit(state.copyWith(things: drawn));

    try {
      emit(
        state.copyWith(
          status: ThingsStatus.success,
          things: await request(),
          clearFailure: true,
        ),
      );
    } on Object catch (error) {
      emit(_failed(error).copyWith(things: before));
    }
  }
}
