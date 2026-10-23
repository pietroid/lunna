import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/all_artifacts_page.dart';
import 'package:artifacts/src/view/artifact_page.dart';
import 'package:artifacts/src/view/artifact_row.dart';
import 'package:artifacts/src/view/failure_listener.dart';
import 'package:artifacts/src/view/goal_card.dart';
import 'package:artifacts/src/view/goal_sheet.dart';
import 'package:artifacts/src/view/shelf_filter.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// {@template artifacts_page}
/// The Entregas tab: the deliveries, by the day each is due.
///
/// The three forces on one screen. The goals say what the month asks for;
/// the line under them says what the agenda can give, the time the queue
/// owes this month against the free time left in it; the queue, in order of
/// priority, is what both are spent on. Held, a row is dragged to another
/// place. One line of the kinds she uses most and the catalogue's shelves
/// filters the queue, and the list ends in a way to every delivery and a
/// search.
/// {@endtemplate}
class ArtifactsPage extends StatefulWidget {
  /// {@macro artifacts_page}
  const ArtifactsPage({
    this.shown = 5,
    this.initialShelf = const Shelf(),
    this.showGoals = false,
    super.key,
  });

  /// Whether the goals are drawn. Off for now: the deliveries and their
  /// days say enough, and the goals' cards pushed them below the fold.
  /// Everything behind them (routes, the agent's verbs) still works.
  final bool showGoals;

  /// How many of the queue are drawn before "Ver todas".
  final int shown;

  /// What the queue is kept to when it opens.
  final Shelf initialShelf;

