import 'dart:async';

import 'package:agent/src/agent_cubit.dart';
import 'package:agent/src/agent_repository.dart';
import 'package:agent/src/models.dart';
import 'package:agent/src/view/apply_plan.dart';
import 'package:agent/src/view/plan_card.dart';
import 'package:agent/src/voice/voice_cubit.dart';
import 'package:agent/src/voice/voice_recognizer.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// Opens the conversation over Tempo, about [day]; already recording when
/// [listen] is set.
///
/// The sheet is a route of its own, which need not sit under whatever
/// provides the conversation, the agent's routes and the day, so it is handed
/// all three from here, and the recognizer its recording runs on.
Future<void> showAgentSheet(
  BuildContext context, {
  DateTime? day,
  bool listen = false,
}) {
  final agent = context.read<AgentCubit>();
  final repository = context.read<AgentRepository>();
  final timeline = context.read<TimelineBloc>();
  final recognizer = context.read<VoiceRecognizer>();
  // Every opening is a new conversation; the last one goes above it.
  agent.open();

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
          BlocProvider(create: (_) => VoiceCubit(recognizer: recognizer)),
        ],
        child: FractionallySizedBox(
          heightFactor: 0.88,
          alignment: Alignment.bottomCenter,
          child: AgentSheet(day: day, listen: listen),
        ),
      ),
    ),
  );
}

/// {@template agent_sheet}
/// The conversation with the agent.
///
/// Empty, it offers what is most often asked. Then it is the conversation:
/// what the user said, what the agent did (one ticked line per step), what
/// it answered, and the plan it proposes, which nothing makes until Aplicar.
///
/// It opens on the conversation alone, which fills the sheet. The ones before
/// it are above, out of sight until the list is pulled down: dimmed, read
/// only, each under the day and hour it began.
///
/// What is said rather than typed is written into the composer as it is
/// heard, and sent as text.
/// {@endtemplate}
class AgentSheet extends StatefulWidget {
  /// {@macro agent_sheet}
  const AgentSheet({this.day, this.listen = false, super.key});

  /// The day Tempo is showing.
  final DateTime? day;

  /// Whether to start recording as it opens.
  final bool listen;

  @override
  State<AgentSheet> createState() => _AgentSheetState();
}

