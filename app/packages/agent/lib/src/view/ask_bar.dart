import 'dart:async';
import 'dart:math' as math;

import 'package:agent/src/agent_cubit.dart';
import 'package:agent/src/models.dart';
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
/// conversation starts. Its microphone records right here, the way a voice
/// message is recorded in WhatsApp, and the bar never moves or changes size
/// while it does: what changes is drawn inside it.
///
/// - **Held**, the microphone swells under the finger, the bar says how long
///   it has been and "deslize para cancelar", a lock waits above, and the
///   words rise over it as they are heard. Letting go **sends** them: the
///   conversation opens with them already said. Sliding left drops them;
///   sliding up to the lock keeps recording without the finger.
/// - **Tapped** (or locked), the bar is the recorder, and the + beside it
///   becomes the send button. The words above it open the conversation with
///   them in the field, for whoever wants to change them before sending.
/// {@endtemplate}
class AskDock extends StatefulWidget {
  /// {@macro ask_dock}
  const AskDock({required this.fab, this.day, this.about, super.key});

  /// The + beside the bar.
  final Widget fab;

  /// The day Tempo is showing, which the conversation is about.
  final DateTime? Function()? day;

  /// The page the dock is on, when not Tempo: the task or the artifact the
  /// conversation is about.
  final AgentSubject? about;

  @override
  State<AskDock> createState() => _AskDockState();
}

class _AskDockState extends State<AskDock> {
  late final _hold = VoiceHold(
    onHeld: () => setState(() {}),
    onRelease: () => unawaited(_send()),
  );

  /// How far left a held finger slides to drop the recording.
  static const cancelAt = 100.0;

  /// How far up a held finger slides to lock the recording on.
  static const lockAt = 80.0;

  /// Where the finger landed, and how far it has slid since.
  Offset? _down;
  Offset _slide = Offset.zero;

  void _move(PointerMoveEvent event) {
    final down = _down;
    if (down == null || !_hold.held) return;
    final slide = event.position - down;
    if (slide.dx <= -cancelAt) {
      _letGo();
      unawaited(context.read<VoiceCubit>().cancel());
    } else if (slide.dy <= -lockAt) {
      // Locked: the recording goes on as if the microphone had been tapped.
      _letGo();
    } else {
      setState(() => _slide = slide);
    }
  }

  void _letGo() {
    _hold.abandon();
    setState(() {
      _down = null;
      _slide = Offset.zero;
    });
  }

  Future<void> _open({String? draft}) => showAgentSheet(
    context,
    day: widget.day?.call(),
    draft: draft,
    about: widget.about,
  );

  /// Starts recording here; a microphone that is refused or missing opens
  /// the conversation instead, whose composer says why.
  Future<void> _listen() async {
    _hold.press();
    final voice = context.read<VoiceCubit>();
    await voice.start();
    if (!mounted || voice.state.status.offered) return;
    await _open();
  }

  /// Ends the recording and says what was heard: the conversation opens on
  /// it, already sent.
  Future<void> _send() async {
    final voice = context.read<VoiceCubit>();
    final agent = context.read<AgentCubit>();
    // Still asking for the microphone (the first time, a dialog took the
    // finger): the recording goes on as if tapped.
    if (voice.state.status == VoiceStatus.preparing) return;
    final take = await voice.take();
    if (take == null || !mounted) return;
    final sheet = _open();
    unawaited(
      agent.send(take.text, day: widget.day?.call(), voice: take.length),
    );
    await sheet;
  }

  /// Ends the recording and opens the conversation with its words in the
  /// field, to be changed before they are sent.
  Future<void> _review() async {
    final take = await context.read<VoiceCubit>().take();
    if (!mounted) return;
    await _open(draft: take?.text);
  }

  void _release() {
    _down = null;
    _slide = Offset.zero;
    _hold.release();
  }

