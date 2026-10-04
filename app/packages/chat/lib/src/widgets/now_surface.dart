import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';

/// {@template now_surface}
/// The surface of whatever is happening now.
///
/// A faint wash of light that goes once around the card every minute, gathered
/// at the border and barely there across the middle. It is slow on purpose:
/// it should read as the card being alive, not as something asking to be
/// looked at.
///
/// A paused block gets none of it. It is the same card on the plain fill with
/// a hairline round it, which is what makes the running one look running.
/// {@endtemplate}
class NowSurface extends StatefulWidget {
  /// {@macro now_surface}
  const NowSurface({
    required this.child,
    this.paused = false,
    this.pressed = false,
    this.radius = AppSpacing.chipRadius,
    super.key,
  });

  /// What is drawn on it.
  final Widget child;

  /// Whether the block is paused, which turns the light off.
  final bool paused;

  /// Whether a finger is on it.
  final bool pressed;

  /// The corner radius.
  final double radius;

  @override
  State<NowSurface> createState() => _NowSurfaceState();
}

class _NowSurfaceState extends State<NowSurface>
    with SingleTickerProviderStateMixin {
  /// Once round the card.
  static const _cycle = Duration(minutes: 1);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(NowSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) _sync();
  }

  void _sync() {
    if (widget.paused) {
      _controller.stop();
    } else {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GlowPainter(
        turn: _controller,
        paused: widget.paused,
        pressed: widget.pressed,
        radius: widget.radius,
        tint: AppDay.colorAt(DateTime.now()),
      ),
      child: widget.child,
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.turn,
    required this.paused,
    required this.pressed,
    required this.radius,
    required this.tint,
  }) : super(repaint: turn);

  final Animation<double> turn;
  final bool paused;
  final bool pressed;
  final double radius;

  /// The hour's own colour, from the clock at the top of the screen, so the
  /// light on the card is the light of the day it is in.
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.drawRRect(
      rrect,
      Paint()..color = pressed ? AppColors.fillStrong : AppColors.fill,
    );

    if (paused) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.line,
      );
      return;
    }

    Shader sweep(double strength) => SweepGradient(
      colors: [
        AppColors.accent.withValues(alpha: strength),
        tint.withValues(alpha: strength * 0.2),
        tint.withValues(alpha: strength * 0.8),
        AppColors.accent.withValues(alpha: strength * 0.15),
        AppColors.accent.withValues(alpha: strength),
      ],
      stops: const [0, 0.25, 0.5, 0.75, 1],
      transform: GradientRotation(turn.value * 2 * math.pi),
    ).createShader(rect);

    // Across the whole card, barely, as a linear wash that turns with the
    // border light. A sweep here would draw its rays meeting in the middle.
    final wash = LinearGradient(
      colors: [
        AppColors.accent.withValues(alpha: 0.06),
        tint.withValues(alpha: 0.015),
        tint.withValues(alpha: 0.05),
      ],
      transform: GradientRotation(turn.value * 2 * math.pi),
    ).createShader(rect);

    // Then gathered at the edge and bled inwards, so the light sits on the
    // border rather than on the text.
    canvas
      ..drawRRect(rrect, Paint()..shader = wash)
      ..save()
      ..clipRRect(rrect)
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppSpacing.s3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, AppSpacing.s2)
          ..shader = sweep(0.22),
      )
      ..restore()
      ..drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = sweep(0.35),
      );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.paused != paused ||
      oldDelegate.pressed != pressed ||
      oldDelegate.tint != tint;
}

/// {@template now_progress}
/// How far along the work is, and what is left of it, kept live.
///
/// Every few seconds rather than every frame: the bar on a thirty minute
/// block moves a pixel every several seconds anyway. A paused block stands
/// still, because paused time is not work, and a block waiting to be begun
/// reads as one paused before its first minute.
/// {@endtemplate}
class NowProgress extends StatefulWidget {
  /// {@macro now_progress}
  const NowProgress({required this.card, this.trailing, super.key});

  /// The running block.
  final TimelineEvent card;

  /// Drawn at the end of the status line, which is where the buttons go.
  final Widget? trailing;

  @override
  State<NowProgress> createState() => _NowProgressState();
}

class _NowProgressState extends State<NowProgress> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_stopped) setState(() {});
    });
  }

  /// Whether nothing is being worked on: paused, or not begun yet.
  bool get _stopped => widget.card.isPaused || widget.card.awaitingStart;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final stopped = _stopped;
    // The server slides a waiting block to the current minute, so its start
    // is always a moment ago. None of that is work.
    final progress = card.awaitingStart ? 0.0 : card.progressAt(DateTime.now());
    final left = (card.workMinutes * (1 - progress)).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stopped
                    ? 'Pausado · faltam ${_minutes(left)}'
                    : 'Faltam ${_minutes(left)}',
                style: AppTypography.label.copyWith(
                  color: stopped ? AppColors.ink3 : AppColors.ink2,
                ),
              ),
            ),
            ?widget.trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: AppColors.line,
            color: stopped ? AppColors.ink3 : AppColors.accent,
          ),
        ),
      ],
    );
  }

  static String _minutes(int minutes) {
    if (minutes < 60) return '$minutes min';

    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h$rest';
  }
}
