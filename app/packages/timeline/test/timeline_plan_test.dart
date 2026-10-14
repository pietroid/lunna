import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/timeline.dart';

TimelineEvent _card(String id, DateTime start, int minutes) {
  return TimelineEvent(
    id: id,
    title: id,
    section: TimelineSection.dia,
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

  group('a day of their own', () {
    const workDay = WorkDay(start: 9 * 60 + 30, end: 18 * 60);

    test('the free stretches run in its hours', () {
      final slots = TimelinePlan.freeSlots(
        const [],
        now: DateTime(2026, 9, 23, 8),
        workDay: workDay,
      );

      expect(slots.first.start, at(9, 30));
      expect(slots.first.end, at(18));
      expect(slots.last.start, at(9, 30, 24));
    });

    test('nothing is proposed after it ends', () {
      final start = TimelinePlan.nextFreeStart(
        const [],
        const Duration(hours: 1),
        now: at(17, 30),
        workDay: workDay,
      );

      expect(start, at(9, 30, 24));
    });

    test('a day that runs to midnight does not skip the next one', () {
      const late = WorkDay(start: 8 * 60, end: 24 * 60);

      expect(
        TimelinePlan.nextFreeStart(
          const [],
          const Duration(minutes: 30),
          now: at(23),
          workDay: late,
        ),
        at(23),
      );
      expect(
        TimelinePlan.nextFreeStart(
          [_card('late', at(23, 30), 60)],
          const Duration(minutes: 20),
          now: at(23, 30),
          workDay: late,
        ),
        at(8, 0, 24),
      );
    });

    test('is read off the wire, and falls back when it cannot be', () {
      expect(
        WorkDay.fromJson(const {'start': '06:15', 'end': '24:00'}),
        const WorkDay(start: 375, end: 1440),
      );
      expect(WorkDay.fromJson(null), WorkDay.standard);
      expect(
        WorkDay.fromJson(const {'start': '22:00', 'end': '07:00'}),
        WorkDay.standard,
      );
      expect(const WorkDay(start: 375, end: 1440).toJson(), {
        'start': '06:15',
        'end': '24:00',
      });
    });
  });
}
