import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/artifact_row.dart';
import 'package:artifacts/src/view/goal_card.dart';
import 'package:l10n/l10n.dart';

/// {@template artifacts_page}
/// The Entregas tab: the goals on top, the queue of deliveries under them.
///
/// The three forces on one screen. The goals say what the month asks for;
/// the line under them says what the agenda can give, the time the queue
/// needs against the free time left in the stretch; the queue, in order of
/// priority, is what both are spent on. The shelves of the catalogue filter
/// the queue, and the list ends in a way to every delivery and a search.
/// {@endtemplate}
class ArtifactsPage extends StatefulWidget {
  /// {@macro artifacts_page}
  const ArtifactsPage({
    required this.goals,
    required this.queue,
    required this.categories,
    required this.now,
    required this.freeMinutes,
    required this.freeUntil,
    this.shown = 5,
    this.onSearch,
    this.onNewGoal,
    this.onSeeAll,
    super.key,
  });

  /// The goals, those being measured first, then those to come.
  final List<Goal> goals;

  /// Every delivery not yet made, in order of priority.
  final List<Artifact> queue;

  /// The catalogue's shelves, which filter the queue.
  final List<CatalogCategory> categories;

  /// The moment it is drawn at.
  final DateTime now;

  /// The free time on the agenda from now to [freeUntil], set against what
  /// the queue has due by then.
  final int freeMinutes;

  /// The end of the stretch the free time is counted to.
  final DateTime freeUntil;

  /// How many of the queue are drawn before "Ver todas".
  final int shown;

  /// Opens the search over every delivery.
  final VoidCallback? onSearch;

  /// Writes a goal down.
  final VoidCallback? onNewGoal;

  /// Opens every delivery.
  final VoidCallback? onSeeAll;

  @override
  State<ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends State<ArtifactsPage> {
  /// The shelf the queue is kept to; null, every shelf.
  String? _category;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = widget.now;
    final queue = [
      for (final a in widget.queue)
        if (_category == null || a.category?.id == _category) a,
    ];
    int left(Iterable<Artifact> list) =>
        list.fold(0, (sum, a) => sum + a.minutes - a.doneMinutes);
    // What the stretch must hold: what is due before it ends.
    final need = left(
      widget.queue.where(
        (a) => a.deadline != null && a.deadline!.isBefore(widget.freeUntil),
      ),
    );
    final shelves = [null, ...widget.categories];

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
              // Room for the bar and the + floating over the list.
              AppSpacing.s16 * 2,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.s1),
                      child: Text(
                        l10n.shellArtifactsTab,
                        style: AppTypography.headline,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.artifactsSearch,
                    onPressed: widget.onSearch,
                    icon: const AppIcon(
                      iconData: AppIcons.search,
                      color: AppColors.ink2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              _Heading(
                title: l10n.goalsSection,
                trailing: AppPillButton(
                  iconData: AppIcons.plus,
                  label: l10n.goalNew,
                  onPressed: widget.onNewGoal ?? () {},
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              SizedBox(
                height: 128,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: widget.goals.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.s2),
                  itemBuilder: (context, index) => SizedBox(
                    width: 300,
                    child: GoalCard(goal: widget.goals[index], now: now),
                  ),
                ),
              ),
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
                          formatMinutes(l10n, need),
                          formatMinutes(l10n, widget.freeMinutes),
                          dayName(l10n, widget.freeUntil, now),
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
                    widget.queue.length,
                    formatMinutes(l10n, left(widget.queue)),
                  ),
                  style: AppTypography.label.copyWith(color: AppColors.ink3),
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: AppSegmented(
                  selected: shelves.indexWhere((c) => c?.id == _category),
                  onSelected: (index) =>
                      setState(() => _category = shelves[index]?.id),
                  segments: [
                    for (final shelf in shelves)
                      AppSegment(label: shelf?.name ?? l10n.artifactsAll),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              for (final artifact in queue.take(widget.shown)) ...[
                ArtifactRow(artifact: artifact, now: now),
                const SizedBox(height: AppSpacing.s2),
              ],
              if (queue.length > widget.shown)
                Center(
                  child: AppButton.text(
                    text: l10n.artifactsSeeAll(queue.length),
                    color: AppColors.ink2,
                    onPressed: widget.onSeeAll ?? () {},
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
