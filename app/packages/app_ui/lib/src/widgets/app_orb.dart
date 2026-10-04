import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// {@template app_orb}
/// The app's one floating action: a lit sphere that breathes.
///
/// Two spheres, really. The warm one runs from [AppColors.warning] down into
/// [AppColors.danger]; the cool one has a pale core that falls through
/// [AppColors.success] into [AppColors.info]. The orb crossfades between them
/// over [period] and swells very slightly as it goes, slowly enough that it
/// reads as something alive rather than as an animation asking to be watched.
/// {@endtemplate}
class AppOrb extends StatefulWidget {
  /// {@macro app_orb}
  const AppOrb({
    required this.onTap,
    this.diameter = 48,
    this.period = const Duration(seconds: 12),
    super.key,
  });

  /// Called when the orb is tapped.
  final VoidCallback onTap;

  /// How wide the sphere is at rest.
  final double diameter;

  /// One full warm-to-cool-and-back cycle.
  final Duration period;

  @override
  State<AppOrb> createState() => _AppOrbState();
}

class _AppOrbState extends State<AppOrb> with SingleTickerProviderStateMixin {
  /// The warm sphere, core first.
  static const _warm = <Color>[
    AppColors.warning,
    Color(0xFFC94A52),
    AppColors.danger,
  ];

  /// The cool sphere, core first.
  static const _cool = <Color>[
    AppColors.accent,
    AppColors.success,
    AppColors.info,
  ];

  /// Where each colour of a sphere sits, from the core out.
  ///
  /// The core is offset up and left by the alignment below, so these stops
  /// describe a lit sphere rather than a flat ring: a small bright centre,
  /// then a long fall into the rim.
  static const _stops = <double>[0, 0.45, 1];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  bool _pressed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_controller.value);
            final colors = <Color>[
              for (var index = 0; index < _warm.length; index++)
                Color.lerp(_warm[index], _cool[index], t) ?? _warm[index],
            ];
            // One slow breath per half-cycle, peaking where the two spheres
            // have fully crossed. Three percent is under the threshold where
            // the eye reads movement and over the one where it reads life.
            final breath = 1 + 0.03 * math.sin(math.pi * _controller.value);

            return Transform.scale(
              scale: breath,
              child: Container(
                width: widget.diameter,
                height: widget.diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    // The light comes from the top left, as it does on every
                    // other lit thing, so the sphere has a side.
                    center: const Alignment(-0.3, -0.35),
                    radius: 0.8,
                    colors: colors,
                    stops: _stops,
                  ),
                  // Two shadows rather than one: a tight halo that reads as
                  // the sphere being lit, and a wide, faint one that puts a
                  // little of its colour on the black around it.
                  boxShadow: [
                    BoxShadow(
                      color: colors[0].withValues(alpha: 0.28),
                      blurRadius: widget.diameter * 0.5,
                      spreadRadius: widget.diameter * 0.02,
                    ),
                    BoxShadow(
                      color: colors[1].withValues(alpha: 0.16),
                      blurRadius: widget.diameter * 1.1,
                      spreadRadius: widget.diameter * 0.06,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
