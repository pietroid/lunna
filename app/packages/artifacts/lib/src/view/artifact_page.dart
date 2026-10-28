import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/artifact_format.dart';
import 'package:artifacts/src/view/failure_listener.dart';
import 'package:artifacts/src/view/pace_bars.dart';
import 'package:artifacts/src/view/value_sheet.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeline/timeline.dart';

/// Opens the artifact with [id] on its own page, over the tab.
///
/// The page is its own route, so it is handed the cubit it reads.
Future<void> openArtifact(BuildContext context, String id, {int? tab}) {
  final cubit = context.read<ArtifactsCubit>();

  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ArtifactPage(id: id, initialTab: tab),
      ),
    ),
  );
}

/// {@template artifact_page}
/// One artifact, opened: the same shape as a task's page.
///
/// The name beside the back button, edited where it is written. Under it the
/// deadline, a tap away from a picker, and the artifact's own row of buttons:
/// a day less, a day more, done. The bar is the one Entregas draws: the
/// work done in green over the time gone in red ([PaceBars]).
///
/// Under that, three spaces of their own: the notes, what is still to do
/// (Pendentes), and what was done (Feitas), opening on whichever was last
/// chosen for this artifact, on this device. Pendentes is Tempo's Lista
/// kept to this artifact, with Tempo's bar and + at the foot.
/// {@endtemplate}
class ArtifactPage extends StatefulWidget {
  /// {@macro artifact_page}
  const ArtifactPage({
    required this.id,
    this.initialTab,
    this.dictation,
    super.key,
  });

  /// The artifact's id.
  final String id;

  /// Which space opens first: 0 the notes, 1 what is to do, 2 what was
  /// done. Null opens the one this device last chose.
  final int? initialTab;

  /// The recording the notes are dictated with, when handed in (tests and
  /// previews); otherwise the notes have their own.
  final DictationCubit? dictation;

  @override
  State<ArtifactPage> createState() => _ArtifactPageState();
}

class _ArtifactPageState extends State<ArtifactPage> {
  static const _notesTab = 0;
  static const _tasksTab = 1;
  static const _doneTab = 2;

  /// Where this artifact's last choice of space is kept, on this device:
  /// each artifact opens the way it was left.
  String get _tabKey => 'artifact.tab.${widget.id}';

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

  Future<void> _delete(BuildContext context, Artifact artifact) async {
    final cubit = context.read<ArtifactsCubit>();
    final navigator = Navigator.of(context);
    if (!await confirmDelete(
      context,
      artifact.title,
      body: context.l10n.artifactDeleteBody,
    )) {
      return;
    }

    navigator.pop();
    await cubit.delete(artifact.id);
  }

