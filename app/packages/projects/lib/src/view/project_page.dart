import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:projects/src/bloc/projects_cubit.dart';
import 'package:projects/src/models/models.dart';
import 'package:projects/src/view/failure_listener.dart';
import 'package:projects/src/view/place_sheet.dart';
import 'package:projects/src/view/project_format.dart';
import 'package:projects/src/view/project_sheet.dart';

/// Opens the project with [id] on its own page, over the tab.
///
/// The page is its own route, so it is handed the cubit it reads.
Future<void> openProject(BuildContext context, String id, {int tab = 0}) {
  final cubit = context.read<ProjectsCubit>();

  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ProjectPage(id: id, initialTab: tab),
      ),
    ),
  );
}

/// {@template project_page}
/// One project, opened: the same shape as a task's page.
///
/// The name beside the back button, edited where it is written. Under it the
/// deadline, a tap away from a picker, and the project's own row of buttons:
/// a day less, a day more, done. The bar is its time, as on the running
/// block.
///
/// Under that, two spaces of their own: the tasks, and the notes. The tasks
/// are the project's, and each says where it is: only here, in the backlog,
/// or on the day. Tapping that is how it moves.
/// {@endtemplate}
class ProjectPage extends StatefulWidget {
  /// {@macro project_page}
  const ProjectPage({required this.id, this.initialTab = 0, super.key});

  /// The project's id.
  final String id;

  /// Which space opens first: 0 the tasks, 1 the notes.
  final int initialTab;

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  late int _tab = widget.initialTab;

  Future<void> _delete(BuildContext context, Project project) async {
    final cubit = context.read<ProjectsCubit>();
    final navigator = Navigator.of(context);
    if (!await confirmProjectDelete(context, project.title)) return;

    navigator.pop();
    await cubit.delete(project.id);
  }

