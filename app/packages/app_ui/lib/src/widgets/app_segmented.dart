import 'package:app_ui/app_ui.dart';

/// One choice in an [AppSegmented].
class AppSegment {
  /// Creates a segment.
  const AppSegment({required this.label, this.iconData});

  /// What it says.
  final String label;

  /// The icon in front of the label, when it has one.
  final AppIconData? iconData;
}

/// {@template app_segmented}
/// A row of choices in one pill, exactly one of them taken.
///
/// The selected segment is the only lit one; the pill around them all is the
/// same fill a card is, so a group of these reads as one control rather than
/// as several buttons that happen to be adjacent. Nothing here is coloured:
/// picking between two ways of doing something is not an outcome.
/// {@endtemplate}
class AppSegmented extends StatelessWidget {
  /// {@macro app_segmented}
  const AppSegmented({
    required this.segments,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The choices, in the order they are drawn.
  final List<AppSegment> segments;

  /// Which one is taken.
  final int selected;

  /// Called with the index of the segment that was tapped.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < segments.length; index++)
            _Segment(
              segment: segments[index],
              isSelected: index == selected,
              onTap: () => onSelected(index),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  final AppSegment segment;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.ink : AppColors.ink3;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.fillStrong : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (segment.iconData != null) ...[
              AppIcon(
                iconData: segment.iconData!,
                size: AppSpacing.s4,
                color: color,
              ),
              const SizedBox(width: AppSpacing.s1 + 2),
            ],
            Text(
              segment.label,
              style: AppTypography.label.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// {@template app_pill_button}
/// A single pill that opens something, showing what it currently says.
///
/// The same shape as one [AppSegmented] segment, so a row of both reads as
/// one line of controls rather than two kinds of thing.
/// {@endtemplate}
class AppPillButton extends StatelessWidget {
  /// {@macro app_pill_button}
  const AppPillButton({
    required this.label,
    required this.onPressed,
    this.iconData,
    super.key,
  });

  /// What it currently says.
  final String label;

  /// The icon in front of the label.
  final AppIconData? iconData;

  /// Called when it is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s3 - 1,
        ),
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData != null) ...[
              AppIcon(
                iconData: iconData!,
                size: AppSpacing.s4,
                color: AppColors.ink2,
              ),
              const SizedBox(width: AppSpacing.s1 + 2),
            ],
            Text(label, style: AppTypography.label),
          ],
        ),
      ),
    );
  }
}
