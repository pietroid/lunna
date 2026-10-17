import 'dart:async';
import 'dart:math' as math;

import 'package:agent/src/view/agent_sheet.dart';
import 'package:agent/src/view/voice_bar.dart';
import 'package:agent/src/voice/voice_cubit.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// {@template ask_dock}
/// The agent's bar and the +, side by side and centred, at the foot of
/// Tempo.
///
/// The + writes something down in one tap; the bar beside it is where a
/// conversation starts. Its microphone records right here: the bar opens
/// across the + into the recorder, with the words rising above it as they
/// are heard. Stopping (the stop button, or letting go of a held
/// microphone) opens the conversation with them in the field, selected;
/// the words themselves open it while still recording, and the recording
/// carries on there.
/// {@endtemplate}
class AskDock extends StatefulWidget {
  /// {@macro ask_dock}
  const AskDock({required this.fab, this.day, super.key});

  /// The + beside the bar.
  final Widget fab;

  /// The day Tempo is showing, which the conversation is about.
  final DateTime? Function()? day;

  @override
  State<AskDock> createState() => _AskDockState();
}

class _AskDockState extends State<AskDock> {
  static const _duration = Duration(milliseconds: 220);

  late final _hold = VoiceHold(onRelease: () => unawaited(_stop()));

  Future<void> _open({String? draft}) =>
      showAgentSheet(context, day: widget.day?.call(), draft: draft);

  /// Starts recording here; a microphone that is refused or missing opens
  /// the conversation instead, whose composer says why.
  Future<void> _listen() async {
    _hold.press();
    final voice = context.read<VoiceCubit>();
    await voice.start();
    if (!mounted || voice.state.status.offered) return;
    await _open();
  }

  Future<void> _stop() async {
    final voice = context.read<VoiceCubit>();
    // Still asking for the microphone (the first time, a dialog took the
    // finger): the recording goes on as if tapped.
    if (voice.state.status == VoiceStatus.preparing) return;
    final take = await voice.take();
    if (take == null || !mounted) return;
    await _open(draft: take.text);
  }

  @override
  Widget build(BuildContext context) {
    final width =
        math.min(MediaQuery.sizeOf(context).width, AppSpacing.maxContentWidth) -
        2 * kFloatingActionButtonMargin;
    final voice = context.watch<VoiceCubit>().state;
    final recording = voice.status.recording;

    return Listener(
      // Wherever the finger is let go, the microphone it held is gone.
      onPointerUp: (_) => _hold.release(),
      onPointerCancel: (_) => _hold.release(),
      child: SizedBox(
        width: width,
        child: AnimatedSize(
          duration: _duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: _duration,
            switchInCurve: Curves.easeOutCubic,
            child: recording
                ? Column(
                    key: const ValueKey('recording'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Heard(voice: voice, onOpen: () => unawaited(_open())),
                      const SizedBox(height: AppSpacing.s2),
                      _Pill(
                        child: VoiceBar(
                          voice: voice,
                          onStop: () => unawaited(_stop()),
                          onDiscard: () =>
                              unawaited(context.read<VoiceCubit>().cancel()),
                        ),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('resting'),
                    children: [
                      Expanded(
                        child: AskBar(
                          onOpen: () => unawaited(_open()),
                          onListen: () => unawaited(_listen()),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      widget.fab,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// {@template ask_bar}
/// Where a conversation with the agent starts: a pill beside the +.
///
/// It only looks like a field. Tapping it opens the sheet on the real field,
/// keyboard up, so the keyboard never comes up over the day. The microphone
/// at its end is a target of its own: it starts recording as a finger lands
/// on it, to be stopped by a tap on stop or, held, by letting go.
/// {@endtemplate}
class AskBar extends StatelessWidget {
  /// {@macro ask_bar}
  const AskBar({required this.onOpen, required this.onListen, super.key});

  /// Opens the conversation.
  final VoidCallback onOpen;

  /// Starts recording.
  final VoidCallback onListen;

  /// As tall as the +, so the two read as one row.
  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.agentAsk(AppBrand.id),
      child: GestureDetector(
        onTap: onOpen,
        child: _Pill(
          padding: const EdgeInsets.only(
            left: AppSpacing.s4,
            right: AppSpacing.s2,
          ),
          child: Row(
            children: [
              const AppIcon(iconData: AppIcons.agent, size: 22),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  context.l10n.agentAsk(AppBrand.id),
                  style: AppTypography.body.copyWith(color: AppColors.ink3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              VoiceRound(
                label: context.l10n.agentVoiceStart,
                icon: AppIcons.microphone,
                fill: AppColors.accentWash,
                ink: AppColors.accent,
                size: 40,
                onPress: onListen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The surface the bar and the recorder are drawn on.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AskBar.height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 28,
            offset: Offset(0, 8),
            spreadRadius: -10,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The words of a recording on Tempo, over the recorder; a tap takes them,
/// still recording, into the conversation.
class _Heard extends StatelessWidget {
  const _Heard({required this.voice, required this.onOpen});

  final VoiceState voice;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.agentVoiceOpen,
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s3,
            AppSpacing.s3,
            AppSpacing.s4,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 28,
                offset: Offset(0, 8),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppIcon(iconData: AppIcons.agent, size: 18),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      voice.status == VoiceStatus.stopped
                          ? context.l10n.agentVoiceStopped
                          : context.l10n.agentVoiceListening,
                      style: AppTypography.label.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Up, into the conversation.
                  const AppIcon(
                    iconData: AppIcons.earlier,
                    size: 18,
                    color: AppColors.ink3,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              VoiceTranscript(voice: voice),
            ],
          ),
        ),
      ),
    );
  }
}
