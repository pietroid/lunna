import 'package:chat/chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 9, 24);
  DateTime at(int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  // 14:05 to 17:00, after a block that ended at 14:00.
  final room = FreeSlot(
    start: at(14, 0),
    end: at(17, 0),
    earliest: at(14, 5),
    index: 1,
  );

  group('landingIn', () {
    test('is the start of the room near the top of it', () {
      expect(TimelineScale.landingIn(room, at(14, 8), 30), at(14, 5));
    });

    test('is the nearest quarter of an hour after that', () {
      expect(TimelineScale.landingIn(room, at(15, 22), 30), at(15, 15));
      expect(TimelineScale.landingIn(room, at(15, 23), 30), at(15, 30));
    });

    test('never lets the block run past the room', () {
      expect(TimelineScale.landingIn(room, at(16, 55), 60), at(16, 0));
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