  @override
  Widget build(BuildContext context) {
    final artifact = context.select<ArtifactsCubit, Artifact?>(
      (cubit) => cubit.state.byId(widget.id),
    );

    // Every change to a task here is the day's, through the timeline, so the
    // artifact reads itself again whenever the day's tasks change.
    return BlocListener<TimelineBloc, TimelineState>(
      listenWhen: (before, after) =>
          before.tasks != after.tasks || before.backlog != after.backlog,
      listener: (context, _) =>
          unawaited(context.read<ArtifactsCubit>().load()),
      child: ArtifactsFailureListener(
        child: Scaffold(
          appBar: AppBar(
            leading: AppIconButton(
              iconData: AppIcons.back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            titleSpacing: 0,
            title: artifact == null ? null : _Title(artifact: artifact),
            actions: [
              if (artifact != null)
                AppIconButton(
                  iconData: AppIcons.check,
                  color: artifact.isDone ? AppColors.accent : AppColors.ink2,
                  onPressed: () => unawaited(
                    context.read<ArtifactsCubit>().setDone(
                      artifact.id,
                      done: !artifact.isDone,
                    ),
                  ),
                ),
              if (artifact != null)
                AppIconButton(
                  iconData: AppIcons.trash,
                  color: AppColors.ink2,
                  onPressed: () => unawaited(_delete(context, artifact)),
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
                child: artifact == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Summary(artifact: artifact),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s6,
                              AppSpacing.s2,
                              AppSpacing.s6,
                              AppSpacing.s2,
                            ),
                            // Three tabs with their counts: on a narrow
                            // phone, or with large text, they shrink to fit
                            // rather than run off the edge.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: AppSegmented(
                                selected: _tab,
                                onSelected: _choose,
                                segments: [
                                  AppSegment(
                                    label: context.l10n.artifactNotesTab,
                                    iconData: AppIcons.pen,
                                  ),
                                  AppSegment(
                                    label: context.l10n.artifactPendingTab(
                                      artifact.steps - artifact.stepsDone,
                                    ),
                                    iconData: AppIcons.time,
                                  ),
                                  AppSegment(
                                    label: context.l10n.artifactDoneTab(
                                      artifact.stepsDone,
                                    ),
                                    iconData: AppIcons.check,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: _tab == _tasksTab
                                ? _Tasks(artifact: artifact, aim: _aim)
                                : _tab == _doneTab
                                ? _Done(artifact: artifact)
                                : _Notes(
                                    key: ValueKey(artifact.id),
                                    artifact: artifact,
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
          floatingActionButton: artifact == null || _tab != _tasksTab
              ? null
              : AskDock(
                  about: AgentSubject.artifact(widget.id),
                  fab: AppFab(
                    tooltip: context.l10n.artifactAddTask,
                    onPressed: () => unawaited(
                      writeDownOnTimeline(
                        context,
                        placement: _aim.value ?? const Placement.backlog(),
                        artifactId: widget.id,
                      ),
                    ),
                  ),
                ),
          floatingActionButtonLocation: AskDock.location,
          // Notas draws its own dock in the same place: Pendentes' comes in
          // without growing out of nothing.
          floatingActionButtonAnimator: AskDock.animator,
        ),
      ),
    );
  }
}

/// The name, edited where it is written.
class _Title extends StatefulWidget {
  const _Title({required this.artifact});

  final Artifact artifact;

  @override
  State<_Title> createState() => _TitleState();
}

class _TitleState extends State<_Title> {
  late final _controller = TextEditingController(text: widget.artifact.title);
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
    if (!_focus.hasFocus && widget.artifact.title != _controller.text) {
      _controller.text = widget.artifact.title;
    }
  }

  void _commit() {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      _controller.text = widget.artifact.title;
      return;
    }
    if (title == widget.artifact.title) return;

    unawaited(context.read<ArtifactsCubit>().rename(widget.artifact.id, title));
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
        hintText: context.l10n.artifactUntitled,
      ),
      onSubmitted: (_) => _focus.unfocus(),
    );
  }
}

/// The deadline, the buttons, and the bar.
class _Summary extends StatelessWidget {
  const _Summary({required this.artifact});

  final Artifact artifact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = clock.now();
    final cubit = context.read<ArtifactsCubit>();
    final remaining = remainingLabel(l10n, artifact, now);
    final overdue = isOverdue(artifact, now);
    final dated = artifact.deadline != null;

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
          _Property(
            label: l10n.artifactDeadlineLabel,
            child: Row(
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
                          ? deadlineLabel(l10n, artifact, now)
                          : l10n.artifactGiveDeadline,
                      style: AppTypography.labelStrong.copyWith(
                        color: dated ? AppColors.ink : AppColors.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    artifact.isDone
                        ? l10n.artifactDoneOn(
                            AppWheelPicker.dayLabel(
                              l10n,
                              artifact.doneAt!,
                              now: now,
                            ).toLowerCase(),
                          )
                        : dated
                        ? remaining ?? ''
                        : '',
                    style: AppTypography.label.copyWith(
                      color: overdue ? AppColors.dangerInk : AppColors.ink2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // What it is: its kind (or a one-off) and its time.
          _Property(
            label: l10n.artifactKindLabel,
            child: Text(
              [
                artifact.type?.name ?? l10n.artifactLoose,
                if (artifact.minutes > 0) formatMinutes(l10n, artifact.minutes),
              ].join(' · '),
              style: AppTypography.labelStrong.copyWith(color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // What it is worth, which a money goal counts once delivered; a
          // tap changes it.
          _Property(
            label: l10n.artifactValue,
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => unawaited(showValueSheet(context, artifact)),
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
                  child: Text(
                    artifact.value == null
                        ? l10n.artifactValueAdd
                        : formatMoney(artifact.value!),
                    style: AppTypography.labelStrong.copyWith(
                      color: artifact.value == null
                          ? AppColors.accent
                          : AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          // The bar Entregas draws, work over time, whose key already says
          // how many tasks are done; beside it the buttons that move the
          // deadline a day either way.
          if (!artifact.isDone)
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s2),
                    child: PaceBars(artifact: artifact, now: now),
                  ),
                ),
                if (dated) ...[
                  const SizedBox(width: AppSpacing.s2),
                  _Action(
                    tooltip: l10n.artifactLessDay,
                    onTap: (artifact.daysLeftAt(now) ?? 0) > 0
                        ? () => cubit.shiftDeadline(artifact.id, -1)
                        : null,
                    child: _Days(l10n.artifactMinusDay),
                  ),
                  _Action(
                    tooltip: l10n.artifactMoreDay,
                    onTap: () => cubit.shiftDeadline(artifact.id, 1),
                    child: _Days(l10n.artifactPlusDay),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _pickDeadline(BuildContext context) async {
    final cubit = context.read<ArtifactsCubit>();
    final now = clock.now();
    final picked = await AppWheelPicker.dayAndTime(
      context,
      initial: artifact.deadline ?? now.add(const Duration(days: 7)),
      earliest: now,
    );
    if (picked == null) return;

    await cubit.setDeadline(
      artifact.id,
      DateTime(picked.year, picked.month, picked.day),
    );
  }
}

/// One labelled row of the summary, as on a task's page.
class _Property extends StatelessWidget {
  const _Property({required this.label, required this.child});

  final String label;
  final Widget child;

  static const _labelWidth = 84.0;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.s8 + 4),
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              label,
              style: AppTypography.label.copyWith(color: AppColors.ink3),
            ),
          ),
          Expanded(child: child),
        ],
      ),
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

/// The artifact's tasks still to do, drawn by the very list Tempo draws in
/// Lista, kept to this artifact's: each day it reaches under Tempo's
/// headings, then Para depois.
///
/// So everything a card does there it does here: held, it moves up, down
/// and across the line; carried right it is done; carried left it is
/// deleted once confirmed; tapped, it opens its page and its notes.
class _Tasks extends StatelessWidget {
  const _Tasks({required this.artifact, required this.aim});

  final Artifact artifact;
  final TimelineAim aim;

  @override
  Widget build(BuildContext context) {
    return TimelineList(
      mode: TimelineMode.list,
      only: {
        for (final t in artifact.tasks)
          if (t.place != TaskPlace.done) t.id,
      },
      aim: aim,
      onCardTap: (card) => unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EventPage(id: card.id, dock: NotesDock.task),
          ),
        ),
      ),
      onWriteDown: (placement) => unawaited(
        writeDownOnTimeline(
          context,
          placement: placement,
          artifactId: artifact.id,
        ),
      ),
    );
  }
}

/// What was done of the artifact, newest first, under the day it was done
/// on, as Feitas in the Menu draws it. Nothing here names the artifact: the
/// page already does.
class _Done extends StatelessWidget {
  const _Done({required this.artifact});

  final Artifact artifact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = clock.now();
    final done = [
      for (final t in artifact.tasks)
        if (t.place == TaskPlace.done) _doneCard(t),
    ]..sort((a, b) => b.startTime.compareTo(a.startTime));
    final rows = <Widget>[];
    DateTime? day;
    for (final card in done) {
      final at = card.startTime;
      final its = DateTime(at.year, at.month, at.day);
      if (its != day) {
        day = its;
        rows.add(
          Padding(
            padding: EdgeInsets.only(
              top: rows.isEmpty ? AppSpacing.s2 : AppSpacing.s6,
              bottom: AppSpacing.s1,
            ),
            child: Text(
              doneDayLabel(l10n, its, now),
              style: AppTypography.title,
            ),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s1),
          child: DoneArchiveTile(
            card: card,
            // A finished task is not on the timeline, so its page is
            // handed the card drawn here.
            onTap: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EventPage(
                    id: card.id,
                    finished: card,
                    dock: NotesDock.task,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        0,
        AppSpacing.s6,
        AppSpacing.s12,
      ),
      children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
            child: Text(
              l10n.artifactDoneEmpty,
              style: AppTypography.label.copyWith(color: AppColors.ink3),
            ),
          ),
        ...rows,
      ],
    );
  }

  /// A done task as a card whose start is when it was done, as Feitas
  /// reads them.
  static TimelineEvent _doneCard(ArtifactTask task) {
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

/// The artifact's notes: free text, saved as it is written.
///
/// A moment after the typing stops, when the field loses focus, and when the
/// page closes, as a task's notes are. At their foot, the agent's bar and the
/// microphone that dictates into them ([NotesDock]).
class _Notes extends StatefulWidget {
  const _Notes({required this.artifact, this.voice, super.key});

  final Artifact artifact;
  final DictationCubit? voice;

  @override
  State<_Notes> createState() => _NotesState();
}

class _NotesState extends State<_Notes> {
  static const _debounce = Duration(milliseconds: 800);

  late final _controller = LiveTextController(text: widget.artifact.notes);
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final ArtifactsCubit _cubit = context.read<ArtifactsCubit>();
  Timer? _timer;

  late String _saved = widget.artifact.notes;

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
        widget.artifact.notes != _saved) {
      _saved = widget.artifact.notes;
      _controller.notes = widget.artifact.notes;
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
    unawaited(_cubit.saveNotes(widget.artifact.id, notes));
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
          hintText: context.l10n.artifactNotesHint,
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
              about: AgentSubject.artifact(widget.artifact.id),
              voice: widget.voice,
            ),
          ),
        ),
      ],
    );
  }
}
