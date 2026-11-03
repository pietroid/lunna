import 'dart:async';

import 'package:agent/src/compose_cubit.dart';
import 'package:agent/src/view/voice_bar.dart';
import 'package:agent/src/voice/voice_cubit.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// {@template compose_button}
/// The one button at the foot of every screen: the app's plus, where it
/// always was.
///
/// It replaces both the + (which wrote a task through a form) and the
/// agent's bar (which asked): whatever is typed or said in the sheet it
/// opens is read once, and comes back as one small summary to confirm.
/// {@endtemplate}
class ComposeButton extends StatelessWidget {
  /// {@macro compose_button}
  const ComposeButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppFab(
      tooltip: context.l10n.composeOpen,
      onPressed: onPressed,
    );
  }
}

/// Opens the composer over the screen, on [cubit] and [voice].
Future<void> showComposer(
  BuildContext context, {
  required ComposeCubit cubit,
  required VoiceCubit voice,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider<ComposeCubit>.value(value: cubit),
        BlocProvider<VoiceCubit>.value(value: voice),
      ],
      child: const ComposerSheet(),
    ),
  );
}

/// {@template composer_sheet}
/// One field, typed or spoken, and over it the summary of what it was read
/// as.
///
/// The microphone records in place (the words rise in the field) and its
/// stop sends; the arrow sends what was typed. Sent, a small box comes up
/// above the sheet: "Entendendo…" for the second it takes, then what will
/// be written (kind, hour, length, the task it goes under, its subtasks),
/// with Adicionar. The field stays as it was, so changing a word and
/// sending again reads it again.
/// {@endtemplate}
class ComposerSheet extends StatefulWidget {
  /// {@macro composer_sheet}
  const ComposerSheet({this.onAdd, this.onAdjust, this.onTalk, super.key});

  /// Writes the summary down.
  final void Function(ComposeDraft draft)? onAdd;

  /// Opens the details of the summary, to change one by hand.
  final void Function(ComposeDraft draft)? onAdjust;

  /// Opens the conversation about a plan.
  final void Function(ComposeDraft draft)? onTalk;

  @override
  State<ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<ComposerSheet> {
  late final _field = TextEditingController(
    text: context.read<ComposeCubit>().state.text,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compose = context.watch<ComposeCubit>().state;
    final voice = context.watch<VoiceCubit>().state;
    final recording = voice.status.recording;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compose.status != ComposeStatus.editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s3,
                    0,
                    AppSpacing.s3,
                    AppSpacing.s2,
                  ),
                  child: ComposeSummary(
                    state: compose,
                    onAdd: widget.onAdd,
                    onAdjust: widget.onAdjust,
                    onTalk: widget.onTalk,
                  ),
                ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.cardRadius),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s5,
                      AppSpacing.s3,
                      AppSpacing.s3,
                      AppSpacing.s3,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.fillStrong,
                              borderRadius: BorderRadius.all(
                                Radius.circular(AppSpacing.pillRadius),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.s2,
                            ),
                            child: recording
                                ? VoiceTranscript(voice: voice)
                                : TextField(
                                    controller: _field,
                                    autofocus: true,
                                    minLines: 1,
                                    maxLines: 5,
                                    style: AppTypography.body,
                                    onChanged: context
                                        .read<ComposeCubit>()
                                        .edit,
                                    decoration: InputDecoration.collapsed(
                                      hintText: l10n.composeHint,
                                      hintStyle: AppTypography.body.copyWith(
                                        color: AppColors.ink3,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        if (recording)
                          VoiceBar(
                            voice: voice,
                            stopIcon: AppIcons.arrowUp,
                            stopLabel: l10n.composeSend,
                            onStop: () => unawaited(_sendVoice()),
                            onDiscard: () => unawaited(
                              context.read<VoiceCubit>().cancel(),
                            ),
                          )
                        else
                          Row(
                            children: [
                              VoiceRound(
                                label: l10n.composeListen,
                                icon: AppIcons.microphone,
                                fill: AppColors.fill,
                                ink: AppColors.ink,
                                size: 40,
                                onTap: () => unawaited(
                                  context.read<VoiceCubit>().start(),
                                ),
                              ),
                              const Spacer(),
                              VoiceRound(
                                label: l10n.composeSend,
                                icon: AppIcons.arrowUp,
                                fill: compose.text.trim().isEmpty
                                    ? AppColors.fillStrong
                                    : AppColors.accent,
                                ink: compose.text.trim().isEmpty
                                    ? AppColors.ink3
                                    : AppColors.onAccent,
                                size: 40,
                                onTap: () => unawaited(
                                  context.read<ComposeCubit>().send(),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ends the recording, puts the words in the field and sends them.
  Future<void> _sendVoice() async {
    final compose = context.read<ComposeCubit>();
    final take = await context.read<VoiceCubit>().take();
    if (take == null || !mounted) return;
    _field.text = take.text;
    compose.edit(take.text);
    await compose.send();
  }
}

/// {@template compose_summary}
/// The small box over the composer: what will be written down.
///
/// One line says what it is (the kind, the day and hour or "na fila", the
/// length); the task it goes under is a tag; its subtasks are listed under
/// it. A plan lists its changes and offers the conversation instead of the
/// details. One button writes it all.
/// {@endtemplate}
class ComposeSummary extends StatelessWidget {
  /// {@macro compose_summary}
  const ComposeSummary({
    required this.state,
    this.onAdd,
    this.onAdjust,
    this.onTalk,
    super.key,
  });

  final ComposeState state;
  final void Function(ComposeDraft draft)? onAdd;
  final void Function(ComposeDraft draft)? onAdjust;
  final void Function(ComposeDraft draft)? onTalk;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.cardRadius)),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 24)],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.bottomCenter,
        child: draft == null || state.status == ComposeStatus.reading
            ? const _Reading()
            : _Read(
                draft: draft,
                onAdd: onAdd,
                onAdjust: onAdjust,
                onTalk: onTalk,
              ),
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Text(
          context.l10n.composeReading,
          style: AppTypography.label.copyWith(color: AppColors.ink2),
        ),
      ],
    );
  }
}

