import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/failure_listener.dart';
import 'package:artifacts/src/view/goal_card.dart';
import 'package:artifacts/src/view/goal_sheet.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// {@template goals_page}
/// The Objetivos tab: how much she means to bill, and by when.
///
/// On top the goal being measured, drawn whole ([GoalCard]); then the ones
/// written down to follow it (Próximos), quiet; then the ones whose day has
/// gone by (Anteriores), newest first, each with what it reached. With no
/// goal at all, a line says what one is and the + writes the first.
/// {@endtemplate}
class GoalsPage extends StatelessWidget {
  /// {@macro goals_page}
  const GoalsPage({super.key});

  Future<void> _delete(BuildContext context, Goal goal) async {
    final cubit = context.read<ArtifactsCubit>();
    final l10n = context.l10n;
    if (!await confirmDelete(
      context,
      goalLabel(l10n, goal),
      body: l10n.goalDeleteObjectiveBody,
    )) {
      return;
    }
    await cubit.deleteGoal(goal.id);
  }

  @override
  Widget build(BuildContext context) {
    return ArtifactsFailureListener(
      child: BlocBuilder<ArtifactsCubit, ArtifactsState>(
        builder: (context, state) {
          final data = state.data;
          if (data == null) return const SizedBox.shrink();
          return _build(context, data);
        },
      ),
    );
  }

  Widget _build(BuildContext context, ArtifactsData data) {
    final l10n = context.l10n;
    final now = clock.now();
    final goals = data.goals.where((g) => g.kind == GoalKind.money).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final current = goals
        .where((g) => g.isActiveAt(now) && !g.isOverAt(now))
        .toList();
    final upcoming = goals.where((g) => !g.isActiveAt(now)).toList();
    final past = goals.where((g) => g.isOverAt(now)).toList().reversed;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s5,
              AppSpacing.s5,
              AppSpacing.s5,
              kNotesDockClearance,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s1),
                child: Text(l10n.shellGoalsTab, style: AppTypography.headline),
              ),
              const SizedBox(height: AppSpacing.s4),
              if (goals.isEmpty) const _Empty(),
              for (final goal in current) ...[
                GoalCard(
                  goal: goal,
                  now: now,
                  queue: goalQueue(goal, data.queue),
                  onLongPress: () => unawaited(_delete(context, goal)),
                ),
                const SizedBox(height: AppSpacing.s3),
              ],
              if (upcoming.isNotEmpty) ...[
                _Heading(l10n.goalsUpcoming),
                for (final goal in upcoming) ...[
                  GoalCard(
                    goal: goal,
                    now: now,
                    onLongPress: () => unawaited(_delete(context, goal)),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                ],
              ],
              if (past.isNotEmpty) ...[
                _Heading(l10n.goalsPast),
                for (final goal in past) ...[
                  GoalRow(
                    goal: goal,
                    onLongPress: () => unawaited(_delete(context, goal)),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A section's title, as the timeline heads its days.
class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s1,
        AppSpacing.s4,
        AppSpacing.s1,
        AppSpacing.s2,
      ),
      child: Text(title, style: AppTypography.title),
    );
  }
}

/// What Objetivos says before it holds a goal: what one is, and the way to
/// the first.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(iconData: AppIcons.goal),
          const SizedBox(height: AppSpacing.s3),
          Text(l10n.goalsEmptyTitle, style: AppTypography.title),
          const SizedBox(height: AppSpacing.s2),
          Text(
            l10n.goalsEmptyBody,
            style: AppTypography.label.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppPillButton(
            iconData: AppIcons.plus,
            label: l10n.goalsNew,
            onPressed: () => unawaited(showGoalSheet(context)),
          ),
        ],
      ),
    );
  }
}
