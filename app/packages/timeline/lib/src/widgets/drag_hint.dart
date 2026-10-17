import 'package:app_ui/app_ui.dart';

/// {@template drag_hint}
/// What letting go will do, said over whatever is being dragged.
///
/// A small dark pill, read before the finger comes off: how far a block is
/// being moved or stretched and the hour it lands on, that it is taking
/// another card's place, that it is being paused, or that it cannot go
/// where it is. One line, never more, so it can sit on top of the card
/// without hiding what the card says.
/// {@endtemplate}
class DragHint extends StatelessWidget {
  /// {@macro drag_hint}
  const DragHint({
    required this.icon,
    required this.text,
    this.refused = false,
    super.key,
  });

  /// What the gesture is doing: moving, swapping, stretching, pausing.
  final AppIconData icon;

  /// The line itself.
  final String text;

  /// Whether letting go here does nothing, which dims the pill.
  final bool refused;

  @override
  Widget build(BuildContext context) {
    final ink = refused ? AppColors.ink3 : AppColors.bg;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: refused ? AppColors.fillStrong : AppColors.ink,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s1 + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(iconData: icon, size: AppSpacing.s4, color: ink),
            const SizedBox(width: AppSpacing.s1 + 2),
            Text(
              text,
              style: AppTypography.labelStrong.copyWith(color: ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// {@template seam_handle}
/// The edge between a block and the one right after it, picked up.
///
/// Held, the seam lifts as a short bar in the accent across the line where
/// one block ends; dragged, it moves that end. The block above takes the
/// new length, and the one below, when it is snapped to it, comes along
/// keeping its own.
/// {@endtemplate}
class SeamHandle extends StatelessWidget {
  /// {@macro seam_handle}
  const SeamHandle({super.key});

  /// How tall the handle is drawn, and so how far it pokes past the seam.
  static const double height = 6;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 2, color: AppColors.accent),
        ),
        Container(
          width: AppSpacing.s8 + AppSpacing.s2,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(height / 2),
            // Black on Focus, which is also the default; not on Lunna.
            // ignore: avoid_redundant_argument_values
            border: Border.all(color: AppColors.bg, width: 2),
          ),
        ),
        Expanded(
          child: Container(height: 2, color: AppColors.accent),
        ),
      ],
    );
  }
}