  @override
  Widget build(BuildContext context) {
    final width =
        math.min(MediaQuery.sizeOf(context).width, AppSpacing.maxContentWidth) -
        2 * kFloatingActionButtonMargin;
    final voice = context.watch<VoiceCubit>().state;

    return Listener(
      onPointerDown: (event) => _down = event.position,
      onPointerMove: _move,
      // Wherever the finger is let go, the microphone it held is gone.
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: SizedBox(
        width: width,
        child: voice.status.recording
            ? AskRecorder(
                voice: voice,
                held: _hold.held,
                slide: _slide,
                onSend: () => unawaited(_send()),
                onDiscard: () => unawaited(context.read<VoiceCubit>().cancel()),
                onReview: () => unawaited(_review()),
              )
            : Row(
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
    );
  }
}

/// {@template ask_recorder}
/// The dock while it records: the same bar in the same place, and the +
/// beside it, whatever the recording asks of them.
///
/// [held] draws a finger still on the microphone: the microphone swollen
/// under it, the lock above, the hint to slide away. Otherwise the bar is
/// the recorder (the way out, the time, the level) and the + is send.
/// {@endtemplate}
class AskRecorder extends StatelessWidget {
  /// {@macro ask_recorder}
  const AskRecorder({
    required this.voice,
    required this.held,
    required this.onSend,
    required this.onDiscard,
    required this.onReview,
    this.slide = Offset.zero,
    super.key,
  });

  final VoiceState voice;

  /// Whether a finger is holding the microphone down.
  final bool held;

  /// How far the held finger has slid from where it landed: the microphone
  /// follows it, left towards cancelling or up towards the lock.
  final Offset slide;

  final VoidCallback onSend;
  final VoidCallback onDiscard;

  /// Opens the conversation with the words in the field, unsent.
  final VoidCallback onReview;

  /// How big the microphone swells under the finger.
  static const _swollen = 72.0;

  /// Where the bar's own microphone sits, from the dock's right edge: past
  /// the +, its gap, and the bar's inner padding.
  static const double _micFromRight = 56 + AppSpacing.s3 + AppSpacing.s2 + 20;

  /// The slide left, and the slide up, whichever leads; the other is held.
  double get _dx =>
      slide.dx.abs() >= -slide.dy ? slide.dx.clamp(-100.0, 0.0) : 0;
  double get _dy =>
      -slide.dy > slide.dx.abs() ? -slide.dy.clamp(-80.0, 0.0) : 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // One surface, as wide as the bar and the + together: the words
        // above, the recorder under them. Nothing else floats over the day,
        // and nothing is kept invisible to hold its room.
        Container(
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                // Held, the lock has the column over the microphone.
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s3,
                  held ? _micFromRight + 20 + AppSpacing.s2 : AppSpacing.s3,
                  0,
                ),
                child: _Heard(voice: voice, onOpen: held ? null : onReview),
              ),
              // The recorder sits where the bar sat, at the bar's height,
              // so the finger on the microphone is still on it.
              SizedBox(
                height: AskBar.height,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.s2, right: 4),
                  child: held
                      ? _HeldRow(voice: voice, slide: slide.dx)
                      : Row(
                          children: [
                            Expanded(
                              child: VoiceBar(
                                voice: voice,
                                onDiscard: onDiscard,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s3),
                            // Send has the +'s place, centre on centre.
                            AppFab(
                              iconData: AppIcons.arrowUp,
                              tooltip: l10n.agentVoiceSend,
                              diameter: 48,
                              onPressed: onSend,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        if (held) ...[
          // The lock, a slide up away.
          const Positioned(
            right: _micFromRight - 20,
            bottom: AskBar.height + AppSpacing.s3,
            child: _Lock(),
          ),
          // The microphone under the finger, following it one way at a time.
          Positioned(
            right: _micFromRight - _swollen / 2 - _dx,
            bottom: (AskBar.height - _swollen) / 2 + _dy,
            child: Container(
              width: _swollen,
              height: _swollen,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: const Center(
                child: AppIcon(
                  iconData: AppIcons.microphone,
                  size: 30,
                  color: AppColors.onAccent,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The bar while the microphone is held: the dot and the time on the left,
/// and the way out, a slide to the left.
class _HeldRow extends StatelessWidget {
  const _HeldRow({required this.voice, this.slide = 0});

  final VoiceState voice;

  /// How far left the finger has slid, which the hint follows and fades on.
  final double slide;

  @override
  Widget build(BuildContext context) {
    final seconds = voice.elapsed.inSeconds;

    return Row(
      children: [
        const SizedBox(width: AppSpacing.s3),
        const VoiceDot(live: true),
        const SizedBox(width: AppSpacing.s2),
        Text(
          '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
          style: AppTypography.label.copyWith(
            color: AppColors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Expanded(
          child: Opacity(
            opacity: (1 + slide / 100).clamp(0, 1),
            child: Transform.translate(
              offset: Offset(slide.clamp(-100, 0), 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppIcon(
                    iconData: AppIcons.back,
                    size: 14,
                    color: AppColors.ink3,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      context.l10n.agentVoiceSlideCancel,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Room for the microphone swollen under the finger, and the + spot
        // past it, which stays empty while the finger is down.
        const SizedBox(
          width: AskRecorder._micFromRight + AskRecorder._swollen / 2 - 4,
        ),
      ],
    );
  }
}

/// The lock over the held microphone: slid up to, the recording goes on
/// without the finger.
class _Lock extends StatelessWidget {
  const _Lock();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.agentVoiceLock,
      child: Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 20,
              offset: Offset(0, 6),
              spreadRadius: -8,
            ),
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(iconData: AppIcons.lock, size: 18, color: AppColors.ink2),
            SizedBox(height: AppSpacing.s1),
            AppIcon(
              iconData: AppIcons.earlier,
              size: 14,
              color: AppColors.ink3,
            ),
          ],
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
        child: AskPill(
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
class AskPill extends StatelessWidget {
  /// Creates the pill.
  const AskPill({
    required this.child,
    super.key,
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

/// The words of a recording on Tempo, at the top of the recorder's panel;
/// a tap takes them, still recording, into the conversation. Null [onOpen]
/// while a finger holds the microphone, when the words only show.
class _Heard extends StatelessWidget {
  const _Heard({required this.voice, this.onOpen});

  final VoiceState voice;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final onOpen = this.onOpen;
    final words = Column(
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
            if (onOpen != null)
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
    );
    if (onOpen == null) return words;

    return Semantics(
      button: true,
      label: context.l10n.agentVoiceOpen,
      child: GestureDetector(
        onTap: onOpen,
        behavior: HitTestBehavior.opaque,
        child: words,
      ),
    );
  }
}
