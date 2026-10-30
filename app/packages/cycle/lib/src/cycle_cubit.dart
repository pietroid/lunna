import 'package:bloc/bloc.dart';
import 'package:cycle/src/cycle_repository.dart';
import 'package:cycle/src/models.dart';
import 'package:equatable/equatable.dart';
import 'package:timeline/timeline.dart';

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

  /// Corrects the prediction: the next period begins on [day]. Null goes
  /// back to the prediction.
  Future<void> predictStart(DateTime? day) {
    final cycle = state.data?.cycle;
    if (cycle == null) return Future.value();

    return saveCycle(cycle.copyWith(nextStart: () => day));
  }

  /// Puts each of [days] back to work, though the weekend is off.
  Future<void> workOn(List<DateTime> days) => _run(() async {
    late Rhythm rhythm;
    for (final day in days) {
      rhythm = await _repository.addDay(day, kind: DayKind.work);
    }
    return rhythm;
  });

  /// Writes [day] down as a day off named [title].
  Future<void> addDayOff(DateTime day, String title) =>
      _run(() => _repository.addDay(day, title: title));

  /// Takes the dates [ids] away.
  Future<void> remove(List<String> ids) => _run(() async {
    var rhythm = state.data ?? const Rhythm();
    for (final id in ids) {
      rhythm = await _repository.removeDay(id);
    }
    return rhythm;
  });

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
