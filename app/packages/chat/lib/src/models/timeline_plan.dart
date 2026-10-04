import 'package:chat/src/models/timeline_event.dart';
import 'package:equatable/equatable.dart';

/// {@template free_slot}
/// A stretch of the working day with nothing on it.
///
/// Drawn on the timeline as its own quiet card, and a place a card can be
/// dropped into. Only stretches longer than [TimelinePlan.gap] count: the
/// five minutes between two blocks are the pause, not free time.
/// {@endtemplate}
class FreeSlot extends Equatable {
  /// {@macro free_slot}
  const FreeSlot({
    required this.start,
    required this.end,
    required this.earliest,
    required this.index,
  });

  /// Where the stretch begins: the end of the block before it, now, or the
  /// start of the working day.
  final DateTime start;

  /// Where it ends: the next block, or the end of the working day.
  final DateTime end;

  /// The earliest a block dropped here could start, which is [start] plus the
  /// pause when a block comes right before it.
  final DateTime earliest;

  /// How many cards come before it in the one list, which is the place in
  /// the day's queue a drop into it lands on.
  final int index;

  /// How long a block dropped here can be and still fit.
  int get capacityMinutes => end.difference(earliest).inMinutes;

  /// Whether [at] falls inside it.
  bool contains(DateTime at) => !at.isBefore(start) && at.isBefore(end);

  @override
  List<Object?> get props => [start, end, earliest, index];
}

/// Where something new would land, worked out on the phone.
///
/// The server is what actually decides, and this is deliberately the same
/// arithmetic rather than a request: the creation sheet has to say what time
/// it is proposing while the user is still typing, and a round trip per
/// keystroke to answer a question the phone already has the cards for would
/// be a spinner where a number should be.
///
/// It can be wrong, in one way only: something the user booked on another
/// device since the last load. The next list puts it right.
abstract final class TimelinePlan {
  /// The first hour of the working day.
  static const startHour = 7;

  /// The hour the working day ends.
  static const endHour = 22;

  /// The breathing room left between two blocks.
  static const gap = Duration(minutes: 5);

  /// The first slot of [duration] that fits from [now], moving nothing.
  ///
  /// Walks the day forward: each card it runs into pushes the candidate to
  /// the end of that card plus the gap, and a candidate that spills past the
  /// end of the day starts again at the top of the next one.
  static DateTime nextFreeStart(
    List<TimelineEvent> cards,
    Duration duration, {
    DateTime? now,
  }) {
    final booked = [...cards]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    var start = _earliest(now ?? DateTime.now());

    // One pass per block it steps over, plus one per day it spills out of.
    for (var attempt = 0; attempt < 500; attempt++) {
      final end = start.add(duration);
      final dayEnd = DateTime(start.year, start.month, start.day, endHour);

      if (end.isAfter(dayEnd)) {
        start = DateTime(start.year, start.month, start.day + 1, startHour);
        continue;
      }

      final hit = booked
          .where(
            (card) =>
                start.isBefore(card.endTime) && card.startTime.isBefore(end),
          )
          .firstOrNull;
      if (hit == null) return start;

      start = _toMinute(hit.endTime.add(gap));
    }

    return start;
  }

  /// Every stretch of the working day with nothing on it, today from [now]
  /// and all of tomorrow, earliest first.
  ///
  /// Everything on the day takes room, meetings included, and a stretch has
  /// to be longer than [gap] to count. The ends of the working day are edges
  /// like any block, so an empty morning and an empty evening are free
  /// stretches too.
  static List<FreeSlot> freeSlots(
    List<TimelineEvent> cards, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final sorted = [...cards]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final slots = <FreeSlot>[];

    for (var offset = 0; offset < 2; offset++) {
      final dayStart = DateTime(
        clock.year,
        clock.month,
        clock.day + offset,
        startHour,
      );
      final dayEnd = DateTime(
        clock.year,
        clock.month,
        clock.day + offset,
        endHour,
      );
      var cursor = offset == 0 && clock.isAfter(dayStart)
          ? _toMinute(clock)
          : dayStart;
      if (!cursor.isBefore(dayEnd)) continue;

      // Whether the cursor sits at the end of a block, which is what decides
      // whether something dropped here owes a pause first.
      var afterBlock = false;

      for (var index = 0; index < sorted.length; index++) {
        final card = sorted[index];
        if (!card.endTime.isAfter(cursor)) continue;
        if (!card.startTime.isBefore(dayEnd)) break;

        if (card.startTime.difference(cursor) > gap) {
          slots.add(
            FreeSlot(
              start: cursor,
              end: card.startTime,
              earliest: afterBlock ? cursor.add(gap) : cursor,
              index: index,
            ),
          );
        }

        cursor = card.endTime;
        afterBlock = true;
      }

      if (dayEnd.difference(cursor) > gap) {
        final before = sorted.where((card) => card.startTime.isBefore(dayEnd));
        slots.add(
          FreeSlot(
            start: cursor,
            end: dayEnd,
            earliest: afterBlock ? cursor.add(gap) : cursor,
            index: before.length,
          ),
        );
      }
    }

    return slots;
  }

  /// The earliest [at] could be, given the day has hours.
  static DateTime _earliest(DateTime at) {
    final dayStart = DateTime(at.year, at.month, at.day, startHour);
    final dayEnd = DateTime(at.year, at.month, at.day, endHour);

    if (at.isBefore(dayStart)) return dayStart;
    if (at.isBefore(dayEnd)) {
      return DateTime(at.year, at.month, at.day, at.hour, at.minute);
    }

    return DateTime(at.year, at.month, at.day + 1, startHour);
  }

  /// [at] with its seconds dropped. Exactly the gap after what it hit, not
  /// the next five, which is what the server does too.
  static DateTime _toMinute(DateTime at) {
    return DateTime(at.year, at.month, at.day, at.hour, at.minute);
  }
}
