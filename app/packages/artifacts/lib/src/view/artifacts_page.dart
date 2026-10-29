import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/all_artifacts_page.dart';
import 'package:artifacts/src/view/artifact_page.dart';
import 'package:artifacts/src/view/artifact_row.dart';
import 'package:artifacts/src/view/artifact_sheet.dart';
import 'package:artifacts/src/view/failure_listener.dart';
import 'package:artifacts/src/view/pace_bars.dart';
import 'package:artifacts/src/view/shelf_filter.dart';
import 'package:artifacts/src/view/start_sheet.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// {@template artifacts_page}
/// The Entregas tab: the deliveries under way, then the ones not begun.
///
/// The goals have a tab of their own (Objetivos); here are the deliveries.
/// Those under way (Em andamento) are fixed, the
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
    this.titled = true,
    super.key,
  });

  /// Whether it draws its own heading and search. Plano heads it with its
  /// tabs instead, and keeps the search at their end.
  final bool titled;

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
    final groups = progressGroups(queue, now);
    // The first few, what is under way first, as the page draws them.
    final started = groups.started.take(widget.shown).toList();
    final waiting = groups.waiting.take(widget.shown - started.length).toList();
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
                padding: side.copyWith(
                  top: widget.titled ? AppSpacing.s5 : AppSpacing.s2,
                ),
                sliver: SliverList.list(
                  children: [
                    if (widget.titled) ...[
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
                            onPressed: () =>
                                unawaited(openAllArtifacts(context)),
                            icon: const AppIcon(
                              iconData: AppIcons.search,
                              color: AppColors.ink2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                    ],
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
              // What is under way, the urgent ones and then the one most
              // behind its time on top, where its place is how late it is.
              // Then what has not been begun, the queue a drag puts in
              // order. One list, so a row is dragged across the line
              // between them: up, it is begun; down, it is not.
              if (all.isNotEmpty) ...[
                _sectionHeading(l10n.artifactsInProgress),
                SliverPadding(
                  padding: side,
                  sliver: SliverReorderableList(
                    itemCount: started.length + 1 + waiting.length,
                    onReorderItem: (from, to) => unawaited(
                      _drop(context, all, started, waiting, from, to),
                    ),
                    itemBuilder: (context, index) {
                      if (index == started.length) {
                        return KeyedSubtree(
                          key: const ValueKey(_line),
                          child: _Line(
                            title: l10n.artifactsNotStarted,
                            // Written down here, a delivery is begun at
                            // once, and so asks for its day.
                            onAdd: () => unawaited(
                              showArtifactSheet(context, started: true),
                            ),
                          ),
                        );
                      }
                      final artifact = index < started.length
                          ? started[index]
                          : waiting[index - started.length - 1];
                      final row = Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                        child: _row(context, artifact, now),
                      );
                      // Only the whole queue is dragged: a place among a
                      // shelf's says nothing about the rest.
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
                    child: AppAddRow(
                      onTap: () =>
                          unawaited(showArtifactSheet(context, top: false)),
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

/// The key of the line between the two groups in the list they share.
const _line = '_line';

/// A row let go at [to] (counted once it left [from]) in the list of
/// [started], the line, and [waiting].
///
/// Above the line, a delivery not begun is begun, asking for its day first
/// when it has none (closed, nothing happens); its place there is the
/// rule's, not where it was let go. Below it, a delivery under way is no
/// longer begun, and either takes the place in the queue it was let go
/// at, counted in the whole of [all] as a move counts.
Future<void> _drop(
  BuildContext context,
  List<Artifact> all,
  List<Artifact> started,
  List<Artifact> waiting,
  int from,
  int to,
) async {
  final cubit = context.read<ArtifactsCubit>();
  if (from == started.length) return;
  final wasStarted = from < started.length;
  final artifact = wasStarted
      ? started[from]
      : waiting[from - started.length - 1];
  // Where the line is once the row has left the list.
  final line = wasStarted ? started.length - 1 : started.length;
  if (to <= line) {
    if (wasStarted) return;
    var deadline = artifact.deadline;
    if (deadline == null) {
      deadline = await showStartSheet(context, artifact);
      if (deadline == null) return;
      return cubit.start(artifact.id, deadline: deadline);
    }
    return cubit.start(artifact.id);
  }
  final index = queueIndexOf(all, waiting, artifact.id, to - line - 1);
  if (wasStarted) return cubit.stop(artifact.id, index);
  return cubit.move(artifact.id, index);
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

/// The line between the two groups: Em andamento's + and the heading of
/// Não iniciadas. A row is dropped either side of it, never moved itself.
class _Line extends StatelessWidget {
  const _Line({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppAddRow(onTap: onAdd),
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.s4,
            bottom: AppSpacing.s2,
          ),
          child: Text(title, style: AppTypography.title),
        ),
      ],
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
