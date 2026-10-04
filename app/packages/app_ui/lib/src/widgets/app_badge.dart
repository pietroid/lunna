import 'package:app_ui/app_ui.dart';

/// {@template app_badge}
/// A small pill carrying one word about state.
///
/// Sized to its content and never wider than its label, so a row of badges
/// reads as a row of statuses rather than a row of buttons.
/// {@endtemplate}
class AppBadge extends StatelessWidget {
  /// {@macro app_badge}
  const AppBadge({
    required this.text,
    this.color = AppColors.accent,
    this.iconData,
    super.key,
  });

  /// The label. Two or three words at most.
  final String text;

  /// What the badge says about state.
  final Color color;

  /// An optional leading icon.
  final AppIconData? iconData;

  @override
  Widget build(BuildContext context) {
    final icon = iconData;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(iconData: icon, size: AppSpacing.s4, color: color),
            const SizedBox(width: AppSpacing.s1),
          ],
          Text(text, style: AppTypography.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}
