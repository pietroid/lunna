import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/free_tile.dart';

/// {@template day_over_tile}
/// Agora outside the working day.
///
/// Nothing starts now: the queue waits for the day to open, and a card let
/// go here is refused rather than begun. The tile says so, with the hour
/// the day ended or will start, so the first task of tomorrow is never
/// mistaken for something that should be running. It is as tall as the
/// break it stands in for, and offers the one way round it: changing when
/// the day ends.
/// {@endtemplate}
class DayOverTile extends StatelessWidget {
  /// {@macro day_over_tile}
  const DayOverTile({
    required this.workDay,
    required this.over,
    this.onAdjust,
    super.key,
  });

  /// The person's working day.
  final WorkDay workDay;

  /// Whether the day is over, rather than not begun yet.
  final bool over;

  /// Opens the working day's hours, when there is somewhere to open them.
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final start = WorkDay.formatMinutes(workDay.start);

    return Container(
      constraints: const BoxConstraints(minHeight: FreeTile.nowHeight),
      decoration: BoxDecoration(
        color: AppColors.freeFill,
        border: Border.all(color: AppColors.freeEdge),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: AppIcon(
              iconData: AppIcons.dayOver,
              size: AppSpacing.s5,
              color: AppColors.freeInk,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  over
                      ? l10n.dayOverTitle(WorkDay.formatMinutes(workDay.end))
                      : l10n.dayNotYetTitle(start),
                  style: AppTypography.body.copyWith(color: AppColors.freeInk),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  over ? l10n.dayOverBody(start) : l10n.dayNotYetBody,
                  style: AppTypography.label.copyWith(color: AppColors.ink2),
                ),
                if (onAdjust != null)
                  TextButton(
                    onPressed: onAdjust,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, AppSpacing.s8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.accent,
                    ),
                    child: Text(
                      l10n.dayClosedAdjust,
                      style: AppTypography.labelStrong.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