class _AgentSheetState extends State<AgentSheet> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  /// How long the text in the field took to say, when it was spoken and then
  /// corrected by hand.
  Duration? _spoken;

  @override
  void initState() {
    super.initState();
    if (widget.listen) unawaited(context.read<VoiceCubit>().start());
    _field.addListener(() {
      if (_field.text.isEmpty) _spoken = null;
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

  Future<void> _sendSpoken() async {
    final take = await context.read<VoiceCubit>().take();
    if (take != null && mounted) _send(take.text, take.length);
  }

  /// Stops hearing and hands the words to the keyboard.
  Future<void> _correct() async {
    final take = await context.read<VoiceCubit>().take();
    if (take == null || !mounted) return;

    _field
      ..text = take.text
      ..selection = TextSelection.collapsed(offset: take.text.length);
    _spoken = take.length;
    _focus.requestFocus();
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
                    builder: (context, voice) => voice.status.recording
                        ? _Recorder(
                            voice: voice,
                            onSend: _sendSpoken,
                            onCorrect: _correct,
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
                            onListen: () => unawaited(
                              context.read<VoiceCubit>().start(),
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
              ? _Welcome(onPick: onPick)
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
                        child: Text(
                          failure.message ?? l10n.agentFailure,
                          style: AppTypography.label.copyWith(
                            color: AppColors.dangerInk,
                          ),
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

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recording = context.select<VoiceCubit, bool>(
      (voice) => voice.state.status.recording,
    );
    final chips = [
      (AppIcons.prioritize, l10n.agentChipAfternoon),
      (AppIcons.calendar, l10n.agentChipStudy),
      (AppIcons.timer, l10n.agentChipLate),
      (AppIcons.time, l10n.agentChipTomorrow),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.agentGreeting, style: AppTypography.headline),
        const SizedBox(height: AppSpacing.s2),
        Text(
          recording ? l10n.agentVoiceHint : l10n.agentGreetingHint,
          style: AppTypography.label,
        ),
        const SizedBox(height: AppSpacing.s5),
        if (!recording)
          for (final (icon, text) in chips) ...[
            Material(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                onTap: () => onPick(text),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4,
                    vertical: AppSpacing.s3,
                  ),
                  child: Row(
                    children: [
                      AppIcon(
                        iconData: icon,
                        size: AppSpacing.s5,
                        color: AppColors.ink2,
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(child: Text(text, style: AppTypography.body)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
      ],
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
          ] else if (plan != null) ...[
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
                    return _Round(
                      label: l10n.agentVoiceStart,
                      icon: AppIcons.microphone,
                      fill: AppColors.surface,
                      ink: AppColors.accent,
                      onTap: onListen,
                    );
                  }

                  final ready = !busy && !empty;
                  return _Round(
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

/// A round button of the composer.
class _Round extends StatelessWidget {
  const _Round({
    required this.label,
    required this.icon,
    required this.fill,
    required this.ink,
    this.onTap,
    this.size = 36,
  });

  final String label;
  final AppIconData icon;
  final Color fill;
  final Color ink;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: size,
          height: size,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: Center(
            child: AppIcon(iconData: icon, size: size / 2, color: ink),
          ),
        ),
      ),
    );
  }
}

/// {@template recorder}
/// The composer while the user speaks: the words as they are heard, the
/// microphone's level, the time, and the two ways out.
///
/// What is settled is in ink, what the recognizer may still revise in ink3.
/// Tapping the words stops and hands them to the keyboard.
/// {@endtemplate}
class _Recorder extends StatelessWidget {
  /// {@macro recorder}
  const _Recorder({
    required this.voice,
    required this.onSend,
    required this.onCorrect,
    required this.onDiscard,
  });

  final VoiceState voice;
  final VoidCallback onSend;
  final VoidCallback onCorrect;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stopped = voice.status == VoiceStatus.stopped;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        0,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (!stopped) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
              ],
              Text(
                stopped ? l10n.agentVoiceStopped : l10n.agentVoiceListening,
                style: AppTypography.label.copyWith(
                  color: stopped ? AppColors.ink2 : AppColors.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Semantics(
            button: true,
            label: l10n.agentVoiceEdit,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: voice.text.isEmpty ? null : onCorrect,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: SizedBox(
                  width: double.infinity,
                  child: Text.rich(
                    TextSpan(
                      style: AppTypography.body.copyWith(fontSize: 17),
                      children: [
                        TextSpan(text: voice.heard),
                        if (voice.heard.isNotEmpty && voice.hearing.isNotEmpty)
                          const TextSpan(text: ' '),
                        TextSpan(
                          text: voice.hearing,
                          style: const TextStyle(color: AppColors.ink3),
                        ),
                        if (!stopped)
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: _Caret(),
                          ),
                      ],
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.fade,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              _Round(
                label: l10n.agentVoiceDiscard,
                icon: AppIcons.close,
                fill: AppColors.surface,
                ink: AppColors.ink2,
                onTap: onDiscard,
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: _Wave(levels: voice.levels, quiet: stopped),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                _clockText(voice.elapsed),
                style: AppTypography.label.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              _Round(
                label: l10n.agentSend,
                icon: AppIcons.arrowUp,
                fill: voice.text.isEmpty
                    ? AppColors.fillStrong
                    : AppColors.accent,
                ink: voice.text.isEmpty ? AppColors.ink3 : AppColors.onAccent,
                size: 44,
                onTap: voice.text.isEmpty ? null : onSend,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Caret extends StatelessWidget {
  const _Caret();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 18,
      margin: const EdgeInsets.only(left: 2),
      color: AppColors.accent,
    );
  }
}

/// The microphone's last levels as bars, newest on the right; a quiet one is
/// drawn grey, so a pause shows as a run of grey.
class _Wave extends StatelessWidget {
  const _Wave({required this.levels, this.quiet = false});

  final List<double> levels;

  /// Whether the microphone is off, which greys the whole wave.
  final bool quiet;

  static const _height = 32.0;

  @override
  Widget build(BuildContext context) {
    final padding = VoiceCubit.bars - levels.length;

    return SizedBox(
      height: _height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < VoiceCubit.bars; i++)
            _bar(i < padding ? null : levels[i - padding]),
        ],
      ),
    );
  }

  Widget _bar(double? level) {
    final loud = !quiet && level != null && level > 0.15;
    return Container(
      width: 3,
      height: level == null ? 4 : 4 + (level.clamp(0, 1) * (_height - 4)),
      decoration: BoxDecoration(
        color: loud ? AppColors.accent : AppColors.ink3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
