import 'package:bloc/bloc.dart';
import 'package:cycle/src/cycle_repository.dart';
import 'package:cycle/src/models.dart';
import 'package:equatable/equatable.dart';

/// Where the rhythm is in being read.
enum CycleStatus {
  /// Not asked for yet.
  initial,

  /// Being read or written.
  loading,

  /// Read.
  ready,

  /// The last read or write failed.
  failure,
}

/// {@template cycle_state}
/// The rhythm as the server last had it.
/// {@endtemplate}
class CycleState extends Equatable {
  /// {@macro cycle_state}
  const CycleState({this.status = CycleStatus.initial, this.data});

  /// Where it is in being read.
  final CycleStatus status;

  /// What was read, kept through a write.
  final Rhythm? data;

  @override
  List<Object?> get props => [status, data];
}

/// {@template cycle_cubit}
/// Reads and writes the cycle, the weekend's rules and the dates off.
///
/// [onChanged] runs after every write, which is where the shell asks the
/// timeline again: a new period moves the light days, and the queue with
/// them.
/// {@endtemplate}
class CycleCubit extends Cubit<CycleState> {
  /// {@macro cycle_cubit}
  CycleCubit({
    required this._repository,
    this.onChanged,
    CycleState initial = const CycleState(),
  }) : super(initial);

  final CycleRepository _repository;

  /// Runs after every write that succeeded.
  final void Function()? onChanged;

  /// Reads it all.
  Future<void> load() => _run(_repository.load, notify: false);

  /// Writes the cycle down whole.
  Future<void> saveCycle(Cycle cycle) =>
      _run(() => _repository.saveCycle(cycle));

  /// A period began on [day].
  Future<void> periodStarted(DateTime day) =>
      _run(() => _repository.periodStarted(day));

  /// Writes the weekend's rules and the light day's budget.
  Future<void> saveRules(RestRules rules) =>
      _run(() => _repository.saveRules(rules));

  Future<void> _run(
    Future<Rhythm> Function() call, {
    bool notify = true,
  }) async {
    emit(CycleState(status: CycleStatus.loading, data: state.data));
    try {
      final data = await call();
      emit(CycleState(status: CycleStatus.ready, data: data));
      if (notify) onChanged?.call();
    } on Object {
      emit(CycleState(status: CycleStatus.failure, data: state.data));
    }
  }
}
