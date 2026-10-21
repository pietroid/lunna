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
/// The foot of a page of notes (a task's, an artifact's): the agent's bar,
/// and beside it, where the + is on Tempo, a microphone that dictates.
///
/// Dictating is not talking to the agent. The words go straight into
/// [notes] as they are heard, each recording a paragraph of its own (at
/// the cursor while the notes are being typed in, at the end otherwise),
/// the words the recognizer may still revise drawn in ink3. Stopping
/// keeps them; discarding takes that paragraph back out. The recording runs
/// until it is stopped, so one can speak freely.
///
/// The bar keeps its own microphone, which talks to the agent as it does on
/// Tempo ([AskDock]): the small one inside the bar asks, the big one beside
/// it writes. The dock never moves or changes shape: with the keyboard up it
/// sits on top of it, so one can type and dictate in the same breath.
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

  /// What the agent's conversation is about: the page's task or artifact.
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

class _NotesDockViewState extends State<_NotesDockView> {
  /// The notes as they were when this recording began, split where its
  /// paragraph goes: at the cursor while the notes are being typed in, at
  /// the end otherwise.
  String? _before;
  String _after = '';

  @override
  void initState() {
    super.initState();
    final voice = context.read<DictationCubit>().state;
    if (voice.status.recording) {
      _begin();
      _write(voice);
    }
  }

  void _begin() {
    final text = widget.notes.text;
    final at = _typing ? widget.notes.selection.start : -1;
    final split = at < 0 || at > text.length ? text.length : at;
    _before = text.substring(0, split).trimRight();
    _after = text.substring(split).trimLeft();
  }

  /// Whether the notes have the keyboard.
  bool get _typing {
    final focused = FocusManager.instance.primaryFocus?.context;
    final field = focused?.findAncestorWidgetOfExactType<EditableText>();
    return field?.controller == widget.notes;
  }

  /// The paragraph so far, between what was there, a blank line on each
  /// side.
  void _write(VoiceState voice) {
    final before = _before;
    if (before == null) return;

    final head = before.isEmpty ? '' : '$before\n\n';
    final heard = voice.heard.trim();
    final hearing = voice.hearing.trim();
    final gap = heard.isNotEmpty && hearing.isNotEmpty ? ' ' : '';
    final settled = '$head$heard$gap';
    final said = '$settled$hearing';

    widget.notes.write(
      '$said${_tail()}',
      live: hearing.isEmpty
          ? null
          : TextRange(start: settled.length, end: said.length),
      cursor: said.length,
    );
  }

  String _tail() => _after.isEmpty ? '' : '\n\n$_after';

  void _end() {
    _before = null;
    _after = '';
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

    _end();
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
    _end();
  }

  Future<void> _discard() async {
    final before = _before;
    final after = _after;
    _end();
    await context.read<DictationCubit>().cancel();
    if (before == null) return;
    final head = before.isEmpty || after.isEmpty ? before : '$before\n\n';
    widget.notes.write('$head$after', cursor: head.length);
  }

  @override
  Widget build(BuildContext context) {
    final width =
        math.min(MediaQuery.sizeOf(context).width, AppSpacing.maxContentWidth) -
        2 * kFloatingActionButtonMargin;
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
      // Swapped in place, with no animation: the bar is where the finger
      // expects it, every time. A tap on it is a tap inside the notes, which
      // keep the keyboard and the cursor dictation writes at.
      child: TextFieldTapRegion(
        child: SizedBox(
          width: width,
          child: recording
              ? AskPill(
                  child: VoiceBar(
                    voice: voice,
                    stopLabel: l10n.dictationStop,
                    discardLabel: l10n.dictationDiscard,
                    onStop: () => unawaited(_stop()),
                    onDiscard: () => unawaited(_discard()),
                  ),
                )
              : AskDock(
                  about: widget.about,
                  fab: AppFab(
                    iconData: AppIcons.microphone,
                    tooltip: l10n.dictationStart,
                    onPressed: () => unawaited(_start()),
                  ),
                ),
        ),
      ),
    );
  }
}