  @override
  State<ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends State<ArtifactsPage> {
  /// What the queue is kept to.
  late Shelf _shelf = widget.initialShelf;

  Future<void> _deleteGoal(Goal goal) async {
    final cubit = context.read<ArtifactsCubit>();
    final l10n = context.l10n;
    if (!await confirmDelete(
      context,
      goalLabel(l10n, goal),
      body: l10n.goalDeleteBody,
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
    final all = data.queue;
    final queue = all.where(_shelf.keeps).toList();
    final shown = byDue(queue, now).take(widget.shown).toList();
    final left = all.fold(
      0,
      (sum, a) => sum + (a.minutes - a.doneMinutes).clamp(0, a.minutes),
    );
    final schedule = data.schedule;
    const side = EdgeInsets.symmetric(horizontal: AppSpacing.s5);

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: side.copyWith(top: AppSpacing.s5),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.s1,
                            ),
                            child: Text(
                              l10n.shellArtifactsTab,
                              style: AppTypography.headline,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.artifactsSearch,
                          onPressed: () => unawaited(openAllArtifacts(context)),
                          icon: const AppIcon(
                            iconData: AppIcons.search,
                            color: AppColors.ink2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    if (widget.showGoals) ...[
                      _Heading(
                        title: l10n.goalsSection,
                        trailing: AppPillButton(
                          iconData: AppIcons.plus,
                          label: l10n.goalNew,
                          onPressed: () => unawaited(showGoalSheet(context)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      if (data.goals.isEmpty)
                        _Quiet(text: l10n.goalsEmpty)
                      else
                        SizedBox(
                          height: 140,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            itemCount: data.goals.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: AppSpacing.s2),
                            itemBuilder: (context, index) {
                              final goal = data.goals[index];
                              return SizedBox(
                                width: 300,
                                child: GestureDetector(
                                  onLongPress: () =>
                                      unawaited(_deleteGoal(goal)),
                                  child: GoalCard(goal: goal, now: now),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                    const SizedBox(height: AppSpacing.s3),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s1,
                      ),
                      child: Row(
                        children: [
                          const AppIcon(
                            iconData: AppIcons.timer,
                            size: AppSpacing.s4,
                            color: AppColors.ink3,
                          ),
                          const SizedBox(width: AppSpacing.s2),
                          Expanded(
                            child: Text(
                              l10n.goalSchedule(
                                formatMinutes(l10n, schedule.needMinutes),
                                formatMinutes(l10n, schedule.freeMinutes),
                                dayName(l10n, schedule.until, now),
                              ),
                              style: AppTypography.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    _Heading(
                      title: l10n.artifactsQueue,
                      trailing: Text(
                        l10n.artifactsQueueSummary(
                          all.length,
                          formatMinutes(l10n, left),
                        ),
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink3,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    if (data.catalog.isNotEmpty) ...[
                      ShelfFilter(
                        categories: data.catalog,
                        top: data.topTypes,
                        value: _shelf,
                        onChanged: (shelf) => setState(() => _shelf = shelf),
                      ),
                      const SizedBox(height: AppSpacing.s3),
                    ],
                    if (queue.isEmpty)
                      _Quiet(
                        text: all.isEmpty
                            ? l10n.artifactsEmpty
                            : l10n.artifactsNoneHere,
                      ),
                  ],
                ),
              ),
              // The queue by the day each is due, the soonest on top: what
              // has to be delivered today leads, whatever was dragged first.
              for (final (due, rows) in dueGroups(shown, now)) ...[
                SliverPadding(
                  padding: side.copyWith(
                    top: AppSpacing.s4,
                    bottom: AppSpacing.s2,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.s1),
                      child: Text(
                        dueLabel(l10n, due),
                        style: AppTypography.labelStrong.copyWith(
                          color: due == Due.today
                              ? AppColors.ink
                              : AppColors.ink2,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: side,
                  sliver: SliverList.list(
                    children: [
                      for (final artifact in rows)
                        Padding(
                          key: ValueKey(artifact.id),
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.s2,
                          ),
                          child: ArtifactRow(
                            artifact: artifact,
                            now: now,
                            onTap: () =>
                                unawaited(openArtifact(context, artifact.id)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              SliverPadding(
                // Room for the bar and the + floating over the list.
                padding: side.copyWith(bottom: AppSpacing.s16 * 2),
                sliver: SliverToBoxAdapter(
                  child: queue.length > widget.shown
                      ? Center(
                          child: AppButton.text(
                            text: l10n.artifactsSeeAll(queue.length),
                            color: AppColors.ink2,
                            onPressed: () => unawaited(
                              openAllArtifacts(context, shelf: _shelf),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section's title, with what acts on it at the end of the line.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s1),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.title)),
          trailing,
        ],
      ),
    );
  }
}

/// What an empty section says, in the quiet ink.
class _Quiet extends StatelessWidget {
  const _Quiet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(
        text,
        style: AppTypography.label.copyWith(color: AppColors.ink2),
      ),
    );
  }
}

/// When a delivery is due, as Entregas heads it.
enum Due {
  /// Today, or already past.
  today,

  /// Tomorrow.
  tomorrow,

  /// Within the next seven days.
  week,

  /// Later than that.
  later,

  /// No deadline.
  none,
}

/// Which heading [artifact] goes under, seen from [now].
Due dueOf(Artifact artifact, DateTime now) {
  final days = artifact.daysLeftAt(now);
  return switch (days) {
    null => Due.none,
    <= 0 => Due.today,
    1 => Due.tomorrow,
    <= 7 => Due.week,
    _ => Due.later,
  };
}

/// [queue] by deadline, the soonest first and those with none last; the
/// queue's own order breaks ties.
List<Artifact> byDue(List<Artifact> queue, DateTime now) {
  final order = {for (final (i, a) in queue.indexed) a.id: i};
  int key(Artifact a) => a.daysLeftAt(now) ?? 1 << 30;
  return [...queue]..sort((a, b) {
    final byDay = key(a).compareTo(key(b));
    return byDay != 0 ? byDay : order[a.id]!.compareTo(order[b.id]!);
  });
}

/// [sorted] cut under its headings, in order, leaving out the empty ones.
List<(Due, List<Artifact>)> dueGroups(List<Artifact> sorted, DateTime now) => [
  for (final due in Due.values)
    if (sorted.where((a) => dueOf(a, now) == due).toList() case final rows
        when rows.isNotEmpty)
      (due, rows),
];

/// The heading's words.
String dueLabel(AppLocalizations l10n, Due due) => switch (due) {
  Due.today => l10n.artifactsDueToday,
  Due.tomorrow => l10n.artifactsDueTomorrow,
  Due.week => l10n.artifactsDueWeek,
  Due.later => l10n.artifactsDueLater,
  Due.none => l10n.artifactsDueNone,
};
