import 'dart:async';

import 'package:agent/src/voice/voice_cubit.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';

/// {@template voice_hold}
/// Hold to talk, beside tap to talk.
///
/// The microphone starts recording as soon as a finger lands on it
/// ([press]). Let go at once and it was a tap: the recording carries on
/// until it is sent. Still down after [hold], it is held ([held], and
/// [onHeld] to redraw), and letting go ([release]) sends it.
///
/// The microphone is swapped for the recorder while the finger is still
/// down, so the release is caught above both, by whatever draws them.
/// {@endtemplate}
class VoiceHold {
  /// {@macro voice_hold}
  VoiceHold({required this.onRelease, this.onHeld});

  /// What letting go after a hold does: send, as the send button would.
  final VoidCallback onRelease;

  /// Called once a press has lasted long enough to be a hold.
  final VoidCallback? onHeld;

  /// How long a press must last to be a hold rather than a tap.
  static const hold = Duration(milliseconds: 400);

  DateTime? _pressedAt;
  Timer? _timer;
  bool _held = false;

  /// Whether a finger is holding the microphone down.
  bool get held => _held;

  /// A finger landed on the microphone.
  void press() {
    _pressedAt = clock.now();
    _timer?.cancel();
    _timer = Timer(hold, () {
      if (_pressedAt == null) return;
      _held = true;
      onHeld?.call();
    });
  }

  /// Forgets the finger without sending: the recording was dropped, or
  /// locked to go on without it.
  void abandon() {
    _pressedAt = null;
    _timer?.cancel();
    _held = false;
  }

  /// A finger left the screen, wherever it was.
  void release() {
    final pressedAt = _pressedAt;
    _pressedAt = null;
    _timer?.cancel();
    final wasHeld = _held;
    _held = false;
    if (pressedAt != null &&
        (wasHeld || clock.now().difference(pressedAt) >= hold)) {
      onRelease();
      onHeld?.call();
    }
  }
}

/// {@template voice_bar}
/// A recording, in the shape of the field it replaces: the way out, the
/// time, the microphone's level as it comes, and the way to stop.
///
/// The same row on Tempo's bar and in the conversation's composer, so a
/// recording started on one carries on unchanged in the other. Stopping
/// keeps the words for the field; discarding drops them.
/// {@endtemplate}
class VoiceBar extends StatelessWidget {
  /// {@macro voice_bar}
  const VoiceBar({
    required this.voice,
    required this.onDiscard,
    this.onStop,
    this.stopLabel,
    this.stopIcon,
    this.discardLabel,
    super.key,
  });

  final VoiceState voice;

  /// Stops and keeps the words; null leaves the button out, for a bar whose
  /// way out is beside it (the agent's send, where the + was).
  final VoidCallback? onStop;
  final VoidCallback onDiscard;

  /// What the two buttons say to a screen reader, when not the composer's.
  final String? stopLabel;
  final String? discardLabel;

  /// The stop button's icon, when stopping does more than stop (the
  /// agent's sends).
  final AppIconData? stopIcon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final live = voice.status != VoiceStatus.stopped;

    return Row(
      children: [
        VoiceRound(
          label: discardLabel ?? l10n.agentVoiceDiscard,
          icon: AppIcons.trash,
          fill: Colors.transparent,
          ink: AppColors.ink2,
          onTap: onDiscard,
        ),
        const SizedBox(width: AppSpacing.s1),
        VoiceDot(live: live),
        const SizedBox(width: AppSpacing.s2),
        Text(
          _clock(voice.elapsed),
          style: AppTypography.label.copyWith(
            color: AppColors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: VoiceWave(levels: voice.levels, quiet: !live),
        ),
        const SizedBox(width: AppSpacing.s3),
        if (onStop != null)
          VoiceRound(
            label: stopLabel ?? l10n.agentVoiceStop,
            icon: stopIcon ?? AppIcons.stop,
            fill: AppColors.accent,
            ink: AppColors.onAccent,
            size: 40,
            onTap: onStop,
          ),
      ],
    );
  }

  static String _clock(Duration elapsed) {
    final seconds = elapsed.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// {@template voice_transcript}
/// The words as they are heard: what is settled in ink, what the
/// recognizer may still revise in ink3, and a caret while it listens.
/// Before anything is heard, an invitation to speak.
/// {@endtemplate}
class VoiceTranscript extends StatelessWidget {
  /// {@macro voice_transcript}
  const VoiceTranscript({required this.voice, this.maxLines = 4, super.key});

  final VoiceState voice;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (voice.text.isEmpty) {
      return Text(
        context.l10n.agentVoiceHint,
        style: AppTypography.body.copyWith(color: AppColors.ink3),
      );
    }

    return Text.rich(
      TextSpan(
        style: AppTypography.body,
        children: [
          TextSpan(text: voice.heard),
          if (voice.heard.isNotEmpty && voice.hearing.isNotEmpty)
            const TextSpan(text: ' '),
          TextSpan(
            text: voice.hearing,
            style: const TextStyle(color: AppColors.ink3),
          ),
          if (voice.status == VoiceStatus.listening)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _Caret(),
            ),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.fade,
    );
  }
}

/// A round button of the composer and the recorder.
class VoiceRound extends StatelessWidget {
  /// Creates a round button.
  const VoiceRound({
    required this.label,
    required this.icon,
    required this.fill,
    required this.ink,
    this.onTap,
    this.onPress,
    this.size = 36,
    super.key,
  });

  final String label;
  final AppIconData icon;
  final Color fill;
  final Color ink;
  final VoidCallback? onTap;

  /// Called as soon as a finger lands, before it is known to be a tap or a
  /// hold (see [VoiceHold]).
  final VoidCallback? onPress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final onPress = this.onPress;

    return Semantics(
      button: true,
      label: label,
      child: Listener(
        onPointerDown: onPress == null ? null : (_) => onPress(),
        child: GestureDetector(
          // A press is answered as the finger lands; the tap is claimed all
          // the same, so it never reaches what the button sits on.
          onTap: onTap ?? (onPress == null ? null : () {}),
          child: _round(),
        ),
      ),
    );
  }

  Widget _round() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Center(
        child: AppIcon(iconData: icon, size: size * 0.45, color: ink),
      ),
    );
  }
}

/// The microphone's last levels as bars, newest on the right, centred on a
/// line the way a voice message is drawn; a quiet one is drawn grey, so a
/// pause shows as a run of grey.
class VoiceWave extends StatelessWidget {
  /// Creates a wave.
  const VoiceWave({required this.levels, this.quiet = false, super.key});

  final List<double> levels;

  /// Whether the microphone is off, which greys the whole wave.
  final bool quiet;

  static const _height = 28.0;

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 3,
      height: level == null ? 3 : 3 + (level.clamp(0, 1) * (_height - 3)),
      decoration: BoxDecoration(
        color: loud ? AppColors.accent : AppColors.ink3.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// The red dot of a live recording, breathing; grey once it has stopped.
class VoiceDot extends StatefulWidget {
  /// Creates the dot.
  const VoiceDot({required this.live, super.key});

  final bool live;

  @override
  State<VoiceDot> createState() => _VoiceDotState();
}

class _VoiceDotState extends State<VoiceDot>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.35,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.live ? _breath : const AlwaysStoppedAnimation(1),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.live ? AppColors.accent : AppColors.ink3,
          shape: BoxShape.circle,
        ),
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
