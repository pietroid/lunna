import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/home_page.dart';
import 'package:timeline/timeline.dart';

/// {@template task_page}
/// A task's own page, whether or not it has tasks of its own: what a
/// delivery's page was.
///
/// Its name, its product and value, its bar; then Notas, Pendentes and
/// Feitas. Pendentes has two sections only, **Agora** (its task running,
/// if one is) and **Para depois** (the rest, in their order), each with its
/// play button. A task of a task has no tasks of its own: one level.
/// {@endtemplate}
class TaskPage extends StatelessWidget {
  /// {@macro task_page}
  const TaskPage({
    required this.title,
    required this.later,
    this.product,
    this.status,
    this.bar,
    this.now,
    this.done = 0,
    super.key,
  });

  /// The task's name.
  final String title;

  /// Its product and value, as a tag.
  final String? product;

  /// Where it stands, over its bar.
  final String? status;

  /// Its bar.
  final TaskBar? bar;

  /// Its task running.
  final TaskView? now;

  /// Its tasks not begun, in order.
  final List<TaskView> later;

  /// How many of its tasks are done.
  final int done;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = this.now;
    final pending = later.length + (now == null ? 0 : 1);
    final bar = this.bar;

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(iconData: AppIcons.back, onPressed: () {}),
        titleSpacing: 0,
        title: Text(title, style: AppTypography.title),
        actions: [
          AppIconButton(
            iconData: AppIcons.check,
            color: AppColors.ink2,
            onPressed: () {},
          ),
          AppIconButton(
            iconData: AppIcons.trash,
            color: AppColors.ink2,
            onPressed: () {},
          ),
          const SizedBox(width: AppSpacing.s2),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: kNotesDockClearance),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s6,
              AppSpacing.s1,
              AppSpacing.s6,
              AppSpacing.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product != null)
                  AppTag(text: product!, iconData: AppIcons.catalog),
                if (status != null) ...[
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    status!,
                    style: AppTypography.label.copyWith(color: AppColors.ink2),
                  ),
                ],
                if (bar != null) ...[
                  const SizedBox(height: AppSpacing.s2),
                  TaskCardBar(bar: bar),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s6,
              AppSpacing.s2,
              AppSpacing.s6,
              AppSpacing.s2,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AppSegmented(
                  selected: 1,
                  onSelected: (_) {},
                  segments: [
                    AppSegment(
                      label: l10n.artifactNotesTab,
                      iconData: AppIcons.pen,
                    ),
                    AppSegment(
                      label: l10n.artifactPendingTab(pending),
                      iconData: AppIcons.time,
                    ),
                    AppSegment(
                      label: l10n.artifactDoneTab(done),
                      iconData: AppIcons.check,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _Section(title: l10n.feedNow),
          if (now != null)
            _Card(task: now, now: true)
          else
            _Card(task: TaskView(title: l10n.feedBreak)),
          _Section(title: l10n.stageBacklog),
          for (final task in later) _Card(task: task),
        ],
      ),
      floatingActionButton: AppFab(onPressed: () {}),
    );
  }
}

/// {@template later_page}
/// Para depois, whole: every task not begun, in the queue's order, each
/// with its play button. Dragged, a task changes its place.
/// {@endtemplate}
class LaterPage extends StatelessWidget {
  /// {@macro later_page}
  const LaterPage({required this.tasks, super.key});

  /// The queue.
  final List<TaskView> tasks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(iconData: AppIcons.back, onPressed: () {}),
        titleSpacing: 0,
        title: Text(context.l10n.stageBacklog, style: AppTypography.title),
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          top: AppSpacing.s2,
          bottom: kNotesDockClearance,
        ),
        children: [for (final task in tasks) _Card(task: task)],
      ),
      floatingActionButton: AppFab(onPressed: () {}),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s5,
        AppSpacing.s6,
        AppSpacing.s3,
      ),
      child: Text(title, style: AppTypography.title),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.task, this.now = false});

  final TaskView task;
  final bool now;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        0,
        AppSpacing.s5,
        AppSpacing.s2,
      ),
      child: TaskCard(
        title: task.title,
        subtitle: task.subtitle,
        trailing: task.trailing,
        now: now,
        playing: task.playing,
        onPlay: () {},
        status: task.status,
        controls: now,
        bar: task.bar,
        onTap: () {},
      ),
    );
  }
}