  @override
  Widget build(BuildContext context) {
    final project = context.select<ProjectsCubit, Project?>(
      (cubit) => cubit.state.byId(widget.id),
    );

    return ProjectsFailureListener(
      child: Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            iconData: AppIcons.back,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: 0,
          title: project == null ? null : _Title(project: project),
          actions: [
            if (project != null)
              AppIconButton(
                iconData: AppIcons.trash,
                color: AppColors.ink2,
                onPressed: () => unawaited(_delete(context, project)),
              ),
            const SizedBox(width: AppSpacing.s2),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: project == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Summary(project: project),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s6,
                            AppSpacing.s2,
                            AppSpacing.s6,
                            AppSpacing.s2,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AppSegmented(
                              selected: _tab,
                              onSelected: (tab) => setState(() => _tab = tab),
                              segments: [
                                AppSegment(
                                  label: context.l10n.projectTasksTab(
                                    project.tasks.length - project.doneCount,
                                  ),
                                  iconData: AppIcons.check,
                                ),
                                AppSegment(
                                  label: context.l10n.projectNotesTab,
                                  iconData: AppIcons.pen,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: _tab == 0
                              ? _Tasks(project: project)
                              : _Notes(
                                  key: ValueKey(project.id),
                                  project: project,
                                ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The name, edited where it is written.
class _Title extends StatefulWidget {
  const _Title({required this.project});

  final Project project;

  @override
  State<_Title> createState() => _TitleState();
}

class _TitleState extends State<_Title> {
  late final _controller = TextEditingController(text: widget.project.title);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_Title oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.project.title != _controller.text) {
      _controller.text = widget.project.title;
    }
  }

  void _commit() {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      _controller.text = widget.project.title;
      return;
    }
    if (title == widget.project.title) return;

    unawaited(context.read<ProjectsCubit>().rename(widget.project.id, title));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      style: AppTypography.title,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration.collapsed(
        hintText: context.l10n.projectUntitled,
      ),
      onSubmitted: (_) => _focus.unfocus(),
    );
  }
}

/// The deadline, the buttons, and the bar.
class _Summary extends StatelessWidget {
  const _Summary({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = clock.now();
    final cubit = context.read<ProjectsCubit>();
    final remaining = remainingLabel(l10n, project, now);
    final overdue = isOverdue(project, now);
    final dated = project.deadline != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        0,
        AppSpacing.s6,
        AppSpacing.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => unawaited(_pickDeadline(context)),
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s1,
                  ),
                  child: Text(
                    dated
                        ? deadlineLabel(l10n, project, now)
                        : l10n.projectGiveDeadline,
                    style: AppTypography.labelStrong.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              if (project.tasks.isNotEmpty) ...[
                Text(
                  ' · ',
                  style: AppTypography.label.copyWith(color: AppColors.ink3),
                ),
                Text(
                  l10n.projectTaskCount(
                    project.doneCount,
                    project.tasks.length,
                  ),
                  style: AppTypography.labelStrong.copyWith(
                    color: AppColors.ink2,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Expanded(
                child: Text(
                  project.isDone
                      ? l10n.projectDoneOn(
                          AppWheelPicker.dayLabel(
                            l10n,
                            project.doneAt!,
                            now: now,
                          ).toLowerCase(),
                        )
                      : remaining ?? l10n.projectNoDeadline,
                  style: AppTypography.label.copyWith(
                    color: overdue ? AppColors.dangerInk : AppColors.ink2,
                  ),
                ),
              ),
              if (dated && !project.isDone) ...[
                _Action(
                  tooltip: l10n.projectLessDay,
                  onTap: (project.daysLeftAt(now) ?? 0) > 0
                      ? () => cubit.shiftDeadline(project.id, -1)
                      : null,
                  child: _Days(l10n.projectMinusDay),
                ),
                _Action(
                  tooltip: l10n.projectMoreDay,
                  onTap: () => cubit.shiftDeadline(project.id, 1),
                  child: _Days(l10n.projectPlusDay),
                ),
              ],
              _Action(
                tooltip: project.isDone ? l10n.projectReopen : l10n.projectDone,
                onTap: () => cubit.setDone(project.id, done: !project.isDone),
                child: AppIcon(
                  iconData: project.isDone ? AppIcons.undo : AppIcons.check,
                  size: AppSpacing.s4,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
          if (dated) ...[
            const SizedBox(height: AppSpacing.s2),
            ProjectBar(project: project, now: now),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDeadline(BuildContext context) async {
    final cubit = context.read<ProjectsCubit>();
    final now = clock.now();
    final picked = await AppWheelPicker.dayAndTime(
      context,
      initial: project.deadline ?? now.add(const Duration(days: 7)),
      earliest: now,
    );
    if (picked == null) return;

    await cubit.setDeadline(
      project.id,
      DateTime(picked.year, picked.month, picked.day),
    );
  }
}

/// "−1 dia", in the controls' quiet type.
class _Days extends StatelessWidget {
  const _Days(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelStrong.copyWith(color: AppColors.ink2),
    );
  }
}

/// One quiet button, the shape of the running card's.
class _Action extends StatelessWidget {
  const _Action({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: AppSpacing.s6,
      child: Tooltip(
        message: tooltip,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.s8 + AppSpacing.s1,
              minHeight: AppSpacing.s8,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// The project's tasks, filed the way Lista files the day: under a heading
/// for where each one is, in the same cards.
///
/// Only in the project first, since that is where new ones land and where
/// the work of deciding happens; then on the day, by their hours; then the
/// backlog; then the done ones, quieter. A heading with nothing under it is
/// not drawn, except the first, which holds the +.
///
/// A card held and dragged moves to whichever stage it is let go over, as
/// in Lista. Let go over a card in the project, it takes that card's place.
/// An hour is not a drop: tapping the card asks for one.
class _Tasks extends StatefulWidget {
  const _Tasks({required this.project});

  final Project project;

  @override
  State<_Tasks> createState() => _TasksState();
}

class _TasksState extends State<_Tasks> {
  /// The card in the air, so the stages know to open up as targets.
  ProjectTask? _dragging;

  Project get project => widget.project;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    List<ProjectTask> at(Set<TaskPlace> places) => [
      for (final t in project.tasks)
        if (places.contains(t.place)) t,
    ];
    final far = DateTime(9999);
    final onDay = at({TaskPlace.queue, TaskPlace.scheduled})
      ..sort((a, b) => (a.at ?? far).compareTo(b.at ?? far));
    final done = at({TaskPlace.done})
      ..sort((a, b) => (b.doneAt ?? far).compareTo(a.doneAt ?? far));
    final stages = [
      (TaskPlace.project, l10n.placeProject, at({TaskPlace.project})),
      (TaskPlace.queue, l10n.placeQueue, onDay),
      (TaskPlace.backlog, l10n.placeBacklog, at({TaskPlace.backlog})),
      (TaskPlace.done, l10n.projectTasksDone(done.length), done),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        0,
        AppSpacing.s5,
        AppSpacing.s8,
      ),
      children: [
        for (final (i, (place, heading, tasks)) in stages.indexed)
          // A stage is drawn when it has something, when it is the first, or
          // while a card is in the air and could land there.
          if (i == 0 || tasks.isNotEmpty || _dragging != null)
            _Stage(
              place: place,
              heading: tasks.isEmpty && place == TaskPlace.done
                  ? l10n.placeDone
                  : heading,
              first: i == 0,
              dragging: _dragging,
              onDrop: (task) => _drop(task, place),
              children: [
                for (final (index, task) in tasks.indexed) ...[
                  _DraggableCard(
                    task: task,
                    onTap: () => unawaited(placeTask(context, project, task)),
                    onDragStarted: () => setState(() => _dragging = task),
                    onDragEnded: () => setState(() => _dragging = null),
                    // Only the project keeps an order of its own: the day
                    // orders the rest by their hours and their queues.
                    onDropBefore: place == TaskPlace.project
                        ? (dropped) => _drop(dropped, place, index: index)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.s2),
                ],
                if (i == 0) _AddTask(onTap: () => unawaited(_add(context))),
              ],
            ),
      ],
    );
  }

  void _drop(ProjectTask task, TaskPlace place, {int? index}) {
    setState(() => _dragging = null);
    if (task.place == place && index == null) return;
    // On the day is one stage with two kinds of card: dropping an anchored
    // one there again changes nothing.
    if (place == TaskPlace.queue && task.place == TaskPlace.scheduled) return;

    unawaited(
      context.read<ProjectsCubit>().placeTask(
        project.id,
        task.id,
        place,
        index: index,
      ),
    );
  }

  /// The same sheet the day writes with, asked without the clock: what it is
  /// and how long. It lands in the project, where only the project sees it.
  Future<void> _add(BuildContext context) async {
    final cubit = context.read<ProjectsCubit>();
    final result = await AppPromptSheet.show(context);
    if (result == null) return;

    await cubit.addTask(project.id, result.text, result.duration.inMinutes);
  }
}

/// One stage: its heading and its cards, and a place a card can be let go.
///
/// While a card from another stage hovers over it, it washes in the accent,
/// so where the card will land is never a guess.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.place,
    required this.heading,
    required this.first,
    required this.dragging,
    required this.onDrop,
    required this.children,
  });

  final TaskPlace place;
  final String heading;
  final bool first;
  final ProjectTask? dragging;
  final ValueChanged<ProjectTask> onDrop;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DragTarget<ProjectTask>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) {
        final hovered =
            candidates.isNotEmpty && candidates.first?.place != place;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: EdgeInsets.only(top: first ? 0 : AppSpacing.s3),
          padding: const EdgeInsets.only(bottom: AppSpacing.s1),
          decoration: BoxDecoration(
            color: hovered ? AppColors.accentWash : null,
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Heading(text: heading, first: first),
              ...children,
              // An empty stage still needs somewhere to be let go over.
              if (children.isEmpty && dragging != null)
                const SizedBox(height: AppSpacing.s12),
            ],
          ),
        );
      },
    );
  }
}

/// A card that can be held and carried to another stage.
class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    required this.task,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragEnded,
    this.onDropBefore,
  });

  final ProjectTask task;
  final VoidCallback onTap;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  /// A card let go over this one, when this stage keeps an order.
  final ValueChanged<ProjectTask>? onDropBefore;

  @override
  Widget build(BuildContext context) {
    final card = _TaskCard(task: task, onTap: onTap);

    final draggable = LayoutBuilder(
      builder: (context, constraints) => LongPressDraggable<ProjectTask>(
        data: task,
        onDragStarted: onDragStarted,
        onDragEnd: (_) => onDragEnded(),
        onDraggableCanceled: (_, _) => onDragEnded(),
        feedback: SizedBox(
          width: constraints.maxWidth,
          child: _TaskCard(task: task, onTap: () {}, lifted: true),
        ),
        childWhenDragging: Opacity(opacity: 0, child: card),
        child: card,
      ),
    );

    final dropBefore = onDropBefore;
    if (dropBefore == null) return draggable;

    return DragTarget<ProjectTask>(
      onWillAcceptWithDetails: (details) => details.data.id != task.id,
      onAcceptWithDetails: (details) => dropBefore(details.data),
      builder: (context, candidates, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Where the card will land: a line above the one it is over.
          if (candidates.isNotEmpty)
            Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: AppSpacing.s1),
              color: AppColors.accent,
            ),
          draggable,
        ],
      ),
    );
  }
}

