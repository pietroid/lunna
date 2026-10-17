import 'dart:async';

import 'package:agent/src/agent_cubit.dart';
import 'package:agent/src/agent_repository.dart';
import 'package:agent/src/models.dart';
import 'package:agent/src/view/apply_plan.dart';
import 'package:agent/src/view/failure_note.dart';
import 'package:agent/src/view/plan_card.dart';
import 'package:agent/src/view/quick_replies.dart';
import 'package:agent/src/view/voice_bar.dart';
import 'package:agent/src/voice/voice_cubit.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// Opens the conversation over Tempo, about [day], straight on the field,
/// with [draft] in it, selected, when there is one.
///
/// The sheet is a route of its own, which need not sit under whatever
/// provides the conversation, the agent's routes and the day, so it is handed
/// all three from here, and the recording, which is the app's: one started
/// on Tempo's bar carries on here.
Future<void> showAgentSheet(
  BuildContext context, {
  DateTime? day,
  String? draft,
  AgentSubject? about,
}) {
  final agent = context.read<AgentCubit>();
  final repository = context.read<AgentRepository>();
  final timeline = context.read<TimelineBloc>();
  final voice = context.read<VoiceCubit>();
  // Every opening is a new conversation; the last one goes above it.
  agent.open(about: about);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.32),
    builder: (_) => RepositoryProvider.value(
      value: repository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: agent),
          BlocProvider.value(value: timeline),
          BlocProvider.value(value: voice),
        ],
        child: FractionallySizedBox(
          heightFactor: 0.88,
          alignment: Alignment.bottomCenter,
          child: AgentSheet(day: day, draft: draft),
        ),
      ),
    ),
  );
}

/// {@template agent_sheet}
/// The conversation with the agent.
///
/// It opens empty, on the field, keyboard up. Then it is the conversation:
/// what the user said, what the agent did (one ticked line per step), what
/// it answered, and the plan it proposes, which nothing makes until Aplicar.
///
/// It opens on the conversation alone, which fills the sheet. The ones before
/// it are above, out of sight until the list is pulled down: dimmed, read
/// only, each under the day and hour it began.
///
/// What is said rather than typed is shown as it is heard, over the
/// recorder; stopping puts it in the field, selected, to be sent as text.
/// {@endtemplate}
class AgentSheet extends StatefulWidget {
  /// {@macro agent_sheet}
  const AgentSheet({this.day, this.draft, super.key});

  /// The day Tempo is showing.
  final DateTime? day;

  /// What the field opens with, selected, so it can be sent, changed or
  /// typed over.
  final String? draft;

  @override
  State<AgentSheet> createState() => _AgentSheetState();
}

