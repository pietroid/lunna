import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:timeline/src/models/models.dart';

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

  /// The step anything dropped in empty room moves by: the minutes the day
  /// is spaced in.
  static const step = 5;

  /// How close to either end of a room a drop has to be to stick to it.
  static const magnet = 10;

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
  /// Wherever it was let go, on the five minutes nearest, as long as the
  /// whole block still fits. Near either end it sticks to it: to the start
  /// of the room, five minutes after the block above, or to the latest start
  /// that ends five minutes before the block below. A block too long for the
  /// room goes to its start, which is where cutting it to fit begins.
  static DateTime landingIn(FreeSlot slot, DateTime aimed, int minutes) {
    final earliest = slot.earliest;
    final latest = slot.latestStart(minutes);
    if (!latest.isAfter(earliest)) return earliest;

    final snapped = _nearestStep(aimed);
    if (snapped.difference(earliest).inMinutes <= magnet) return earliest;
    if (latest.difference(snapped).inMinutes <= magnet) return latest;

    return snapped;
  }

  /// The wall-clock minute divisible by [step] nearest to [at].
  static DateTime _nearestStep(DateTime at) {
    final minutes = at.minute + at.second / 60;
    final rounded = (minutes / step).round() * step;

    return DateTime(at.year, at.month, at.day, at.hour, rounded);
  }

  static double _height(int minutes) =>
      math.max(minutes, floorMinutes) * perMinute - AppSpacing.s1;
}
