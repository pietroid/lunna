import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:l10n/l10n.dart';

/// {@template goal_card}
/// One goal, as the top of Entregas shows it: what it measures, how far it
/// has come, and how much of the rest the queue already holds.
///
/// The bar has two parts: what was delivered, in the accent, and what is
/// waiting in the queue and would count, in its wash. What is left after
/// both is what nothing planned covers yet. A goal that has not started is
/// drawn quiet, with the day it starts.
/// {@endtemplate}
class GoalCard extends StatelessWidget {
  /// {@macro goal_card}
  const GoalCard({required this.goal, required this.now, super.key});

  /// The goal.
  final Goal goal;

  /// The moment it is drawn at.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = goal.isActiveAt(now);
    final daysLeft = goal.end
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final missing = math.max(0, goal.target - goal.done - goal.queued);

    return Container(
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
              Expanded(
                child: Text(
                  goalLabel(l10n, goal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                active
                    ? l10n.goalDaysLeft(daysLeft)
                    : l10n.goalStartsOn(dayName(l10n, goal.start, now)),
                style: AppTypography.caption.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: goalAmount(goal, goal.done),
                  style: AppTypography.title.copyWith(
                    color: active ? AppColors.ink : AppColors.ink3,
                  ),
                ),
                TextSpan(
                  text: ' ${l10n.goalOf(goalAmount(goal, goal.target))}',
                  style: AppTypography.label,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          _GoalBar(goal: goal),
          const SizedBox(height: AppSpacing.s2),
          if (active)
            Row(
              children: [
                const _Dot(color: AppColors.accent),
                const SizedBox(width: AppSpacing.s1),
                Text(l10n.goalDone, style: AppTypography.caption),
                const SizedBox(width: AppSpacing.s3),
                const _Dot(color: AppColors.accentSoft),
                const SizedBox(width: AppSpacing.s1),
                Flexible(
                  child: Text(
                    l10n.goalQueued(goalAmount(goal, goal.queued)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Flexible(
                  child: Text(
                    missing == 0
                        ? l10n.goalCovered
                        : l10n.goalMissing(goalAmount(goal, missing)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink3,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The goal's bar: delivered, then queued, on the hairline track.
class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final target = math.max(1, goal.target);
    final done = (goal.done / target).clamp(0.0, 1.0);
    final queued = (goal.queued / target).clamp(0.0, 1.0 - done);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: AppColors.line),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: width * (done + queued),
                  child: const ColoredBox(color: AppColors.accentSoft),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: width * done,
                  child: const ColoredBox(color: AppColors.accent),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
