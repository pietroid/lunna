import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:projects/src/data/projects_repository.dart';
import 'package:projects/src/models/models.dart';

/// Whether the projects have been read yet.
enum ProjectsStatus {
  /// Not read yet.
  loading,

  /// Read.
  ready,

  /// The last read or write failed.
  failure,
}

/// {@template projects_state}
/// Every project, as the server last sent them.
/// {@endtemplate}
class ProjectsState extends Equatable {
  /// {@macro projects_state}
  const ProjectsState({
    this.status = ProjectsStatus.loading,
    this.projects = const [],
    this.failure,
  });

  /// Whether they have been read.
  final ProjectsStatus status;

  /// Every project, the open ones first.
  final List<Project> projects;

  /// What the last write was refused with, until the next one.
  final ProjectsFailure? failure;

  /// The projects not marked done.
  List<Project> get open => [
    for (final p in projects)
      if (!p.isDone) p,
  ];

  /// The projects marked done, most recent first.
  List<Project> get done => [
    for (final p in projects)
      if (p.isDone) p,
  ]..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));

  /// The project with [id], if it is still there.
  Project? byId(String id) {
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// A copy with the given fields changed.
  ProjectsState copyWith({
    ProjectsStatus? status,
    List<Project>? projects,
    ProjectsFailure? Function()? failure,
  }) {
    return ProjectsState(
      status: status ?? this.status,
      projects: projects ?? this.projects,
      failure: failure == null ? this.failure : failure(),
    );
  }

  @override
  List<Object?> get props => [status, projects, failure];
}

/// {@template projects_cubit}
/// The Projetos tab: reads the projects, and hands every change to the
/// server, replacing them with what it answers.
///
/// A task let out of a project, or taken back, changes the day too, so
/// [onDayChanged] is told, and the timeline reads itself again.
/// {@endtemplate}
class ProjectsCubit extends Cubit<ProjectsState> {
  /// {@macro projects_cubit}
  ProjectsCubit({
    required this._repository,
    this.onDayChanged,
    ProjectsState initial = const ProjectsState(),
  }) : super(initial);

  final ProjectsRepository _repository;

  /// Called after a change that moved something on or off the day.
  final void Function()? onDayChanged;

  /// Reads every project.
  Future<void> load() => _run(_repository.list);

  /// Writes a new project down.
  Future<void> create(String title, {DateTime? deadline}) =>
      _run(() => _repository.create(title: title, deadline: deadline));

  /// Renames a project.
  Future<void> rename(String id, String title) =>
      _run(() => _repository.update(id, title: title));

  /// Saves a project's notes.
  Future<void> saveNotes(String id, String notes) =>
      _run(() => _repository.update(id, notes: notes));

  /// Moves a project's deadline by [days], which may be negative.
  Future<void> shiftDeadline(String id, int days) {
    final deadline = state.byId(id)?.deadline;
    if (deadline == null) return Future.value();

    final moved = DateTime(deadline.year, deadline.month, deadline.day + days);
    return _run(() => _repository.update(id, deadline: () => moved));
  }

  /// Gives a project a deadline, or takes it away with null.
  Future<void> setDeadline(String id, DateTime? deadline) =>
      _run(() => _repository.update(id, deadline: () => deadline));

  /// Marks a project done, or open again.
  Future<void> setDone(String id, {required bool done}) =>
      _run(() => _repository.update(id, done: done));

  /// Removes a project, and what waited in the backlog for it, so the day
  /// reads itself again.
  Future<void> delete(String id) async {
    if (await _run(() => _repository.delete(id))) onDayChanged?.call();
  }

  /// Forgets the last refusal, once it has been shown.
  void failureShown() => emit(state.copyWith(failure: () => null));

  Future<bool> _run(Future<List<Project>> Function() call) async {
    try {
      final projects = await call();
      emit(
        state.copyWith(
          status: ProjectsStatus.ready,
          projects: projects,
          failure: () => null,
        ),
      );
      return true;
    } on ProjectsFailure catch (failure) {
      emit(
        state.copyWith(
          status: state.status == ProjectsStatus.loading
              ? ProjectsStatus.failure
              : state.status,
          failure: () => failure,
        ),
      );
      return false;
    }
  }
}
