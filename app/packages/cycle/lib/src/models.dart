import 'package:equatable/equatable.dart';
import 'package:timeline/timeline.dart';

/// {@template cycle}
/// The person's menstrual cycle, as she tells it: the first day of her
/// last period, how long a cycle lasts and how long the period, and what a
/// day of the period is to the queue.
///
/// Every phase is worked out from those, the way Apple Health predicts
/// them: the period from its first day, ovulation fourteen days before the
/// next one, the follicular phase between, the luteal after. The server
/// works them out the same way for the timeline's [DayMark]s; this copy
/// draws the next 30 days on the cycle's page.
/// {@endtemplate}
class Cycle extends Equatable {
  /// {@macro cycle}
  const Cycle({
    required this.lastStart,
    this.length = 28,
    this.periodLength = 5,
    this.periodKind = DayKind.light,
  });

  /// Reads one from the API's JSON.
  factory Cycle.fromJson(Map<String, dynamic> json) => Cycle(
    lastStart: DateTime.parse(json['lastStart'] as String),
    length: json['length'] as int? ?? 28,
    periodLength: json['periodLength'] as int? ?? 5,
    periodKind: DayKind.parse(json['periodKind']),
  );

  /// The first day of the last period, at midnight.
  final DateTime lastStart;

  /// How many days a cycle lasts, from one period's first day to the next.
  final int length;

  /// How many days the period lasts.
  final int periodLength;

  /// What a day of the period is to the queue: light by default.
  final DayKind periodKind;

  /// The day of the cycle ovulation falls on: fourteen before the next
  /// period, which is the part of the cycle that varies least.
  int get ovulationDay => length - 14;

  /// Which day of its cycle [day] is, from 1, or null before [lastStart].
  int? dayOn(DateTime day) {
    final from = DateTime.utc(lastStart.year, lastStart.month, lastStart.day);
    final to = DateTime.utc(day.year, day.month, day.day);
    final days = to.difference(from).inDays;
    if (days < 0) return null;

    return days % length + 1;
  }

  /// The phase [day] falls in, or null before [lastStart].
  CyclePhase? phaseOn(DateTime day) {
    final at = dayOn(day);
    if (at == null) return null;
    if (at <= periodLength) return CyclePhase.menstrual;
    if (at < ovulationDay - 1) return CyclePhase.follicular;
    if (at <= ovulationDay + 1) return CyclePhase.ovulatory;

    return CyclePhase.luteal;
  }

  /// The last day of the phase [day] falls in.
  DateTime? phaseEnd(DateTime day) {
    final phase = phaseOn(day);
    if (phase == null) return null;
    var end = DateTime(day.year, day.month, day.day);
    while (phaseOn(end.add(const Duration(days: 1))) == phase) {
      end = DateTime(end.year, end.month, end.day + 1);
    }

    return end;
  }

  /// A copy with the given fields replaced.
  Cycle copyWith({
    DateTime? lastStart,
    int? length,
    int? periodLength,
    DayKind? periodKind,
  }) => Cycle(
    lastStart: lastStart ?? this.lastStart,
    length: length ?? this.length,
    periodLength: periodLength ?? this.periodLength,
    periodKind: periodKind ?? this.periodKind,
  );

  @override
  List<Object?> get props => [lastStart, length, periodLength, periodKind];
}

/// {@template day_off}
/// A date written down as a day off: a holiday, a trip.
/// {@endtemplate}
class DayOff extends Equatable {
  /// {@macro day_off}
  const DayOff({required this.id, required this.day, required this.title});

  /// Reads one from the API's JSON.
  factory DayOff.fromJson(Map<String, dynamic> json) => DayOff(
    id: json['id'] as String,
    day: DateTime.parse(json['day'] as String),
    title: json['title'] as String? ?? '',
  );

  /// Its id.
  final String id;

  /// The day, at midnight.
  final DateTime day;

  /// What it is, as the person named it.
  final String title;

  @override
  List<Object?> get props => [id, day, title];
}

/// {@template rest_rules}
/// What the weekend is to the queue, and how much a light day takes.
/// {@endtemplate}
class RestRules extends Equatable {
  /// {@macro rest_rules}
  const RestRules({
    this.saturday = DayKind.work,
    this.sunday = DayKind.work,
    this.lightMinutes = 180,
  });

  /// Reads them from the API's JSON.
  factory RestRules.fromJson(Map<String, dynamic>? json) => RestRules(
    saturday: DayKind.parse(json?['saturday']),
    sunday: DayKind.parse(json?['sunday']),
    lightMinutes: json?['lightMinutes'] as int? ?? 180,
  );

  /// What a Saturday is.
  final DayKind saturday;

  /// What a Sunday is.
  final DayKind sunday;

  /// How many minutes of tasks the queue puts on a light day.
  final int lightMinutes;

  /// A copy with the given fields replaced.
  RestRules copyWith({
    DayKind? saturday,
    DayKind? sunday,
    int? lightMinutes,
  }) => RestRules(
    saturday: saturday ?? this.saturday,
    sunday: sunday ?? this.sunday,
    lightMinutes: lightMinutes ?? this.lightMinutes,
  );

  @override
  List<Object?> get props => [saturday, sunday, lightMinutes];
}

/// {@template rhythm}
/// Everything the cycle's page and Folgas draw: the cycle, when there is
/// one, the weekend's rules and the dates off.
/// {@endtemplate}
class Rhythm extends Equatable {
  /// {@macro rhythm}
  const Rhythm({
    this.cycle,
    this.rules = const RestRules(),
    this.daysOff = const [],
  });

  /// Reads it from the API's JSON (`GET /api/rhythm`).
  factory Rhythm.fromJson(Map<String, dynamic> json) {
    final cycle = json['cycle'] as Map<String, dynamic>?;

    return Rhythm(
      cycle: cycle == null ? null : Cycle.fromJson(cycle),
      rules: RestRules.fromJson(json['rest'] as Map<String, dynamic>?),
      daysOff: [
        for (final day in json['daysOff'] as List<dynamic>? ?? <dynamic>[])
          DayOff.fromJson(day as Map<String, dynamic>),
      ],
    );
  }

  /// The cycle, or null until the first period is written down.
  final Cycle? cycle;

  /// The weekend's rules and the light day's budget.
  final RestRules rules;

  /// The dates off ahead, earliest first.
  final List<DayOff> daysOff;

  @override
  List<Object?> get props => [cycle, rules, daysOff];
}
