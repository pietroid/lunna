import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:projects/src/bloc/projects_cubit.dart';
import 'package:projects/src/models/models.dart';
import 'package:projects/src/view/failure_listener.dart';
import 'package:projects/src/view/project_format.dart';
import 'package:projects/src/view/project_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeline/timeline.dart';

/// Opens the project with [id] on its own page, over the tab.
///
/// The page is its own route, so it is handed the cubit it reads.
Future<void> openProject(BuildContext context, String id, {int? tab}) {
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
/// Under that, two spaces of their own: the notes, and the tasks, opening
/// on whichever was last chosen for this project, on this device. The tasks
/// are Tempo's Lista kept to this project, with Tempo's bar and + at the
/// foot.
/// {@endtemplate}
class ProjectPage extends StatefulWidget {
  /// {@macro project_page}
  const ProjectPage({
    required this.id,
    this.initialTab,
    this.dictation,
    super.key,
  });

  /// The project's id.
  final String id;

  /// Which space opens first: 0 the notes, 1 the tasks. Null opens the one
  /// this device last chose.
  final int? initialTab;

  /// The recording the notes are dictated with, when handed in (tests and
  /// previews); otherwise the notes have their own.
  final DictationCubit? dictation;

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  static const _notesTab = 0;
  static const _tasksTab = 1;

  /// Where this project's last choice of space is kept, on this device:
  /// each project opens the way it was left.
  String get _tabKey => 'project.tab.${widget.id}';

  late int _tab = widget.initialTab ?? _notesTab;

  /// Where the + at the foot of the page writes: the stage at the top of
  /// the list, as on Tempo.
  final _aim = TimelineAim();

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == null) unawaited(_restoreTab());
  }

  Future<void> _restoreTab() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getInt(_tabKey);
      if (saved != null && mounted) setState(() => _tab = saved);
    } on Object {
      // Nothing remembered opens on the notes.
    }
  }

  void _choose(int tab) {
    setState(() => _tab = tab);
    unawaited(
      SharedPreferences.getInstance()
          .then((prefs) => prefs.setInt(_tabKey, tab))
          .catchError((Object _) => true),
    );
  }

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

    // Every change to a task here is the day's, through the timeline, so the
    // project reads itself again whenever the day's tasks change.
    return BlocListener<TimelineBloc, TimelineState>(
      listenWhen: (before, after) =>
          before.tasks != after.tasks || before.backlog != after.backlog,
      listener: (context, _) => unawaited(context.read<ProjectsCubit>().load()),
      child: ProjectsFailureListener(
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
                                onSelected: _choose,
                                segments: [
                                  AppSegment(
                                    label: context.l10n.projectNotesTab,
                                    iconData: AppIcons.pen,
                                  ),
                                  AppSegment(
                                    label: context.l10n.projectTasksTab(
                                      project.tasks.length - project.doneCount,
                                    ),
                                    iconData: AppIcons.check,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: _tab == _tasksTab
                                ? _Tasks(project: project, aim: _aim)
                                : _Notes(
                                    key: ValueKey(project.id),
                                    project: project,
                                    voice: widget.dictation,
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          // The tasks are written and talked about the way the day is: the
          // same bar and the same +. The notes draw their own dock, whose
          // microphone writes into them.
          floatingActionButton: project == null || _tab != _tasksTab
              ? null
              : AskDock(
                  about: AgentSubject.project(widget.id),
                  fab: AppFab(
                    tooltip: context.l10n.projectAddTask,
                    onPressed: () => unawaited(
                      writeDownOnTimeline(
                        context,
                        placement: _aim.value ?? const Placement.backlog(),
                        projectId: widget.id,
                      ),
                    ),
                  ),
                ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
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

/// The project's tasks, drawn by the very list Tempo draws in Lista, kept
/// to this project's: Fazer em breve with their hours, Depois eu priorizo,
/// and what was done.
///
/// So everything a card does there it does here: held, it moves up, down
/// and across the line; carried right it is done; carried left it is
/// deleted once confirmed; tapped, it opens its page and its notes.
class _Tasks extends StatelessWidget {
  const _Tasks({required this.project, required this.aim});

  final Project project;
  final TimelineAim aim;

  @override
  Widget build(BuildContext context) {
    final far = DateTime(9999);
    final done = [
      for (final t in project.tasks)
        if (t.place == TaskPlace.done) t,
    ]..sort((a, b) => (b.doneAt ?? far).compareTo(a.doneAt ?? far));
    final cards = [for (final t in done) _doneCard(t)];

    return TimelineList(
      mode: TimelineMode.list,
      only: {
        for (final t in project.tasks)
          if (t.place != TaskPlace.done) t.id,
      },
      done: cards,
      aim: aim,
      // A finished task is not on the timeline, so its page is handed the
      // card this list drew.
      onCardTap: (card) => unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EventPage(
              id: card.id,
              finished: cards.where((it) => it.id == card.id).firstOrNull,
              dock: NotesDock.task,
            ),
          ),
        ),
      ),
      onWriteDown: (placement) => unawaited(
        writeDownOnTimeline(
          context,
          placement: placement,
          projectId: project.id,
        ),
      ),
    );
  }

  static TimelineEvent _doneCard(ProjectTask task) {
    final at = task.doneAt ?? clock.now();
    return TimelineEvent(
      id: task.id,
      title: task.title,
      notes: task.notes,
      section: TimelineSection.backlog,
      startTime: at,
      endTime: at,
      durationMinutes: task.minutes,
    );
  }
}

/// The project's notes: free text, saved as it is written.
///
/// A moment after the typing stops, when the field loses focus, and when the
/// page closes, as a task's notes are. At their foot, the agent's bar and the
/// microphone that dictates into them ([NotesDock]).
class _Notes extends StatefulWidget {
  const _Notes({required this.project, this.voice, super.key});

  final Project project;
  final DictationCubit? voice;

  @override
  State<_Notes> createState() => _NotesState();
}

class _NotesState extends State<_Notes> {
  static const _debounce = Duration(milliseconds: 800);

  late final _controller = LiveTextController(text: widget.project.notes);
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final ProjectsCubit _cubit = context.read<ProjectsCubit>();
  Timer? _timer;

  late String _saved = widget.project.notes;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_Notes oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only notes changed somewhere else replace these: the server's echo of
    // what was saved here is not one, nor anything while it is dictated.
    if (!_focus.hasFocus &&
        _controller.live == null &&
        widget.project.notes != _saved) {
      _saved = widget.project.notes;
      _controller.notes = widget.project.notes;
    }
  }

  /// Typed or dictated, the notes are saved a moment after they stop
  /// changing; dictated words keep the end of the notes in sight.
  void _onChanged() {
    if (_controller.notes == _saved) return;
    _timer?.cancel();
    _timer = Timer(_debounce, _save);
    if (_controller.live != null) _followEnd();
  }

  void _followEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  void _save() {
    _timer?.cancel();
    final notes = _controller.notes;
    if (notes == _saved) return;

    _saved = notes;
    unawaited(_cubit.saveNotes(widget.project.id, notes));
  }

  @override
  void dispose() {
    _save();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s3,
        AppSpacing.s6,
        // Room to scroll the last line clear of the dock.
        kNotesDockClearance,
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        maxLines: null,
        minLines: 8,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: AppTypography.body,
        // A link's card is a line of its own, taller than the text's.
        strutStyle: StrutStyle.disabled,
        decoration: InputDecoration.collapsed(
          hintText: context.l10n.projectNotesHint,
          hintStyle: AppTypography.body.copyWith(color: AppColors.ink3),
        ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(child: notes),
        Positioned(
          left: 0,
          right: 0,
          bottom: kFloatingActionButtonMargin,
          child: Center(
            child: NotesDock(
              notes: _controller,
              about: AgentSubject.project(widget.project.id),
              voice: widget.voice,
            ),
          ),
        ),
      ],
    );
  }
}
