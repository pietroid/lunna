import 'package:equatable/equatable.dart';

/// How much work a day takes.
enum DayKind {
  /// A working day: the queue fills it.
  work,

  /// A light day: the queue puts at most [DayMark.budgetMinutes] of tasks
  /// on it, and none of a delivery's.
  light,

  /// A day off: the queue puts nothing on it.
  off;

  /// The kind the API names [raw], or a working day for one it does not
  /// know.
  static DayKind parse(Object? raw) => switch (raw) {
    'light' => DayKind.light,
    'off' => DayKind.off,
    _ => DayKind.work,
  };
}

/// Why a day is not a working day.
enum DayReason {
  /// It is a Saturday or a Sunday, set aside in Folgas.
  weekend,

  /// A day of the period, as the cycle sets it.
  period,

  /// A date written down in Folgas: a holiday, a trip.
  dayOff;

  /// The reason the API names [raw].
  static DayReason? parse(Object? raw) => switch (raw) {
    'weekend' => DayReason.weekend,
    'period' => DayReason.period,
    'day_off' => DayReason.dayOff,
    _ => null,
  };
}

/// The four phases of a menstrual cycle, in their order.
enum CyclePhase {
  /// The period: from its first day to its last.
  menstrual,

  /// From the end of the period to the days around ovulation.
  follicular,

  /// The days around ovulation.
  ovulatory,

  /// From after ovulation to the next period.
  luteal;

  /// The phase the API names [raw].
  static CyclePhase? parse(Object? raw) => switch (raw) {
    'menstrual' => CyclePhase.menstrual,
    'follicular' => CyclePhase.follicular,
    'ovulatory' => CyclePhase.ovulatory,
    'luteal' => CyclePhase.luteal,
    _ => null,
  };
}

/// {@template day_mark}
/// What the server knows about one day beyond its cards: how much work it
/// takes and why, and the day of the cycle it is.
///
/// The timeline carries one for every day it draws that is not a plain
/// working day, or that has a cycle to tell.
/// {@endtemplate}
class DayMark extends Equatable {
  /// {@macro day_mark}
  const DayMark({
    required this.day,
    this.kind = DayKind.work,
    this.reason,
    this.budgetMinutes,
    this.cycleDay,
    this.cycleLength,
    this.phase,
  });

  /// Reads one from the API's JSON.
  factory DayMark.fromJson(Map<String, dynamic> json) {
    final cycle = json['cycle'] as Map<String, dynamic>?;

    return DayMark(
      day: DateTime.parse(json['day'] as String),
      kind: DayKind.parse(json['kind']),
      reason: DayReason.parse(json['reason']),
      budgetMinutes: json['budgetMinutes'] as int?,
      cycleDay: cycle?['day'] as int?,
      cycleLength: cycle?['length'] as int?,
      phase: CyclePhase.parse(cycle?['phase']),
    );
  }

  /// The day, at midnight in the person's zone.
  final DateTime day;

  /// How much work it takes.
  final DayKind kind;

  /// Why it is not a working day; null on one.
  final DayReason? reason;

  /// How many minutes of tasks a light day takes.
  final int? budgetMinutes;

  /// Which day of the cycle it is, from 1; null without a cycle.
  final int? cycleDay;

  /// How many days the cycle it is in lasts.
  final int? cycleLength;

  /// The phase of the cycle it is in.
  final CyclePhase? phase;

  /// Whether it is anything but a plain working day.
  bool get restricted => kind != DayKind.work;

  @override
  List<Object?> get props => [
    day,
    kind,
    reason,
    budgetMinutes,
    cycleDay,
    cycleLength,
    phase,
  ];
}

/// Finding a day's mark in a list of them.
extension DayMarks on List<DayMark> {
  /// The mark of the day [at] falls on, or null when it has none.
  DayMark? on(DateTime at) {
    for (final mark in this) {
      if (mark.day.year == at.year &&
          mark.day.month == at.month &&
          mark.day.day == at.day) {
        return mark;
      }
    }

    return null;
  }
}
