import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/format.dart';

/// How each phase of the cycle is drawn: its icon, its ink, its fill and
/// its name. One place, so the Feed, the calendar and the cycle's page
/// never draw a phase two ways.
extension CyclePhaseLook on CyclePhase {
  /// The phase's icon: a drop, a sprout, the sun, the moon.
  AppIconData get icon => switch (this) {
    CyclePhase.menstrual => AppIcons.cycleMenstrual,
    CyclePhase.follicular => AppIcons.cycleFollicular,
    CyclePhase.ovulatory => AppIcons.cycleOvulatory,
    CyclePhase.luteal => AppIcons.cycleLuteal,
  };

  /// Marks and text in the phase's colour.
  Color get ink => switch (this) {
    CyclePhase.menstrual => AppColors.cycleMenstrual,
    CyclePhase.follicular => AppColors.cycleFollicular,
    CyclePhase.ovulatory => AppColors.cycleOvulatory,
    CyclePhase.luteal => AppColors.cycleLuteal,
  };

  /// The fill behind [ink].
  Color get fill => switch (this) {
    CyclePhase.menstrual => AppColors.cycleMenstrualFill,
    CyclePhase.follicular => AppColors.cycleFollicularFill,
    CyclePhase.ovulatory => AppColors.cycleOvulatoryFill,
    CyclePhase.luteal => AppColors.cycleLutealFill,
  };

  /// The phase's name, as the person reads it.
  String label(AppLocalizations l10n) => switch (this) {
    CyclePhase.menstrual => l10n.cyclePhaseMenstrual,
    CyclePhase.follicular => l10n.cyclePhaseFollicular,
    CyclePhase.ovulatory => l10n.cyclePhaseOvulatory,
    CyclePhase.luteal => l10n.cyclePhaseLuteal,
  };
}

/// {@template day_mark_tag}
/// What a day that is not a plain working day says beside its heading:
/// "Dia leve · 3h" or "Folga", with the icon of why (the drop of the
/// period, the couch of a day off).
///
/// Nothing on a working day: the heading of an ordinary day stays a line
/// of text.
/// {@endtemplate}
class DayMarkTag extends StatelessWidget {
  /// {@macro day_mark_tag}
  const DayMarkTag({required this.mark, super.key});

  /// The day's mark.
  final DayMark mark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = mark.reason == DayReason.period;

    return switch (mark.kind) {
      DayKind.work => const SizedBox.shrink(),
      DayKind.light => AppTag(
        text: l10n.dayLightTag(durationLabel(l10n, mark.budgetMinutes ?? 0)),
        iconData: period ? AppIcons.cycleMenstrual : AppIcons.dayLight,
        fill: period ? AppColors.cycleMenstrualFill : AppColors.fillStrong,
        ink: period ? AppColors.cycleMenstrual : AppColors.ink2,
      ),
      DayKind.off => AppTag(
        text: l10n.dayOffTag,
        iconData: period ? AppIcons.cycleMenstrual : AppIcons.dayOff,
        fill: period ? AppColors.cycleMenstrualFill : AppColors.fillStrong,
        ink: period ? AppColors.cycleMenstrual : AppColors.ink2,
      ),
    };
  }
}

/// {@template cycle_tag}
/// The day of the cycle and its phase, in the phase's colours: "Dia 2 do
/// ciclo · Menstruação".
/// {@endtemplate}
class CycleTag extends StatelessWidget {
  /// {@macro cycle_tag}
  const CycleTag({required this.day, required this.phase, super.key});

  /// Which day of the cycle, from 1.
  final int day;

  /// The phase it falls in.
  final CyclePhase phase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppTag(
      text: l10n.cycleDayPhase(day, phase.label(l10n)),
      iconData: phase.icon,
      fill: phase.fill,
      ink: phase.ink,
    );
  }
}

/// {@template rest_day_tile}
/// A whole day off with nothing on it, drawn on the calendar as one quiet
/// row instead of fifteen hours of room: the queue never sends anything
/// there, so there is nothing to scale.
///
/// A tap still writes something down on it, at the hour the day would
/// open: the queue keeps off it, the person does not have to. A day of
/// the weekend also offers **Trabalhar** ([onWork]), which puts that one
/// day back to work and the queue back on it.
/// {@endtemplate}
class RestDayTile extends StatelessWidget {
  /// {@macro rest_day_tile}
  const RestDayTile({required this.mark, this.onTap, this.onWork, super.key});

  /// The day off.
  final DayMark mark;

  /// Writes something down on the day anyway.
  final VoidCallback? onTap;

  /// Puts this day of the weekend back to work; offered only on one.
  final VoidCallback? onWork;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = mark.reason == DayReason.period;
    final text = switch (mark.reason) {
      DayReason.period => l10n.dayOffPeriod,
      DayReason.dayOff => l10n.dayOffDate,
      _ => l10n.dayOffWeekend,
    };

    return Material(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s3,
            AppSpacing.s3,
            AppSpacing.s3,
          ),
          child: Row(
            children: [
              AppIcon(
                iconData: period ? AppIcons.cycleMenstrual : AppIcons.dayOff,
                size: AppSpacing.s5,
                color: period ? AppColors.cycleMenstrual : AppColors.ink3,
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.label.copyWith(color: AppColors.ink2),
                ),
              ),
              if (onWork != null && mark.reason == DayReason.weekend)
                AppButton.text(text: l10n.dayOffWorkHere, onPressed: onWork),
              if (onTap != null)
                const AppIcon(
                  iconData: AppIcons.plus,
                  size: AppSpacing.s4,
                  color: AppColors.ink3,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
