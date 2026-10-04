import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// {@template app_typing_indicator}
/// Three dots that rise in turn while the agent is writing.
///
/// It replaced a skeleton of grey bars. A skeleton promises a shape, and the
/// agent's answer has no fixed one: it might be a sentence or a card with three
/// options, so the bars were always a lie that then jumped when the real reply
/// landed. Dots promise only that something is coming, which is all that is
/// actually known.
/// {@endtemplate}
class AppTypingIndicator extends StatefulWidget {
  /// {@macro app_typing_indicator}
  const AppTypingIndicator({this.color = AppColors.ink3, super.key});

  /// The dots' colour at rest.
  final Color color;

  @override
  State<AppTypingIndicator> createState() => _AppTypingIndicatorState();
}

class _AppTypingIndicatorState extends State<AppTypingIndicator>
    with SingleTickerProviderStateMixin {
  static const _dots = 3;
  static const _travel = 3.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.s5,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _dots; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.s1),
                _Dot(phase: _phase(i), color: widget.color),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Where dot [index] is in its rise, staggered a third of a cycle apart.
  ///
  /// The result is a wave rather than a pulse: the three dots are never at the
  /// same height, which is what makes it read as typing instead of loading.
  double _phase(int index) {
    final offset = index / _dots;
    final value = (_controller.value - offset) % 1.0;
    return math.sin(value * math.pi).clamp(0.0, 1.0);
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -_AppTypingIndicatorState._travel * phase),
      child: Container(
        width: AppSpacing.s2,
        height: AppSpacing.s2,
        decoration: BoxDecoration(
          // The lifted dot is also the brightest, so the eye follows the wave.
          color: Color.lerp(color, AppColors.accent, phase * 0.7),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
