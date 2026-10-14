import 'package:equatable/equatable.dart';

/// Which days a routine repeats on.
enum RoutineDays {
  /// Every day.
  daily('daily'),

  /// Monday to Friday.
  weekdays('weekdays'),

  /// Saturday and Sunday.
  weekend('weekend');

  const RoutineDays(this.wire);

  /// The name the API uses.
  final String wire;

  /// The days [wire] names, defaulting to every day.
  static RoutineDays fromWire(String? wire) {
    return RoutineDays.values.firstWhere(
      (days) => days.wire == wire,
      orElse: () => RoutineDays.daily,
    );
  }
}

/// {@template routine}
/// A block that happens on the same days at the same hour: lunch, the
/// morning routine.
///
/// A routine is one rule, written down on each day it falls on as the
/// timeline reaches that day. Flexible unless it says otherwise: each day is
/// a task that keeps the routine's hour, slides when something runs into it
/// and waits to be begun. A fixed one's days are blocks nothing moves.
/// {@endtemplate}
class Routine extends Equatable {
  /// {@macro routine}
  const Routine({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    required this.durationMinutes,
    required this.days,
    this.fixed = false,
  });

  /// Creates a [Routine] from the API's JSON.
  factory Routine.fromJson(Map<String, dynamic> json) {
    final time = (json['time'] as String? ?? '07:00').split(':');

    return Routine(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      hour: int.tryParse(time.first) ?? 7,
      minute: int.tryParse(time.length > 1 ? time[1] : '0') ?? 0,
      durationMinutes: json['durationMinutes'] as int? ?? 30,
      days: RoutineDays.fromWire(json['days'] as String?),
      fixed: json['fixed'] as bool? ?? false,
    );
  }

  /// The recurring event's id.
  final String id;

  /// What it is called.
  final String title;

  /// The hour it starts, on the calendar's clock.
  final int hour;

  /// The minute it starts.
  final int minute;

  /// How long it lasts.
  final int durationMinutes;

  /// Which days it happens on.
  final RoutineDays days;

  /// Whether its hour is the point of it, so nothing ever moves its days.
  final bool fixed;

  /// Minutes past midnight it starts.
  int get startMinute => hour * 60 + minute;

  /// "12:30", the way the API writes the hour.
  String get time =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [
    id,
    title,
    hour,
    minute,
    durationMinutes,
    days,
    fixed,
  ];
}