class _AgentSheetState extends State<AgentSheet> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  /// Letting go of a held microphone stops it.
  late final _hold = VoiceHold(onRelease: () => unawaited(_stop()));

  /// How long the text in the field took to say, when it was spoken and then
  /// corrected by hand.
  Duration? _spoken;

  @override
  void initState() {
    super.initState();
    final voice = context.read<VoiceCubit>();
    final draft = widget.draft;
    if (draft != null) _fill(draft);
    _field.addListener(() {
      if (_field.text.isEmpty) _spoken = null;
    });
    // Straight to the field: the keyboard comes up with the sheet, unless
    // the microphone has the floor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !voice.state.status.recording) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text, Duration? voice]) {
    final said = (text ?? _field.text).trim();
    if (said.isEmpty) return;

    final spoken = voice ?? (text == null ? _spoken : null);
    if (text == null) _field.clear();
    _spoken = null;
    unawaited(
      context.read<AgentCubit>().send(said, day: widget.day, voice: spoken),
    );
  }

  /// Stops hearing and hands the words to the field, selected.
  Future<void> _stop() async {
    final voice = context.read<VoiceCubit>();
    // Still asking for the microphone: the recording goes on as if tapped.
    if (voice.state.status == VoiceStatus.preparing) return;
    final take = await voice.take();
    if (take == null || !mounted) return;

    _fill(take.text);
    _spoken = take.length;
    _focus.requestFocus();
  }

  /// Puts [text] in the field, all of it selected.
  void _fill(String text) {
    _field
      ..text = text
      ..selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }

  /// Puts [draft] in the field, to be finished by hand.
  void _draft(String draft) {
    _field
      ..text = draft
      ..selection = TextSelection.collapsed(offset: draft.length);
    _focus.requestFocus();
  }

  /// Back to the newest message, which is the bottom of a reversed list.
  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  /// Reads older conversations once the top of those held is near.
  bool _onScroll(ScrollNotification notification) {
    final position = notification.metrics;
    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(context.read<AgentCubit>().loadPast());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadius + 4),
          ),
        ),
        child: SafeArea(
          top: false,
          child: BlocConsumer<AgentCubit, AgentState>(
            listenWhen: (a, b) =>
                a.entries.length != b.entries.length || a.busy != b.busy,
            listener: (_, _) => _toEnd(),
            builder: (context, state) {
              return Column(
                children: [
                  const _Grabber(),
                  const _Header(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) =>
                          NotificationListener<ScrollNotification>(
                            onNotification: _onScroll,
                            child: ListView(
                              controller: _scroll,
                              // Newest at the bottom, where it opens.
                              reverse: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s5,
                              ),
                              children: [
                                ConstrainedBox(
                                  // The conversation fills the sheet, so the
                                  // past is out of sight until pulled down.
                                  constraints: BoxConstraints(
                                    minHeight: box.maxHeight,
                                  ),
                                  child: _Current(
                                    state: state,
                                    onPick: _send,
                                    onAdjust: (plan) => plan.pushed.isEmpty
                                        ? _focus.requestFocus()
                                        : _draft(l10n.agentOtherTimeDraft),
                                    onLoadPast: context
                                        .read<AgentCubit>()
                                        .loadPast,
                                  ),
                                ),
                                if (state.past.isNotEmpty)
                                  _Divider(
                                    l10n.agentHistoryNow(DateTime.now()),
                                    accent: true,
                                  ),
                                for (final conversation in state.past)
                                  _Past(conversation: conversation),
                                if (state.pastStatus == PastStatus.loading)
                                  const Padding(
                                    padding: EdgeInsets.all(AppSpacing.s4),
                                    child: Center(
                                      child: SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.ink3,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                    ),
                  ),
                  BlocBuilder<VoiceCubit, VoiceState>(
                    builder: (context, voice) => Listener(
                      // Wherever the finger is let go, the microphone it
                      // held is gone.
                      onPointerUp: (_) => _hold.release(),
                      onPointerCancel: (_) => _hold.release(),
                      child: voice.status.recording
                          ? _Recording(
                              voice: voice,
                              onStop: _stop,
                              onDiscard: context.read<VoiceCubit>().cancel,
                            )
                          : _Composer(
                              controller: _field,
                              focusNode: _focus,
                              hint: state.entries.isEmpty
                                  ? l10n.agentInputHint
                                  : l10n.agentReplyHint,
                              busy: state.busy,
                              voice: voice.status,
                              onSend: _send,
                              onListen: () {
                                _hold.press();
                                unawaited(context.read<VoiceCubit>().start());
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(top: AppSpacing.s3, bottom: AppSpacing.s1),
      decoration: BoxDecoration(
        color: AppColors.fillStrong,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        AppSpacing.s2,
        AppSpacing.s3,
        AppSpacing.s2,
      ),
      child: Row(
        children: [
          const AppIcon(iconData: AppIcons.agent, size: 26),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(l10n.appName(AppBrand.id), style: AppTypography.title),
          ),
          Tooltip(
            message: l10n.agentClose,
            child: AppIconButton(
              iconData: AppIcons.close,
              size: AppSpacing.s5,
              color: AppColors.ink2,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The conversation being had, at the bottom of the sheet, under a hint
/// that the ones before it are above.
class _Current extends StatelessWidget {
  const _Current({
    required this.state,
    required this.onPick,
    required this.onAdjust,
    required this.onLoadPast,
  });

  final AgentState state;

  final ValueChanged<String> onPick;

  final ValueChanged<AgentPlan> onAdjust;

  final VoidCallback onLoadPast;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final quiet = AppTypography.label.copyWith(color: AppColors.ink3);

    return Column(
      // Held at least as tall as the sheet: the hint at the top, the
      // conversation at the bottom, by the composer.
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.past.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon(
                  iconData: AppIcons.earlier,
                  size: 12,
                  color: AppColors.ink3,
                ),
                const SizedBox(width: AppSpacing.s1),
                Text(l10n.agentEarlier, style: quiet),
              ],
            ),
          )
        else if (state.pastStatus == PastStatus.failed)
          InkWell(
            onTap: onLoadPast,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: Text(
                l10n.agentEarlierFailed,
                style: quiet,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.s5,
            bottom: AppSpacing.s4,
          ),
          child: state.entries.isEmpty && !state.busy
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in state.entries)
                      switch (entry) {
                        UserEntry(:final text, :final voice) => _Said(
                          text,
                          voice: voice,
                        ),
                        ReplyEntry() => _Answer(
                          entry: entry,
                          onAdjust: onAdjust,
                        ),
                      },
                    if (state.busy) const _Thinking(),
                    if (state.failure case final failure?)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s2),
                        child: FailureNote(
                          failure: failure,
                          onRetry: context.read<AgentCubit>().retry,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// A conversation already over, under the day and hour it began: dimmed,
/// and read only.
class _Past extends StatelessWidget {
  const _Past({required this.conversation});

  final PastConversation conversation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Divider(_startedText(context.l10n, conversation.startedAt)),
        for (final entry in conversation.entries)
          switch (entry) {
            UserEntry(:final text, :final voice) => _Said(
              text,
              voice: voice,
              past: true,
            ),
            ReplyEntry() => _Answer(entry: entry),
          },
      ],
    );
  }
}

/// "Hoje · 14:12", "Ontem, quarta-feira · 18:40", "seg., 12 de out. · 09:10".
String _startedText(AppLocalizations l10n, DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final ago = today.difference(day).inHours ~/ 24;

  final text = switch (ago) {
    0 => l10n.agentHistoryToday(at),
    1 => l10n.agentHistoryYesterday(at, at),
    _ => l10n.agentHistoryDay(at, at),
  };
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// A thin rule with a time on it, between conversations.
class _Divider extends StatelessWidget {
  const _Divider(this.text, {this.accent = false});

  final String text;

  /// Whether it marks where the conversation being had begins.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.accent : AppColors.ink3;
    const rule = Expanded(child: Divider(height: 1, color: AppColors.line));

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s3, bottom: AppSpacing.s4),
      child: Row(
        children: [
          rule,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
            child: Text(
              text,
              style: AppTypography.label.copyWith(color: color, fontSize: 12),
            ),
          ),
          rule,
        ],
      ),
    );
  }
}

/// What the user said, on the right, in ink, marked when it was spoken.
class _Said extends StatelessWidget {
  const _Said(this.text, {this.voice, this.past = false});

  final String text;

  final Duration? voice;

  /// Whether it belongs to a conversation already over, drawn quieter.
  final bool past;

  @override
  Widget build(BuildContext context) {
    final voice = this.voice;
    final bubble = Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.s4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        decoration: BoxDecoration(
          color: past ? AppColors.fillStrong : AppColors.ink,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          text,
          style: AppTypography.body.copyWith(
            color: past ? AppColors.ink : AppColors.bg,
          ),
        ),
      ),
    );
    if (voice == null) return bubble;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        bubble,
        Transform.translate(
          offset: const Offset(0, -AppSpacing.s2),
          child: Padding(
            padding: const EdgeInsets.only(
              right: AppSpacing.s1,
              bottom: AppSpacing.s2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(
                  iconData: AppIcons.microphone,
                  size: 12,
                  color: AppColors.ink3,
                ),
                const SizedBox(width: AppSpacing.s1),
                Text(
                  context.l10n.agentVoiceVia(_clockText(voice)),
                  style: AppTypography.label.copyWith(
                    color: AppColors.ink3,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A length as a stopwatch shows it: 0:09, 1:00.
String _clockText(Duration length) {
  final seconds = length.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// What the agent did and said, and its plan.
///
/// Without [onAdjust] it belongs to a conversation already over: quieter,
/// and its plan is one line saying what became of it.
class _Answer extends StatelessWidget {
  const _Answer({required this.entry, this.onAdjust});

  final ReplyEntry entry;

  final ValueChanged<AgentPlan>? onAdjust;

  @override
  Widget build(BuildContext context) {
    final reply = entry.reply;
    final plan = reply.plan;
    final tookOption = entry.chosen != null && entry.chosen != plan?.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in reply.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: Row(
                children: [
                  const AppIcon(
                    iconData: AppIcons.check,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(child: Text(step, style: AppTypography.label)),
                ],
              ),
            ),
          if (reply.steps.isNotEmpty) const SizedBox(height: AppSpacing.s1),
          Text(
            reply.text,
            style: onAdjust == null
                ? AppTypography.body.copyWith(color: AppColors.ink2)
                : AppTypography.body,
          ),
          if (plan != null && onAdjust == null) ...[
            const SizedBox(height: AppSpacing.s3),
            PlanLine(plan: plan, status: entry.status),
          ] else if (plan != null && !tookOption) ...[
            const SizedBox(height: AppSpacing.s3),
            PlanCard(
              plan: plan,
              status: entry.status,
              onAdjust: () => onAdjust!(plan),
              onApply: () async {
                final navigator = Navigator.of(context);
                if (await applyAgentPlan(context, plan)) navigator.pop();
              },
            ),
          ],
          // Offered beside the plan or instead of it; gone once the plan is.
          if (reply.options.isNotEmpty &&
              onAdjust != null &&
              (entry.chosen == null || tookOption)) ...[
            const SizedBox(height: AppSpacing.s3),
            QuickReplies(
              options: reply.options,
              status: entry.status,
              chosen: entry.chosen,
              onPick: (option) async {
                final navigator = Navigator.of(context);
                if (await applyAgentPlan(context, option.plan)) {
                  navigator.pop();
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.ink3,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Text(context.l10n.agentThinking, style: AppTypography.label),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.busy,
    required this.voice,
    required this.onSend,
    required this.onListen,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool busy;

  /// Where the microphone stands: offered, or why not.
  final VoiceStatus voice;

  final VoidCallback onSend;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final refusal = switch (voice) {
      VoiceStatus.denied => l10n.agentVoiceDenied(AppBrand.id),
      VoiceStatus.unavailable => l10n.agentVoiceUnavailable,
      _ => null,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        0,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s4,
        refusal == null ? AppSpacing.s1 : AppSpacing.s3,
        AppSpacing.s2,
        AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (refusal != null)
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.s2),
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIcon(
                    iconData: AppIcons.microphoneSlash,
                    size: 18,
                    color: AppColors.ink2,
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(child: Text(refusal, style: AppTypography.label)),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: AppTypography.body,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTypography.body.copyWith(
                      color: AppColors.ink3,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s3,
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final empty = controller.text.trim().isEmpty;

                  // An empty field offers the microphone; typing turns it
                  // into send.
                  if (empty && voice.offered && !busy) {
                    return VoiceRound(
                      label: l10n.agentVoiceStart,
                      icon: AppIcons.microphone,
                      fill: AppColors.surface,
                      ink: AppColors.accent,
                      onPress: onListen,
                    );
                  }

                  final ready = !busy && !empty;
                  return VoiceRound(
                    label: l10n.agentSend,
                    icon: AppIcons.arrowUp,
                    fill: ready ? AppColors.accent : AppColors.fillStrong,
                    ink: ready ? AppColors.onAccent : AppColors.ink3,
                    onTap: ready ? onSend : null,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// {@template recording}
/// The composer while the user speaks: the words as they come, on the right
/// where they will be sent from, over the recorder in the field's place.
/// {@endtemplate}
class _Recording extends StatelessWidget {
  /// {@macro recording}
  const _Recording({
    required this.voice,
    required this.onStop,
    required this.onDiscard,
  });

  final VoiceState voice;
  final VoidCallback onStop;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        0,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            margin: const EdgeInsets.only(bottom: AppSpacing.s3),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s3,
            ),
            decoration: BoxDecoration(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: VoiceTranscript(voice: voice, maxLines: 6),
          ),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
            decoration: BoxDecoration(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            ),
            child: VoiceBar(voice: voice, onStop: onStop, onDiscard: onDiscard),
          ),
        ],
      ),
    );
  }
}
