import 'package:chat/chat.dart';
import 'package:flutter_test/flutter_test.dart';

TimelineEvent _card(String id, DateTime start, int minutes) {
  return TimelineEvent(
    id: id,
    title: id,
    section: TimelineSection.hoje,
    startTime: start,
    endTime: start.add(Duration(minutes: minutes)),
    durationMinutes: minutes,
  );
}

void main() {
  /// Ten in the morning.
  final now = DateTime(2026, 9, 23, 10);
  DateTime at(int hour, [int minute = 0, int day = 23]) =>
      DateTime(2026, 9, day, hour, minute);

  group('free stretches', () {
    test('an empty day is free from now to ten, and all of tomorrow', () {
      final slots = TimelinePlan.freeSlots(const [], now: now);

      expect(slots, [
        FreeSlot(start: now, end: at(22), earliest: now, index: 0),
        FreeSlot(
          start: at(7, 0, 24),
          end: at(22, 0, 24),
          earliest: at(7, 0, 24),
          index: 0,
        ),
      ]);
    });

    test('the pause between two blocks is not free time', () {
      final cards = [
        _card('a', at(10), 30),
        _card('b', at(10, 35), 30),
        _card('c', at(11, 10), 30),
      ];

      final today = TimelinePlan.freeSlots(
        cards,
        now: now,
      ).where((slot) => slot.start.day == 23);

      // Five minutes apart, twice, and then the evening.
      expect(today, hasLength(1));
      expect(today.single.start, at(11, 40));
    });

    test('a gap is room for its length less the pause after a block', () {
      final cards = [_card('a', at(10), 30), _card('b', at(12), 30)];

      final gap = TimelinePlan.freeSlots(cards, now: now).first;

      expect(gap.start, at(10, 30));
      expect(gap.earliest, at(10, 35));
      expect(gap.capacityMinutes, 85);
      // It sits before "b", which is the place a drop into it lands on.
      expect(gap.index, 1);
    });

    test('the start of the day owes no pause', () {
      final cards = [_card('a', at(9, 0, 24), 60)];

      final morning = TimelinePlan.freeSlots(
        cards,
        now: now,
      ).where((slot) => slot.start.day == 24).first;

      expect(morning.start, at(7, 0, 24));
      expect(morning.capacityMinutes, 120);
      expect(morning.index, 0);
    });

    test('nothing is free after ten at night', () {
      final late = DateTime(2026, 9, 23, 22, 30);

      final slots = TimelinePlan.freeSlots(const [], now: late);

      expect(slots.single.start, at(7, 0, 24));
    });
  });
}
