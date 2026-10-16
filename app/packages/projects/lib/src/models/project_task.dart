import 'package:equatable/equatable.dart';

/// Where a project's task is, as far as the day is concerned.
enum TaskPlace {
  /// Only in the project. The day never sees it.
  project,

  /// In the backlog, "Depois eu priorizo": no hour, in its order.
  backlog,

  /// In the queue, taking the next free hour it fits.
  queue,

  /// Keeping an hour of its own (an anchor).
  scheduled,

  /// Ticked off.
  done,
}

/// {@template project_task}
/// One task of a project.
///
/// It is the same task the day draws: once it leaves [TaskPlace.project]
/// it is in the backlog or on the timeline like any other, and its hour is
/// the queue's to give. [at] is that hour, as the server last worked it out.
/// {@endtemplate}
class ProjectTask extends Equatable {
  /// {@macro project_task}
  const ProjectTask({
    required this.id,
    required this.title,
    required this.minutes,
    required this.place,
    this.at,
    this.doneAt,
  });

  /// Reads a task off the wire.
  factory ProjectTask.fromJson(Map<String, dynamic> json) {
    final at = json['at'] as String?;
    final doneAt = json['doneAt'] as String?;
    return ProjectTask(
      id: json['id'] as String,
      title: json['title'] as String,
      minutes: (json['minutes'] as num).toInt(),
      place: TaskPlace.values.byName(json['place'] as String),
      at: at == null ? null : DateTime.parse(at).toLocal(),
      doneAt: doneAt == null ? null : DateTime.parse(doneAt).toLocal(),
    );
  }

  /// The task's id, the same one the timeline knows it by.
  final String id;

  /// What it is.
  final String title;

  /// How long it takes.
  final int minutes;

  /// Where it is.
  final TaskPlace place;

  /// Its hour, when it is on the timeline.
  final DateTime? at;

  /// When it was ticked off.
  final DateTime? doneAt;

  @override
  List<Object?> get props => [id, title, minutes, place, at, doneAt];
}
