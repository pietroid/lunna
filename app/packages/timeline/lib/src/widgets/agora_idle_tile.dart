import 'package:app_ui/app_ui.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/day_over_tile.dart';
import 'package:timeline/src/widgets/free_tile.dart';

/// {@template agora_idle_tile}
/// Agora with nothing in it, the same wherever Agora is drawn (the
/// calendar's and Plano's).
///
/// Inside the working day it is the break ([FreeTile], one of its twenty
/// lines, picked from the minute it starts), from now to the next card's
/// start; outside it, [DayOverTile]: nothing begins, and it offers the
/// working day's hours.
/// {@endtemplate}
class AgoraIdleTile extends StatelessWidget {
  /// {@macro agora_idle_tile}
  const AgoraIdleTile({
    required this.workDay,
    required this.now,
    this.nextStart,
    this.slot,
    this.targeted = false,
    this.onWriteDown,
    this.onAdjustDay,
    super.key,
  });

  /// The person's working day.
  final WorkDay workDay;

  /// The moment it is drawn at.
  final DateTime now;

  /// When the next card starts, which is where the break ends; an hour on
  /// when nothing comes.
  final DateTime? nextStart;

  /// The break's room when the layout has worked it out (the calendar's
  /// free stretch under Agora); without it, from now to [nextStart].
  final FreeSlot? slot;

  /// Whether a card in the air is aimed at it.
  final bool targeted;

  /// Writes something down from now, on a tap of the break.
  final ValueChanged<Placement>? onWriteDown;

  /// Opens the working day's hours, offered outside it.
  final VoidCallback? onAdjustDay;

  /// Whether [now] is outside [workDay], when nothing begins.
  static bool closedAt(WorkDay workDay, DateTime now) {
    final minute = now.hour * 60 + now.minute;
    return minute < workDay.start || minute >= workDay.end;
  }

  @override
  Widget build(BuildContext context) {
    if (closedAt(workDay, now)) {
      return DayOverTile(
        workDay: workDay,
        over: now.hour * 60 + now.minute >= workDay.end,
        onAdjust: onAdjustDay,
      );
    }
    final minute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final onWriteDown = this.onWriteDown;
    final slot =
        this.slot ??
        FreeSlot(
          start: minute,
          end: nextStart ?? minute.add(const Duration(hours: 1)),
          earliest: minute,
          index: 0,
        );
    return FreeTile(
      slot: slot,
      now: true,
      targeted: targeted,
      // The break is not cut into hours, so a tap on it is always now.
      onTap: onWriteDown == null
          ? null
          : () => onWriteDown(Placement.at(slot.earliest)),
    );
  }
}
