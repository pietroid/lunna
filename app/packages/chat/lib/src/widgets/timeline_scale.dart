import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';

/// How much of the screen an hour of the later day takes.
///
/// Half an hour is one card as it was always drawn, with the space under
/// it, so a 25 minute block and the pause after it fill one card exactly, and
/// a 55 minute one fills two. Nothing is drawn shorter than half an hour,
/// because a ten minute block drawn to scale is a sliver nobody can read or
/// hold. The day stretches a little around the short ones instead, which is
/// why the scale is only nearly proportional.
///
/// The pause between two blocks is never drawn as its own thing: it is part
/// of the block before it.
abstract final class TimelineScale {
  /// The height of half an hour, the space under a card included.
  static const double halfHour = AppSpacing.s12 + AppSpacing.s1;

  /// The height of one minute.
  static const double perMinute = halfHour / 30;

  /// The fewest minutes anything is drawn as.
  static const floorMinutes = 30;

  /// Empty room this short is not worth drawing: the next block simply
  /// follows.
  static const shortestStretch = 10;

  /// How tall [card] is drawn, the pause after it included.
  static double blockHeight(TimelineEvent card) =>
      _height(card.durationMinutes + TimelinePlan.gap.inMinutes);

  /// How tall [slot] is drawn, counted from the earliest a block could start
  /// in it, because the pause before that belongs to the block above.
  static double stretchHeight(FreeSlot slot) =>
      _height(slot.end.difference(slot.earliest).inMinutes);

  /// Whether [slot] has enough room in it to be drawn at all.
  static bool shows(FreeSlot slot) => slot.capacityMinutes > shortestStretch;

  /// How far down [slot] each full hour inside it falls.
  static List<double> hourLines(FreeSlot slot) {
    final from = slot.earliest;
    var hour = DateTime(from.year, from.month, from.day, from.hour + 1);
    final lines = <double>[];

    while (hour.isBefore(slot.end)) {
      lines.add(hour.difference(from).inMinutes * perMinute);
      hour = DateTime(hour.year, hour.month, hour.day, hour.hour + 1);
    }

    return lines;
  }

  /// The step a fixed block moves by inside empty room.
  static const step = 15;

  /// The moment [dy] points at, measured down from the top of [slot] drawn
  /// [height] tall.
  ///
  /// Proportional to the height it was actually drawn at, because a stretch
  /// shorter than half an hour is drawn taller than its time.
  static DateTime timeAt(FreeSlot slot, double dy, double height) {
    final total = slot.end.difference(slot.earliest).inMinutes;
    final share = height <= 0 ? 0.0 : (dy / height).clamp(0.0, 1.0);

    return slot.earliest.add(Duration(minutes: (share * total).round()));
  }

  /// How far down [slot], drawn [height] tall, the moment [at] falls.
  static double offsetOf(FreeSlot slot, DateTime at, double height) {
    final total = slot.end.difference(slot.earliest).inMinutes;
    if (total <= 0) return 0;

    final minutes = at.difference(slot.earliest).inMinutes;
    return (minutes / total).clamp(0.0, 1.0) * height;
  }

  /// Where a block of [minutes] let go near [aimed] would start in [slot].
  ///
  /// The start of the room, or any quarter of an hour after it that still
  /// leaves the whole block inside, whichever is nearest. A block too long
  /// for the room goes to its start, which is where cutting it to fit
  /// begins.
  static DateTime landingIn(FreeSlot slot, DateTime aimed, int minutes) {
    final latest = slot.end.subtract(Duration(minutes: minutes));
    var best = slot.earliest;

    for (
      var quarter = _nextQuarter(slot.earliest);
      !quarter.isAfter(latest);
      quarter = quarter.add(const Duration(minutes: step))
    ) {
      final gap = quarter.difference(aimed).abs();
      if (gap < best.difference(aimed).abs()) best = quarter;
    }

    return best;
  }

  /// The first quarter of an hour strictly after [at].
  static DateTime _nextQuarter(DateTime at) {
    final floored = DateTime(
      at.year,
      at.month,
      at.day,
      at.hour,
      at.minute - at.minute % step,
    );

    return floored.add(const Duration(minutes: step));
  }

  static double _height(int minutes) =>
      math.max(minutes, floorMinutes) * perMinute - AppSpacing.s1;
}