class _Read extends StatelessWidget {
  const _Read({
    required this.draft,
    this.onAdd,
    this.onAdjust,
    this.onTalk,
  });

  final ComposeDraft draft;
  final void Function(ComposeDraft draft)? onAdd;
  final void Function(ComposeDraft draft)? onAdjust;
  final void Function(ComposeDraft draft)? onTalk;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = draft.kind == ComposeKind.plan;
    final parent = draft.parent;
    final lines = plan ? draft.changes : draft.subtasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KindMark(kind: draft.kind),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _meta(l10n, draft),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (parent != null) ...[
          const SizedBox(height: AppSpacing.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 44),
              child: AppTag(text: l10n.composeIn(parent)),
            ),
          ),
        ],
        if (lines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s3),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!plan)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s1),
                    child: Text(
                      l10n.composeSubtasks(lines.length),
                      style: AppTypography.caption,
                    ),
                  ),
                for (final line in lines) _Line(text: line, plan: plan),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s3),
        Row(
          children: [
            AppButton.text(
              text: plan ? l10n.composeTalk : l10n.composeAdjust,
              onPressed: () => (plan ? onTalk : onAdjust)?.call(draft),
            ),
            const Spacer(),
            AppButton.icon(
              icon: const AppIcon(
                iconData: AppIcons.check,
                size: 18,
                color: AppColors.onAccent,
              ),
              text: plan ? l10n.composeApply : l10n.composeAdd,
              onPressed: () => onAdd?.call(draft),
            ),
          ],
        ),
      ],
    );
  }

  /// "Evento · amanhã, 15:00 · 1h", "Tarefa · na fila · 2h".
  static String _meta(AppLocalizations l10n, ComposeDraft draft) {
    final kind = switch (draft.kind) {
      ComposeKind.task => l10n.composeKindTask,
      ComposeKind.event => l10n.composeKindEvent,
      ComposeKind.plan => l10n.composeKindPlan,
    };
    final start = draft.start;
    final minutes = draft.minutes;
    return [
      kind,
      if (start != null)
        l10n.composeAt(_day(l10n, start), _hour(start))
      else if (draft.kind == ComposeKind.task)
        l10n.composeQueued,
      if (minutes != null) _length(minutes),
    ].join(' · ');
  }

  static String _day(AppLocalizations l10n, DateTime start) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    return switch (day.difference(today).inDays) {
      0 => l10n.composeToday,
      1 => l10n.composeTomorrow,
      _ => '${day.day}/${day.month}',
    };
  }

  static String _hour(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  static String _length(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest min';
    if (rest == 0) return '${hours}h';
    return '${hours}h${rest.toString().padLeft(2, '0')}';
  }
}

/// The kind as a mark: a check for a task, the pin fixed cards carry for an
/// event, the agent's crescent for a plan.
class _KindMark extends StatelessWidget {
  const _KindMark({required this.kind});

  final ComposeKind kind;

  @override
  Widget build(BuildContext context) {
    final (fill, icon, ink) = switch (kind) {
      ComposeKind.task => (AppColors.fill, AppIcons.check, AppColors.ink),
      ComposeKind.event => (
        AppColors.fixedFill,
        AppIcons.pin,
        AppColors.fixedInk,
      ),
      ComposeKind.plan => (AppColors.accentWash, AppIcons.agent, null),
    };
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Center(child: AppIcon(iconData: icon, size: 16, color: ink)),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.plan});

  final String text;
  final bool plan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: plan ? AppColors.accent : AppColors.ink3,
                shape: plan ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: plan
                    ? null
                    : const BorderRadius.all(Radius.circular(1.5)),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(child: Text(text, style: AppTypography.label)),
        ],
      ),
    );
  }
}
