import 'dart:async';

import 'package:artifacts/src/data/artifacts_repository.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

/// Whether Entregas has been read yet.
enum ArtifactsStatus {
  /// Not read yet.
  loading,

  /// Read.
  ready,

  /// The last read or write failed.
  failure,
}

/// {@template artifacts_state}
/// Every delivery, the catalogue and the goals, as the server last sent
/// them.
/// {@endtemplate}
class ArtifactsState extends Equatable {
  /// {@macro artifacts_state}
  const ArtifactsState({
    this.status = ArtifactsStatus.loading,
    this.data,
    this.failure,
  });

  /// Whether they have been read.
  final ArtifactsStatus status;

  /// What the server sent; null until it has.
  final ArtifactsData? data;

  /// What the last write was refused with, until the next one.
  final ArtifactsFailure? failure;

  /// Every delivery, the open ones first.
  List<Artifact> get artifacts => data?.artifacts ?? const [];

  /// The deliveries not made yet, in order of priority.
  List<Artifact> get queue => data?.queue ?? const [];

  /// The deliveries made, newest first.
  List<Artifact> get done => data?.done ?? const [];

  /// The catalogue's shelves.
  List<CatalogCategory> get catalog => data?.catalog ?? const [];

  /// The goals.
  List<Goal> get goals => data?.goals ?? const [];

  /// The delivery with [id], if it is still there.
  Artifact? byId(String id) {
    for (final a in artifacts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// A copy with the given fields changed.
  ArtifactsState copyWith({
    ArtifactsStatus? status,
    ArtifactsData? data,
    ArtifactsFailure? Function()? failure,
  }) {
    return ArtifactsState(
      status: status ?? this.status,
      data: data ?? this.data,
      failure: failure == null ? this.failure : failure(),
    );
  }

  @override
  List<Object?> get props => [status, data, failure];
}

/// {@template artifacts_cubit}
/// Entregas: reads the deliveries, the catalogue and the goals, and hands
/// every change to the server, replacing them with what it answers.
///
/// Removing a delivery takes what waited in the backlog for it off the day
/// too, so [onDayChanged] is told, and the timeline reads itself again.
/// {@endtemplate}
class ArtifactsCubit extends Cubit<ArtifactsState> {
  /// {@macro artifacts_cubit}
  ArtifactsCubit({
    required this._repository,
    this.onDayChanged,
    ArtifactsState initial = const ArtifactsState(),
  }) : super(initial);

  final ArtifactsRepository _repository;

  /// Called after a change that moved something on or off the day.
  final void Function()? onDayChanged;

  /// Reads everything.
  Future<void> load() => _run(_repository.load);

  /// Puts a delivery in the queue.
  Future<bool> create({
    required String title,
    CatalogType? type,
    int? minutes,
    int? value,
    int? blockMinutes,
    DateTime? deadline,
    bool top = false,
  }) => _run(
    () => _repository.create(
      title: title,
      typeId: type?.id,
      minutes: minutes,
      value: value,
      blockMinutes: blockMinutes,
      deadline: deadline,
      top: top,
    ),
  );

  /// Renames a delivery.
  Future<void> rename(String id, String title) =>
      _run(() => _repository.update(id, title: title));

  /// Saves a delivery's notes.
  Future<void> saveNotes(String id, String notes) =>
      _run(() => _repository.update(id, notes: notes));

  /// Moves a delivery's deadline by [days], which may be negative.
  Future<void> shiftDeadline(String id, int days) {
    final deadline = state.byId(id)?.deadline;
    if (deadline == null) return Future.value();

    final moved = DateTime(deadline.year, deadline.month, deadline.day + days);
    return _run(() => _repository.update(id, deadline: () => moved));
  }

  /// Gives a delivery a deadline, or takes it away with null.
  Future<void> setDeadline(String id, DateTime? deadline) =>
      _run(() => _repository.update(id, deadline: () => deadline));

  /// Marks a delivery delivered, or open again.
  Future<void> setDone(String id, {required bool done}) =>
      _run(() => _repository.update(id, done: done));

  /// Moves a delivery to [index] in the queue, drawn there at once.
  Future<void> move(String id, int index) {
    final data = state.data;
    if (data != null) {
      final queue = data.queue;
      final moving = queue.where((a) => a.id == id).firstOrNull;
      if (moving != null) {
        queue
          ..remove(moving)
          ..insert(index.clamp(0, queue.length), moving);
        emit(
          state.copyWith(
            data: ArtifactsData(
              artifacts: [...queue, ...data.done],
              catalog: data.catalog,
              goals: data.goals,
              schedule: data.schedule,
              topTypes: data.topTypes,
            ),
          ),
        );
      }
    }
    return _run(() => _repository.move(id, index));
  }

  /// Removes a delivery, and what waited in the backlog for it, so the day
  /// reads itself again.
  Future<void> delete(String id) async {
    if (await _run(() => _repository.delete(id))) onDayChanged?.call();
  }

  /// Writes a kind down in the catalogue.
  Future<bool> addType({
    required String name,
    required int minutes,
    int? price,
    int? blockMinutes,
    String? categoryId,
    String? category,
  }) => _run(
    () => _repository.addType(
      name: name,
      minutes: minutes,
      price: price,
      blockMinutes: blockMinutes,
      categoryId: categoryId,
      category: category,
    ),
  );

  /// Writes a goal down.
  Future<bool> addGoal({
    required GoalKind kind,
    required int target,
    required GoalPeriod period,
    CatalogType? type,
    bool next = false,
  }) => _run(
    () => _repository.addGoal(
      kind: kind,
      target: target,
      period: period,
      typeId: type?.id,
      next: next,
    ),
  );

  /// Removes a goal.
  Future<void> deleteGoal(String id) => _run(() => _repository.deleteGoal(id));

  /// Forgets the last refusal, once it has been shown.
  void failureShown() => emit(state.copyWith(failure: () => null));

  Future<bool> _run(Future<ArtifactsData> Function() call) async {
    try {
      final data = await call();
      emit(
        state.copyWith(
          status: ArtifactsStatus.ready,
          data: data,
          failure: () => null,
        ),
      );
      return true;
    } on ArtifactsFailure catch (failure) {
      emit(
        state.copyWith(
          status: state.status == ArtifactsStatus.loading
              ? ArtifactsStatus.failure
              : state.status,
          failure: () => failure,
        ),
      );
      return false;
    }
  }
}
