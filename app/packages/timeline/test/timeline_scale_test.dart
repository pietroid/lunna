import 'package:flutter_test/flutter_test.dart';
import 'package:timeline/timeline.dart';

void main() {
  final day = DateTime(2026, 9, 24);
  DateTime at(int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  // 14:05 to 17:00, after a block that ended at 14:00 and before one that
  // starts at 17:00.
  final room = FreeSlot(
    start: at(14, 0),
    end: at(17, 0),
    earliest: at(14, 5),
    index: 1,
    beforeBlock: true,
  );

  group('landingIn', () {
    test('sticks to the start of the room near the top of it', () {
      expect(TimelineScale.landingIn(room, at(14, 14), 30), at(14, 5));
    });

    test('is the nearest five minutes anywhere else', () {
      expect(TimelineScale.landingIn(room, at(15, 22), 30), at(15, 20));
      expect(TimelineScale.landingIn(room, at(15, 23), 30), at(15, 25));
    });

    test('sticks to the block below, a pause before it, near the bottom', () {
      // 16:25 for half an hour ends at 16:55, five minutes before 17:00.
      expect(TimelineScale.landingIn(room, at(16, 18), 30), at(16, 25));
    });

    test('never lets the block run past the room', () {
      expect(TimelineScale.landingIn(room, at(16, 55), 60), at(15, 55));
    });

    test('runs right to the end of the day, which needs no pause', () {
      final evening = FreeSlot(
        start: at(20, 0),
        end: at(22, 0),
        earliest: at(20, 5),
        index: 2,
      );
      expect(TimelineScale.landingIn(evening, at(21, 50), 30), at(21, 30));
    });

    test('is the start of the room for a block too long for it', () {
      expect(TimelineScale.landingIn(room, at(16, 0), 240), at(14, 5));
    });
  });

  test('timeAt and offsetOf read the same scale', () {
    const height = 300.0;
    final dy = TimelineScale.offsetOf(room, at(15, 30), height);

    expect(TimelineScale.timeAt(room, dy, height), at(15, 30));
  });
}
