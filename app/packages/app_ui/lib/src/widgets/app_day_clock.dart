import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// {@template app_day_clock}
/// The time, inside a ring that fills as the day does.
///
/// The ring runs from [AppDay.startHour] to [AppDay.endHour] clockwise from
/// twelve o'clock, painted in the light of the hour it passes through. What is
/// left of the day stays as a faint track, so a glance says how much of it is
/// gone without reading the number in the middle.
/// {@endtemplate}
class AppDayClock extends StatelessWidget {
  /// {@macro app_day_clock}
  const AppDayClock({this.diameter = 80, this.strokeWidth = 1.5, super.key});

  /// The outer size of the ring.
  final double diameter;

  /// How thick the ring is drawn.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return AppMinuteBuilder(
      builder: (context, now) {
        return SizedBox.square(
          dimension: diameter,
          child: CustomPaint(
            painter: _RingPainter(
              progress: AppDay.progressAt(now),
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Text(
                _hhmm(now),
                style: AppTypography.onest(
                  size: diameter * 0.25,
                  weight: FontWeight.w300,
                  height: 1,
                  tracking: -0.02,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _hhmm(DateTime at) {
    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.strokeWidth});

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final circle = Rect.fromCircle(center: rect.center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppDay.unfilled;

    canvas.drawCircle(rect.center, radius, track);

    if (progress <= 0) return;

    // The sweep starts at twelve o'clock. A sweep gradient always starts at
    // three, so the shader is rotated back a quarter turn rather than the
    // canvas, which would take the arc with it.
    final shader = SweepGradient(
      colors: AppDay.ramp(upTo: progress),
      endAngle: math.pi * 2 * progress,
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(circle);

    final day = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = shader;

    canvas.drawArc(circle, -math.pi / 2, math.pi * 2 * progress, false, day);
  }

  @override
  bool shouldRepaint(_RingPainter old) {
    return old.progress != progress || old.strokeWidth != strokeWidth;
  }
}
