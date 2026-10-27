import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/all_artifacts_page.dart';
import 'package:artifacts/src/view/artifact_page.dart';
import 'package:artifacts/src/view/artifact_row.dart';
import 'package:artifacts/src/view/artifact_sheet.dart';
import 'package:artifacts/src/view/failure_listener.dart';
import 'package:artifacts/src/view/goal_card.dart';
import 'package:artifacts/src/view/goal_sheet.dart';
import 'package:artifacts/src/view/pace_bars.dart';
import 'package:artifacts/src/view/shelf_filter.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// {@template artifacts_page}
/// The Entregas tab: the deliveries under way, then the ones not begun.
///
/// The three forces on one screen. The goals say what the month asks for;
/// the line under them says what the agenda can give, the time the queue
/// owes this month against the free time left in it; the deliveries are
/// what both are spent on. Those under way (Em andamento) are fixed, the
/// one whose time has run furthest past its work on top; those not begun
/// (Não iniciadas) are the queue, in order of priority, and held, a row is
/// dragged to another place in it. One line of the kinds she uses most
/// and the catalogue's shelves filters the queue, and the list ends in a
/// way to every delivery and a search.
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

  bool get _unfiltered => _shelf.category == null && _shelf.type == null;

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
    final cubit = context.read<ArtifactsCubit>();
    final groups = progressGroups(queue, now);
    // The first few, what is under way first, as the page draws them.
    final started = groups.started.take(widget.shown).toList();
    final waiting = groups.waiting.take(widget.shown - started.length).toList();
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
                    const SizedBox(height: AppSpacing.s4),
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
              // What is under way, the one most behind its time on top,
              // where nothing moves it: its place is how late it is. Then
              // what has not been begun, the queue a drag puts in order.
              if (all.isNotEmpty) ...[
                _sectionHeading(l10n.artifactsInProgress),
                SliverPadding(
                  padding: side,
                  sliver: SliverList.list(
                    children: [
                      for (final artifact in started)
                        Padding(
                          key: ValueKey(artifact.id),
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.s2,
                          ),
                          child: _row(context, artifact, now),
                        ),
                      // Written down here, a delivery is begun at once,
                      // and so asks for its day.
                      _AddRow(
                        onTap: () => unawaited(showArtifactSheet(context)),
                      ),
                    ],
                  ),
                ),
                _sectionHeading(l10n.artifactsNotStarted),
                SliverPadding(
                  padding: side,
                  // Held, a row moves to another place in the queue, among
                  // the others not begun. Only the whole queue is dragged: a
                  // place among a shelf's says nothing about the rest.
                  sliver: SliverReorderableList(
                    itemCount: waiting.length,
                    onReorderItem: (from, to) {
                      final id = waiting[from].id;
                      unawaited(
                        cubit.move(
                          id,
                          queueIndexOf(all, waiting, id, to),
                        ),
                      );
                    },
                    itemBuilder: (context, index) {
                      final artifact = waiting[index];
                      final row = Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                        child: _row(context, artifact, now),
                      );
                      return KeyedSubtree(
                        key: ValueKey(artifact.id),
                        child: _unfiltered
                            ? ReorderableDelayedDragStartListener(
                                index: index,
                                child: row,
                              )
                            : row,
                      );
                    },
                  ),
                ),
                SliverPadding(
                  padding: side,
                  sliver: SliverToBoxAdapter(
                    child: _AddRow(
                      onTap: () => unawaited(showArtifactSheet(context)),
                    ),
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

/// One delivery's row, opening its page.
Widget _row(BuildContext context, Artifact artifact, DateTime now) =>
    ArtifactRow(
      artifact: artifact,
      now: now,
      onTap: () => unawaited(openArtifact(context, artifact.id)),
    );

/// A heading of the deliveries, set as the timeline sets its days and
/// stages.
Widget _sectionHeading(String title) => SliverPadding(
  padding: const EdgeInsets.fromLTRB(
    AppSpacing.s5,
    AppSpacing.s4,
    AppSpacing.s5,
    AppSpacing.s2,
  ),
  sliver: SliverToBoxAdapter(child: Text(title, style: AppTypography.title)),
);

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

/// The last line of a section, as the timeline ends its stages: a + and
/// Adicionar, writing a delivery down in that section.
class _AddRow extends StatelessWidget {
  const _AddRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(
                iconData: AppIcons.plus,
                size: AppSpacing.s4,
                color: AppColors.ink3,
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                context.l10n.timelineAdd,
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
        ),
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
