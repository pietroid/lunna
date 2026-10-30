import 'package:equatable/equatable.dart';
import 'package:timeline/timeline.dart';

/// {@template cycle}
/// The person's menstrual cycle, as they tell it: the first day of the
/// last period, how long a cycle lasts and how long the period, and what a
/// day of the period is to the queue.
///
/// Every phase is worked out from those: the period from its first day,
/// ovulation fourteen days before the next one, the follicular phase
/// between, the luteal after. **The prediction is the person's to
/// correct**: [nextStart], set from a tap on the grid, says when the next
/// period will begin, and the cycles after it count from there. The server
/// works the phases out the same way for the timeline's [DayMark]s; this
/// copy draws the next 30 days on the cycle's page.
/// {@endtemplate}
class Cycle extends Equatable {
  /// {@macro cycle}
  const Cycle({
    required this.lastStart,
    this.length = 28,
    this.periodLength = 5,
    this.periodKind = DayKind.light,
    this.nextStart,
  });

  /// Reads one from the API's JSON.
  factory Cycle.fromJson(Map<String, dynamic> json) => Cycle(
    lastStart: DateTime.parse(json['lastStart'] as String),
    length: json['length'] as int? ?? 28,
    periodLength: json['periodLength'] as int? ?? 5,
    periodKind: DayKind.parse(json['periodKind']),
    nextStart: switch (json['nextStart']) {
      final String day => DateTime.parse(day),
      _ => null,
    },
  );

  /// The first day of the last period, at midnight.
  final DateTime lastStart;

  /// How many days a cycle lasts, from one period's first day to the next.
  final int length;

  /// How many days the period lasts.
  final int periodLength;

  /// What a day of the period is to the queue: light by default.
  final DayKind periodKind;

  /// When the next period will begin, as the person corrected it; null
  /// while the prediction ([lastStart] plus [length]) stands.
  final DateTime? nextStart;

  /// When the next period is expected: [nextStart], or the prediction.
  DateTime get predictedStart =>
      nextStart ?? _plus(lastStart, length);

  /// Which day of its cycle [day] is, from 1, or null before [lastStart].
  int? dayOn(DateTime day) => _place(day)?.$1;

  /// How long the cycle [day] falls in lasts: [length], or up to a
  /// corrected [nextStart].
  int? lengthOn(DateTime day) => _place(day)?.$2;

  /// The day of its cycle and that cycle's length. Before [nextStart] the
  /// cycle runs from [lastStart] to it; from it on, cycles of [length].
  (int, int)? _place(DateTime day) {
    final next = nextStart;
    if (next != null && !_utc(day).isBefore(_utc(next))) {
      return (_daysBetween(next, day) % length + 1, length);
    }
    final days = _daysBetween(lastStart, day);
    if (days < 0) return null;
    if (next != null) return (days + 1, _daysBetween(lastStart, next));

    return (days % length + 1, length);
  }

  /// The phase [day] falls in, or null before [lastStart].
  CyclePhase? phaseOn(DateTime day) {
    final place = _place(day);
    if (place == null) return null;
    final (at, cycleLength) = place;
    // Ovulation falls fourteen days before the next period, the part of
    // the cycle that varies least.
    final ovulation = cycleLength - 14;
    if (at <= periodLength) return CyclePhase.menstrual;
    if (at < ovulation - 1) return CyclePhase.follicular;
    if (at <= ovulation + 1) return CyclePhase.ovulatory;

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

  /// A copy with the given fields replaced. [nextStart] is replaced
  /// whole: pass null to go back to the prediction.
  Cycle copyWith({
    DateTime? lastStart,
    int? length,
    int? periodLength,
    DayKind? periodKind,
    DateTime? Function()? nextStart,
  }) => Cycle(
    lastStart: lastStart ?? this.lastStart,
    length: length ?? this.length,
    periodLength: periodLength ?? this.periodLength,
    periodKind: periodKind ?? this.periodKind,
    nextStart: nextStart == null ? this.nextStart : nextStart(),
  );

  static DateTime _utc(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day);

  static int _daysBetween(DateTime from, DateTime to) =>
      _utc(to).difference(_utc(from)).inDays;

  static DateTime _plus(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  @override
  List<Object?> get props => [
    lastStart,
    length,
    periodLength,
    periodKind,
    nextStart,
  ];
}

/// {@template day_off}
/// A date written down in Folgas: a day off (a holiday, a trip), or a day
/// of the weekend put back to work ([kind] work). A date the person wrote
/// down wins over the weekend and the cycle.
/// {@endtemplate}
class DayOff extends Equatable {
  /// {@macro day_off}
  const DayOff({
    required this.id,
    required this.day,
    this.title = '',
    this.kind = DayKind.off,
  });

  /// Reads one from the API's JSON.
  factory DayOff.fromJson(Map<String, dynamic> json) => DayOff(
    id: json['id'] as String,
    day: DateTime.parse(json['day'] as String),
    title: json['title'] as String? ?? '',
    kind: DayKind.parse(json['kind'] ?? 'off'),
  );

  /// Its id.
  final String id;

  /// The day, at midnight.
  final DateTime day;

  /// What it is, as the person named it.
  final String title;

  /// What the day is: off, or a weekend day put back to work.
  final DayKind kind;

  @override
  List<Object?> get props => [id, day, title, kind];
}

/// {@template rest_rules}
/// What the weekend is to the queue, and how much a light day takes.
///
/// Saturdays and Sundays are days off until the person says otherwise,
/// here for every weekend or in Folgas' list for one.
/// {@endtemplate}
class RestRules extends Equatable {
  /// {@macro rest_rules}
  const RestRules({
    this.saturday = DayKind.off,
    this.sunday = DayKind.off,
    this.lightMinutes = 180,
  });

  /// Reads them from the API's JSON.
  factory RestRules.fromJson(Map<String, dynamic>? json) => RestRules(
    saturday: DayKind.parse(json?['saturday'] ?? 'off'),
    sunday: DayKind.parse(json?['sunday'] ?? 'off'),
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

  /// The dates written down ahead, off or put back to work, earliest
  /// first.
  final List<DayOff> daysOff;

  @override
  List<Object?> get props => [cycle, rules, daysOff];
}
