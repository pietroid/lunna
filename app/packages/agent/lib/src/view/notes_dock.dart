import 'dart:async';
import 'dart:math' as math;

import 'package:agent/src/models.dart';
import 'package:agent/src/view/ask_bar.dart';
import 'package:agent/src/view/voice_bar.dart';
import 'package:agent/src/voice/voice_cubit.dart';
import 'package:agent/src/voice/voice_recognizer.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// {@template notes_dock}
/// The foot of a page of notes (a task's, a project's): the agent's bar,
/// and beside it, where the + is on Tempo, a microphone that dictates.
///
/// Dictating is not talking to the agent. The words go straight into
/// [notes] as they are heard, each recording a paragraph of its own at the
/// end, the words the recognizer may still revise drawn in ink3. Stopping
/// keeps them; discarding takes that paragraph back out. The recording runs
/// until it is stopped, so one can speak freely.
///
/// The bar keeps its own microphone, which talks to the agent as it does on
/// Tempo ([AskDock]): the small one inside the bar asks, the big one beside
/// it writes. While the keyboard is up the dock steps aside, since the notes
/// are being typed.
///
/// There is one microphone: dictating stops the agent's recording, and the
/// agent's starting stops dictation, keeping its words. A microphone that is
/// refused, or a device with no recognizer, is said in a snackbar.
/// {@endtemplate}
class NotesDock extends StatelessWidget {
  /// {@macro notes_dock}
  const NotesDock({
    required this.notes,
    this.about,
    this.voice,
    super.key,
  });

  /// The dock of a task's notes, for `EventPage.dock`: the conversation is
  /// about the task, when the page is one's.
  static Widget task(
    BuildContext context,
    LiveTextController notes,
    String? taskId,
  ) => NotesDock(
    notes: notes,
    about: taskId == null ? null : AgentSubject.task(taskId),
  );

  /// The notes dictation writes into.
  final LiveTextController notes;

  /// What the agent's conversation is about: the page's task or project.
  final AgentSubject? about;

  /// The recording, when handed in; otherwise the dock has its own, apart
  /// from the agent's composer.
  final DictationCubit? voice;

  @override
  Widget build(BuildContext context) {
    final voice = this.voice;
    final view = _NotesDockView(notes: notes, about: about);

    return voice != null
        ? BlocProvider.value(value: voice, child: view)
        : BlocProvider(
            create: (context) =>
                DictationCubit(recognizer: context.read<VoiceRecognizer>()),
            child: view,
          );
  }
}

class _NotesDockView extends StatefulWidget {
  const _NotesDockView({required this.notes, this.about});

  final LiveTextController notes;
  final AgentSubject? about;

  @override
  State<_NotesDockView> createState() => _NotesDockViewState();
}

class _NotesDockViewState extends State<_NotesDockView>
    with WidgetsBindingObserver {
  static const _duration = Duration(milliseconds: 220);

  /// Whether the keyboard is up. Read off the view, since the page's
  /// Scaffold takes the insets out of what it hands its body.
  bool _typing = false;

  /// The notes as they were when this recording began, which its paragraph
  /// is written after.
  String? _before;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final voice = context.read<DictationCubit>().state;
    if (voice.status.recording) {
      _begin();
      _write(voice);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _typing = View.of(context).viewInsets.bottom > 0;
  }

  @override
  void didChangeMetrics() {
    final typing = View.of(context).viewInsets.bottom > 0;
    if (typing != _typing) setState(() => _typing = typing);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _begin() => _before = widget.notes.text.trimRight();

  /// The paragraph so far, after what was there, a blank line between.
  void _write(VoiceState voice) {
    final before = _before;
    if (before == null) return;

    final head = before.isEmpty ? '' : '$before\n\n';
    final heard = voice.heard.trim();
    final hearing = voice.hearing.trim();
    final gap = heard.isNotEmpty && hearing.isNotEmpty ? ' ' : '';
    final settled = '$head$heard$gap';
    final text = '$settled$hearing';

    widget.notes.write(
      text,
      live: hearing.isEmpty
          ? null
          : TextRange(start: settled.length, end: text.length),
    );
  }

  Future<void> _start() async {
    final asking = context.read<VoiceCubit>();
    final dictation = context.read<DictationCubit>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    if (asking.state.status.recording) await asking.cancel();

    _begin();
    await dictation.start();
    if (!mounted || dictation.state.status.offered) return;

    _before = null;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            dictation.state.status == VoiceStatus.denied
                ? l10n.agentVoiceDenied(AppBrand.id)
                : l10n.agentVoiceUnavailable,
          ),
        ),
      );
  }

  Future<void> _stop() async {
    final take = await context.read<DictationCubit>().take();
    if (take != null) {
      _write(VoiceState(heard: take.text));
    }
    widget.notes.settle();
    _before = null;
  }

  Future<void> _discard() async {
    final before = _before;
    _before = null;
    await context.read<DictationCubit>().cancel();
    if (before != null) widget.notes.write(before);
  }

  @override
  Widget build(BuildContext context) {
    final width =
        math.min(MediaQuery.sizeOf(context).width, AppSpacing.maxContentWidth) -
        2 * kFloatingActionButtonMargin;
    final asking = context.watch<VoiceCubit>().state.status.recording;
    final voice = context.watch<DictationCubit>().state;
    final recording = voice.status.recording;
    final l10n = context.l10n;

    return MultiBlocListener(
      listeners: [
        BlocListener<DictationCubit, VoiceState>(
          listenWhen: (before, after) =>
              after.status.recording &&
              (before.heard != after.heard || before.hearing != after.hearing),
          listener: (_, voice) => _write(voice),
        ),
        // The agent took the microphone: what was dictated stays.
        BlocListener<VoiceCubit, VoiceState>(
          listenWhen: (before, after) =>
              !before.status.recording && after.status.recording,
          listener: (context, _) {
            if (context.read<DictationCubit>().state.status.recording) {
              unawaited(_stop());
            }
          },
        ),
      ],
      child: Visibility(
        visible: recording || asking || !_typing,
        maintainState: true,
        child: SizedBox(
          width: width,
          child: AnimatedSwitcher(
            duration: _duration,
            switchInCurve: Curves.easeOutCubic,
            child: recording
                ? AskPill(
                    key: const ValueKey('dictating'),
                    child: VoiceBar(
                      voice: voice,
                      stopLabel: l10n.dictationStop,
                      discardLabel: l10n.dictationDiscard,
                      onStop: () => unawaited(_stop()),
                      onDiscard: () => unawaited(_discard()),
                    ),
                  )
                : AskDock(
                    key: const ValueKey('resting'),
                    about: widget.about,
                    fab: AppFab(
                      iconData: AppIcons.microphone,
                      tooltip: l10n.dictationStart,
                      onPressed: () => unawaited(_start()),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
