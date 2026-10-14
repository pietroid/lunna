import 'package:equatable/equatable.dart';

/// {@template work_day}
/// When someone's working day runs: nothing is laid out outside it.
///
/// Each edge is minutes after midnight, and [end] may be 1440, the midnight
/// that closes the day. The server keeps it and sends it with every day it
/// draws, so the free stretches on the calendar and the queue the server
/// lays out are cut from the same hours.
/// {@endtemplate}
class WorkDay extends Equatable {
  /// {@macro work_day}
  const WorkDay({required this.start, required this.end});

  /// Reads `{start: "07:00", end: "22:00"}`, or [standard] when it is not
  /// there or not readable.
  factory WorkDay.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return standard;

    final start = minutesOf(json['start']);
    final end = minutesOf(json['end']);
    if (start == null || end == null || end <= start) return standard;

    return WorkDay(start: start, end: end);
  }

  /// The day nobody has changed: seven in the morning to ten at night.
  static const standard = WorkDay(start: 7 * 60, end: 22 * 60);

  /// The shortest day the server accepts.
  static const minimum = Duration(hours: 1);

  /// Minutes after midnight it starts.
  final int start;

  /// Minutes after midnight it ends.
  final int end;

  /// Where it starts on the day [date] is in.
  DateTime startOn(DateTime date) =>
      DateTime(date.year, date.month, date.day, 0, start);

  /// Where it ends on the day [date] is in.
  DateTime endOn(DateTime date) =>
      DateTime(date.year, date.month, date.day, 0, end);

  /// A copy with the given edges replaced.
  WorkDay copyWith({int? start, int? end}) =>
      WorkDay(start: start ?? this.start, end: end ?? this.end);

  /// As the server reads it.
  Map<String, dynamic> toJson() => {
    'start': formatMinutes(start),
    'end': formatMinutes(end),
  };

  /// "07:30" for 450.
  static String formatMinutes(int minutes) {
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final rest = (minutes % 60).toString().padLeft(2, '0');

    return '$hours:$rest';
  }

  /// 450 for "07:30", or null when it is not a time of day.
  static int? minutesOf(Object? raw) {
    if (raw is! String) return null;
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(raw);
    if (match == null) return null;

    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final total = hours * 60 + minutes;
    if (minutes > 59 || total > 24 * 60) return null;

    return total;
  }

  @override
  List<Object?> get props => [start, end];
}