/// A stage's heading, in the type Lista heads its stages with.
class _Heading extends StatelessWidget {
  const _Heading({required this.text, required this.first});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s1,
        first ? AppSpacing.s3 : AppSpacing.s6,
        AppSpacing.s1,
        AppSpacing.s2,
      ),
      child: Text(text, style: AppTypography.title),
    );
  }
}

/// {@template task_card}
/// A project's task, drawn as Lista draws a task: a borderless fill with the
/// title, and on the right its hours once it is on the day, or its length
/// while it is not.
/// {@endtemplate}
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onTap,
    this.lifted = false,
  });

  final ProjectTask task;
  final VoidCallback onTap;

  /// Whether this is the copy that follows the finger.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final done = task.place == TaskPlace.done;
    final start = task.at;
    final length = formatDuration(l10n, Duration(minutes: task.minutes));
    final end = start?.add(Duration(minutes: task.minutes));

    return Material(
      color: lifted ? AppColors.fillStrong : AppColors.fill,
      elevation: lifted ? 8 : 0,
      shadowColor: AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          child: Row(
            children: [
              // The mark goes before the title, as a routine's or a fixed
              // block's does on the day.
              if (done) ...[
                const AppIcon(
                  iconData: AppIcons.check,
                  size: AppSpacing.s4,
                  color: AppColors.ink3,
                ),
                const SizedBox(width: AppSpacing.s2),
              ],
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: done ? AppColors.ink3 : AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                start == null || done
                    ? length
                    : '${_day(l10n, start)}${_hhmm(start)}–${_hhmm(end!)}',
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nothing for today, "amanhã ", "dom ": there are no day headings here to
  /// say it.
  static String _day(AppLocalizations l10n, DateTime at) {
    final now = clock.now();
    final days = DateTime.utc(
      at.year,
      at.month,
      at.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    if (days <= 0) return '';
    if (days == 1) return '${l10n.dayTomorrow.toLowerCase()} ';
    return '${l10n.weekdaysShort.split(',')[at.weekday - 1]} ';
  }

  static String _hhmm(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}

/// The + under the tasks.
class _AddTask extends StatelessWidget {
  const _AddTask({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s3,
          AppSpacing.s4,
          AppSpacing.s3,
        ),
        child: Row(
          children: [
            const SizedBox(
              width: AppSpacing.s5 + 2,
              child: AppIcon(
                iconData: AppIcons.plus,
                size: AppSpacing.s5,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Text(
              context.l10n.projectAddTask,
              style: AppTypography.bodyStrong.copyWith(color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// The project's notes: free text, saved as it is written.
///
/// A moment after the typing stops, when the field loses focus, and when the
/// page closes, as a task's notes are.
class _Notes extends StatefulWidget {
  const _Notes({required this.project, super.key});

  final Project project;

  @override
  State<_Notes> createState() => _NotesState();
}

class _NotesState extends State<_Notes> {
  static const _debounce = Duration(milliseconds: 800);

  late final _controller = TextEditingController(text: widget.project.notes);
  final _focus = FocusNode();
  late final ProjectsCubit _cubit = context.read<ProjectsCubit>();
  Timer? _timer;

  late String _saved = widget.project.notes;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void didUpdateWidget(_Notes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.project.notes != _controller.text) {
      _controller.text = widget.project.notes;
      _saved = widget.project.notes;
    }
  }

  void _onChanged(String _) {
    _timer?.cancel();
    _timer = Timer(_debounce, _save);
  }

  void _save() {
    _timer?.cancel();
    final notes = _controller.text;
    if (notes == _saved) return;

    _saved = notes;
    unawaited(_cubit.saveNotes(widget.project.id, notes));
  }

  @override
  void dispose() {
    _save();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s3,
        AppSpacing.s6,
        AppSpacing.s8,
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onChanged: _onChanged,
        maxLines: null,
        minLines: 8,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: AppTypography.body,
        decoration: InputDecoration.collapsed(
          hintText: context.l10n.projectNotesHint,
          hintStyle: AppTypography.body.copyWith(color: AppColors.ink3),
        ),
      ),
    );
  }
}
