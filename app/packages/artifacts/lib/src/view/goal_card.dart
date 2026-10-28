import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/pace_bars.dart';
import 'package:l10n/l10n.dart';

/// How far a goal may fall behind what its days ask before it reads as
/// behind: the same slack a delivery's bar has ([paceSlack]).
const double goalSlack = paceSlack;

/// {@template goal_card}
/// The goal being measured, as Objetivos draws it on top: what it asks and
/// by when, how much is in, and one bar holding two, as a delivery's does.
///
/// Green ([AppColors.paceDone]) is the money delivered since it began, out
/// of the target; under it red ([AppColors.paceTime]) is what its days ask
/// to be in by now, were the target reached evenly. Green covering the red
/// is on pace; red showing past it is behind, by as much as shows, and a
/// tag says by how much. Under the bar a line says where the open
/// deliveries due by its day would take it: no delivery names a goal, the
/// server finds them by their day and their value ([Goal.queued]). A goal
/// that has not begun is drawn quiet, with the day it begins and no bar.
/// {@endtemplate}
class GoalCard extends StatelessWidget {
  /// {@macro goal_card}
  const GoalCard({
    required this.goal,
    required this.now,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  /// The goal.
  final Goal goal;

  /// The moment it is drawn at.
  final DateTime now;

  /// Opens it.
  final VoidCallback? onTap;

  /// Asks to remove it.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = goal.isActiveAt(now);
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = goal.lastDay.difference(today).inDays;
    final expected = goal.expectedAt(now);
    final target = math.max(1, goal.target);
    final gap = expected - goal.done;
    final behind = gap > target * goalSlack;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIcon(
                  iconData: AppIcons.goal,
                  size: 16,
                  color: AppColors.ink2,
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  flex: 2,
                  child: Text(
                    [
                      l10n.goalRevenueBy(shortDay(l10n, goal.lastDay)),
                      if (!active)
                        l10n.goalStartsOn(dayName(l10n, goal.start, now)),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(color: AppColors.ink2),
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: AppSpacing.s2),
                  // The tag gives way, ellipsised, before the day does.
                  Flexible(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: behind
                          ? AppTag(
                              text: l10n.goalBehind(formatMoney(gap)),
                              iconData: AppIcons.warning,
                              fill: AppColors.danger,
                              ink: AppColors.dangerInk,
                            )
                          : AppTag(
                              text: gap < 0
                                  ? l10n.goalAhead(formatMoney(-gap))
                                  : l10n.goalOnPace,
                              iconData: AppIcons.check,
                            ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatMoney(goal.done),
                          style: AppTypography.headline.copyWith(
                            color: active ? AppColors.ink : AppColors.ink3,
                          ),
                        ),
                        TextSpan(
                          text: ' ${l10n.goalOf(formatMoney(goal.target))}',
                          style: AppTypography.label,
                        ),
                      ],
                    ),
                  ),
                ),
                if (active)
                  Text(
                    l10n.goalDaysLeft(math.max(0, daysLeft)),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink3,
                    ),
                  ),
              ],
            ),
            if (active) ...[
              const SizedBox(height: AppSpacing.s3),
              PaceBar(time: goal.timeAt(now), done: goal.done / target),
              const SizedBox(height: AppSpacing.s2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: PaceKey(
                      color: AppColors.paceDone,
                      text: l10n.goalAchieved(formatMoney(goal.done)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Flexible(
                    child: PaceKey(
                      color: AppColors.paceTime,
                      text: l10n.goalExpected(formatMoney(expected)),
                      ink: behind ? AppColors.dangerInk : null,
                    ),
                  ),
                ],
              ),
            ],
            if (active && goal.queuedCount > 0) ...[
              const SizedBox(height: AppSpacing.s3),
              Container(height: 1, color: AppColors.line),
              const SizedBox(height: AppSpacing.s3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIcon(
                    iconData: AppIcons.artifacts,
                    size: 16,
                    color: AppColors.ink3,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      goal.done + goal.queued >= goal.target
                          ? l10n.goalQueuedReaches(
                              goal.queuedCount,
                              shortDay(l10n, goal.lastDay),
                            )
                          : l10n.goalQueuedLine(
                              goal.queuedCount,
                              // Kept on one line with its R\$.
                              formatMoney(
                                goal.done + goal.queued,
                              ).replaceFirst(' ', '\u00a0'),
                              shortDay(l10n, goal.lastDay),
                            ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// {@template goal_row}
/// A goal whose day has gone by, as Anteriores lists it: what it asked, and
/// whether it was reached, with the green alone, since no time is left to
/// set it against.
/// {@endtemplate}
class GoalRow extends StatelessWidget {
  /// {@macro goal_row}
  const GoalRow({required this.goal, this.onLongPress, super.key});

  /// The goal.
  final Goal goal;

  /// Asks to remove it.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reached = goal.done >= goal.target;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goalLabel(l10n, goal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                if (reached)
                  AppTag(text: l10n.goalReached, iconData: AppIcons.check)
                else
                  Text(
                    formatMoney(goal.done),
                    style: AppTypography.label.copyWith(color: AppColors.ink3),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            PaceBar(done: goal.done / math.max(1, goal.target)),
          ],
        ),
      ),
    );
  }
}
