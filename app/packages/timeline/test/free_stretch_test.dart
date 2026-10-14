import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/timeline.dart';

void main() {
  group('a tap on a stretch', () {
    FreeStretch between(DateTime start, DateTime end, {bool block = true}) =>
        FreeStretch(
          slot: FreeSlot(
            start: start,
            end: end,
            earliest: start.add(TimelinePlan.gap),
            index: 0,
            beforeBlock: block,
          ),
        );

    test('fills short room between two blocks', () {
      final stretch = between(
        DateTime(2026, 10, 14, 10),
        DateTime(2026, 10, 14, 10, 45),
      );

      expect(
        stretch.placementAt(DateTime(2026, 10, 14, 10, 5)),
        Placement.at(DateTime(2026, 10, 14, 10, 5), minutes: 35),
      );
    });

    test('keeps the usual length in long room', () {
      final stretch = between(
        DateTime(2026, 10, 14, 10),
        DateTime(2026, 10, 14, 12, 20),
      );

      expect(
        stretch.placementAt(DateTime(2026, 10, 14, 10, 5)).minutes,
        isNull,
      );
      // The last part of a long room is short again.
      expect(
        stretch.placementAt(DateTime(2026, 10, 14, 12)).minutes,
        15,
      );
    });

    test('keeps the usual length before the end of the day', () {
      final stretch = between(
        DateTime(2026, 10, 14, 21, 30),
        DateTime(2026, 10, 14, 22),
        block: false,
      );

      expect(
        stretch.placementAt(DateTime(2026, 10, 14, 21, 35)).minutes,
        isNull,
      );
    });
  });
}
