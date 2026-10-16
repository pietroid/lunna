import 'package:equatable/equatable.dart';
import 'package:projects/src/models/project_task.dart';

/// {@template project}
/// A subject that outlives a day: a name, an optional deadline, free-text
/// notes, and the tasks it holds.
///
/// The deadline is a day, not an hour: the project is due by the end of it.
/// The bar on it is time, not tasks: how much of the stretch from the day it
/// was written down to the deadline has gone by.
/// {@endtemplate}
class Project extends Equatable {
  /// {@macro project}
  const Project({
    required this.id,
    required this.title,
    required this.createdAt,
    this.deadline,
    this.doneAt,
    this.notes = '',
    this.tasks = const [],
  });

  /// Reads a project off the wire. The deadline is a day, `YYYY-MM-DD`,
  /// and is read as that day on this device.
  factory Project.fromJson(Map<String, dynamic> json) {
    final deadline = json['deadline'] as String?;
    final doneAt = json['doneAt'] as String?;
    return Project(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      deadline: deadline == null ? null : _day(deadline),
      doneAt: doneAt == null ? null : DateTime.parse(doneAt).toLocal(),
      tasks: [
        for (final task in json['tasks'] as List<dynamic>? ?? const [])
          ProjectTask.fromJson(task as Map<String, dynamic>),
      ],
    );
  }

  static DateTime _day(String raw) {
    final [year, month, day] = raw.split('-').map(int.parse).toList();
    return DateTime(year, month, day);
  }

  /// The project's id.
  final String id;

  /// Its name.
  final String title;

  /// When it was written down, which is where its bar starts.
  final DateTime createdAt;

  /// The day it is due by, or null when it has none.
  final DateTime? deadline;

  /// When it was marked done.
  final DateTime? doneAt;

  /// Free text.
  final String notes;

  /// Its tasks, in their order.
  final List<ProjectTask> tasks;

  /// Whether it has been marked done.
  bool get isDone => doneAt != null;

  /// The moment it is due: the end of its deadline's day.
  DateTime? get dueAt {
    final day = deadline;
    if (day == null) return null;
    return DateTime(day.year, day.month, day.day + 1);
  }

  /// How much of its time has gone by, from 0 to 1, or null with no
  /// deadline.
  double? progressAt(DateTime now) {
    final due = dueAt;
    if (due == null) return null;

    final total = due.difference(createdAt).inMinutes;
    if (total <= 0) return 1;
    return (now.difference(createdAt).inMinutes / total).clamp(0, 1);
  }

  /// Whole days from [now]'s day to the deadline: 0 on the day itself,
  /// negative once it has passed. Null with no deadline.
  int? daysLeftAt(DateTime now) {
    final day = deadline;
    if (day == null) return null;
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }

  /// How many of its tasks are done.
  int get doneCount => tasks.where((t) => t.place == TaskPlace.done).length;

  /// A copy with the given fields changed.
  Project copyWith({
    String? title,
    DateTime? Function()? deadline,
    DateTime? Function()? doneAt,
    String? notes,
    List<ProjectTask>? tasks,
  }) {
    return Project(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      deadline: deadline == null ? this.deadline : deadline(),
      doneAt: doneAt == null ? this.doneAt : doneAt(),
      notes: notes ?? this.notes,
      tasks: tasks ?? this.tasks,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    createdAt,
    deadline,
    doneAt,
    notes,
    tasks,
  ];
}
