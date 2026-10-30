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

  test('weekends are days off until the person says otherwise', () {
    expect(const RestRules().saturday, DayKind.off);
    expect(const RestRules().sunday, DayKind.off);
    expect(RestRules.fromJson(null).sunday, DayKind.off);
  });
}
