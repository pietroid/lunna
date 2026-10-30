import 'package:cycle/cycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/timeline.dart';

void main() {
  final cycle = Cycle(lastStart: DateTime(2026, 10, 28));

  group('Cycle', () {
    test('counts the days of the cycle from the last start', () {
      expect(cycle.dayOn(DateTime(2026, 10, 27)), isNull);
      expect(cycle.dayOn(DateTime(2026, 10, 28)), 1);
      expect(cycle.dayOn(DateTime(2026, 11, 25)), 1);
      expect(cycle.predictedStart, DateTime(2026, 11, 25));
    });

    test('works the phases out from the lengths', () {
      expect(cycle.phaseOn(DateTime(2026, 10, 31)), CyclePhase.menstrual);
      expect(cycle.phaseOn(DateTime(2026, 11, 2)), CyclePhase.follicular);
      // Day 14 of 28, and the days either side of it.
      expect(cycle.phaseOn(DateTime(2026, 11, 10)), CyclePhase.ovulatory);
      expect(cycle.phaseOn(DateTime(2026, 11, 12)), CyclePhase.luteal);
    });

    test('a corrected next start moves the next period and every one '
        'after it', () {
      final moved = cycle.copyWith(nextStart: () => DateTime(2026, 11, 23));

      expect(moved.predictedStart, DateTime(2026, 11, 23));
      // The cycle running now is 26 days long.
      expect(moved.dayOn(DateTime(2026, 11, 22)), 26);
      expect(moved.lengthOn(DateTime(2026, 11, 22)), 26);
      expect(moved.phaseOn(DateTime(2026, 11, 23)), CyclePhase.menstrual);
      expect(moved.phaseOn(DateTime(2026, 11, 25)), CyclePhase.menstrual);
      expect(moved.dayOn(DateTime(2026, 12, 21)), 1);
      expect(
        moved.copyWith(nextStart: () => null).predictedStart,
        DateTime(2026, 11, 25),
      );
    });
  });

  test('a 35-day cycle moves ovulation and the next period', () {
    final long = Cycle(lastStart: DateTime(2026, 10, 28), length: 35);
    // Ovulation is fourteen days before the next period: day 21.
    expect(long.phaseOn(DateTime(2026, 11, 14)), CyclePhase.follicular);
    expect(long.phaseOn(DateTime(2026, 11, 17)), CyclePhase.ovulatory);
    expect(long.phaseOn(DateTime(2026, 11, 20)), CyclePhase.luteal);
    expect(long.predictedStart, DateTime(2026, 12, 2));
  });

  test('reads the rhythm the server answers', () {
    final rhythm = Rhythm.fromJson(const {
      'cycle': {
        'lastStart': '2026-10-28',
        'length': 30,
        'periodLength': 4,
        'periodKind': 'off',
        'nextStart': '2026-11-25',
        'predictedStart': '2026-11-25',
      },
      'rest': {'saturday': 'work', 'sunday': 'off', 'lightMinutes': 120},
      'daysOff': [
        {'id': 'a', 'day': '2026-11-20', 'title': 'Feriado', 'kind': 'off'},
        {'id': 'b', 'day': '2026-11-07', 'title': '', 'kind': 'work'},
      ],
    });
    expect(
      rhythm.cycle,
      Cycle(
        lastStart: DateTime(2026, 10, 28),
        length: 30,
        periodLength: 4,
        periodKind: DayKind.off,
        nextStart: DateTime(2026, 11, 25),
      ),
    );
    expect(
      rhythm.rules,
      const RestRules(saturday: DayKind.work, lightMinutes: 120),
    );
    expect(rhythm.daysOff.map((it) => it.kind), [DayKind.off, DayKind.work]);
    expect(Rhythm.fromJson(const {'cycle': null}).cycle, isNull);
  });

  test('weekends are days off until the person says otherwise', () {
    expect(const RestRules().saturday, DayKind.off);
    expect(const RestRules().sunday, DayKind.off);
    expect(RestRules.fromJson(null).sunday, DayKind.off);
  });
}
