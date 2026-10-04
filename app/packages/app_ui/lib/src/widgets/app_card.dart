import 'package:app_ui/app_ui.dart';

/// {@template app_card}
/// A padded surface that groups one thing worth judging on its own.
///
/// A card tinted by [color] washes its fill and border in that colour at low
/// opacity rather than filling with it. On true black a solid colour block
/// shouts; a wash says "these three lines belong together and this is how it
/// went" while the text on top stays the brightest thing in the card.
/// {@endtemplate}
class AppCard extends StatelessWidget {
  /// {@macro app_card}
  const AppCard({required this.child, this.color, super.key});

  /// What the card holds.
  final Widget child;

  /// The colour the card is tinted with. Neutral when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: tint == null ? AppColors.fill : tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(
          color: tint == null ? AppColors.line : tint.withValues(alpha: 0.32),
        ),
      ),
      child: child,
    );
  }
}
