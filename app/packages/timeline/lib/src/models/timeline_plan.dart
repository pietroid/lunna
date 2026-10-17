import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:timeline/src/models/timeline_event.dart';
import 'package:timeline/src/models/work_day.dart';

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
    this.beforeBlock = false,
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

  /// Whether a block comes right after it, rather than the end of the day,
  /// so something dropped here has to end a pause before [end].
  final bool beforeBlock;

  /// The latest a block of [minutes] dropped here could start and still end
  /// in time, pause included. Never before [earliest].
  DateTime latestStart(int minutes) {
    final room = beforeBlock ? end.subtract(TimelinePlan.gap) : end;
    final latest = room.subtract(Duration(minutes: minutes));
    return latest.isBefore(earliest) ? earliest : latest;
  }

  /// How long a block dropped here can be and still fit.
  int get capacityMinutes => end.difference(earliest).inMinutes;

  /// Whether [at] falls inside it.
  bool contains(DateTime at) => !at.isBefore(start) && at.isBefore(end);

  @override
  List<Object?> get props => [start, end, earliest, index, beforeBlock];
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
///
/// Every answer is inside a [WorkDay], the one the server last sent, so the
/// phone and the server agree on when the day starts and ends.
abstract final class TimelinePlan {
  /// The breathing room left between two blocks.
  static const gap = Duration(minutes: 5);

  /// How close one block has to start after another to be snapped to it,
  /// and come along when it moves or stretches: the pause and five minutes
  /// of slack. The server's own rule, `SNAP_MINUTES`.
  static const snap = Duration(minutes: 10);

  /// Where a new task would land: the end of the queue, from [now] or after
  /// the last of [tasks], whichever is later, in the first room that fits
  /// among [cards].
  ///
  /// The queue has no gaps the next task could slip into: each task starts
  /// looking where the one before it ended, so a new one at the end of it
  /// starts looking where the last one ends.
  static DateTime nextQueuedStart(
    List<TimelineEvent> cards,
    List<TimelineEvent> tasks,
    Duration duration, {
    DateTime? now,
    WorkDay workDay = WorkDay.standard,
  }) {
    final present = now ?? clock.now();
    final last = tasks.isEmpty ? null : tasks.last.endTime.add(gap);

    return nextFreeStart(
      cards,
      duration,
      now: last != null && last.isAfter(present) ? last : present,
      workDay: workDay,
    );
  }

  /// The first slot of [duration] that fits from [now], moving nothing.
  ///
  /// Walks the day forward: each card it runs into pushes the candidate to
  /// the end of that card plus the gap, and a candidate that spills past the
  /// end of the day starts again at the top of the next one.
  static DateTime nextFreeStart(
    List<TimelineEvent> cards,
    Duration duration, {
    DateTime? now,
    WorkDay workDay = WorkDay.standard,
  }) {
    final booked = [...cards]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    var start = now ?? clock.now();

    // One pass per block it steps over, plus one per day it spills out of.
    for (var attempt = 0; attempt < 500; attempt++) {
      // Stepping past a block can land outside the day: before it opens,
      // after a block that ran past midnight, or after it has closed.
      start = _earliest(start, workDay);
      final end = start.add(duration);
      final dayEnd = workDay.endOn(start);

      if (end.isAfter(dayEnd)) {
        start = workDay.startOn(
          DateTime(start.year, start.month, start.day + 1),
        );
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
  /// and all of the [days] after it counting today, earliest first.
  ///
  /// Everything on the day takes room, meetings included, and a stretch has
  /// to be longer than [gap] to count. The ends of the working day are edges
  /// like any block, so an empty morning and an empty evening are free
  /// stretches too.
  static List<FreeSlot> freeSlots(
    List<TimelineEvent> cards, {
    DateTime? now,
    int days = 2,
    WorkDay workDay = WorkDay.standard,
  }) {
    final present = now ?? clock.now();
    final sorted = [...cards]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final slots = <FreeSlot>[];

    for (var offset = 0; offset < days; offset++) {
      final date = DateTime(present.year, present.month, present.day + offset);
      final dayStart = workDay.startOn(date);
      final dayEnd = workDay.endOn(date);
      var cursor = offset == 0 && present.isAfter(dayStart)
          ? _toMinute(present)
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
              beforeBlock: true,
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
  static DateTime _earliest(DateTime at, WorkDay workDay) {
    final dayStart = workDay.startOn(at);
    final dayEnd = workDay.endOn(at);

    if (at.isBefore(dayStart)) return dayStart;
    if (at.isBefore(dayEnd)) return _toMinute(at);

    return workDay.startOn(DateTime(at.year, at.month, at.day + 1));
  }

  /// [at] with its seconds dropped. Exactly the gap after what it hit, not
  /// the next five, which is what the server does too.
  static DateTime _toMinute(DateTime at) {
    return DateTime(at.year, at.month, at.day, at.hour, at.minute);
  }
}
