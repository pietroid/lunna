import 'package:app_ui/app_ui.dart';

/// {@template app_list_item}
/// One row of a list: an icon, a line to read, and an optional second line.
///
/// The icon is what makes a list scannable, so it is given a colour that means
/// something and a fixed column of its own. Titles then start at the same x
/// whether or not the row above had a subtitle, and the eye runs straight down
/// them.
///
/// A row with two lines hangs its icon from the top, beside the title it
/// belongs to. A row with one line centres it instead: on a single line the
/// top and the middle are almost the same place, and hanging the glyph there
/// leaves it sitting visibly high of the text it is paired with.
/// {@endtemplate}
class AppListItem extends StatelessWidget {
  /// {@macro app_list_item}
  const AppListItem({
    required this.title,
    this.subtitle,
    this.iconData,
    this.color = AppColors.ink2,
    this.onTap,
    super.key,
  });

  /// The line that is read first.
  final String title;

  /// An optional supporting line.
  final String? subtitle;

  /// The leading icon.
  final AppIconData? iconData;

  /// What the icon's colour says about the row.
  final Color color;

  /// Makes the whole row tappable when given.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = iconData;
    final supporting = subtitle;
    final oneLine = supporting == null || supporting.isEmpty;

    final row = Row(
      crossAxisAlignment: oneLine
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            // On a two-line row the glyph is nudged down onto the title's
            // optical centre rather than left on its ascender line. A one-line
            // row is already centred, so the nudge would push it back off.
            padding: EdgeInsets.only(top: oneLine ? 0 : 2),
            child: AppIcon(iconData: icon, size: AppSpacing.s5, color: color),
          ),
          const SizedBox(width: AppSpacing.s3),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.bodyStrong),
              if (!oneLine) ...[
                const SizedBox(height: AppSpacing.s1),
                Text(
                  supporting,
                  style: AppTypography.label.copyWith(color: AppColors.ink2),
                ),
              ],
            ],
          ),
        ),
        if (onTap != null)
          Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.s2,
              top: oneLine ? 0 : 2,
            ),
            child: const AppIcon(
              iconData: AppIcons.chevronRight,
              size: AppSpacing.s4,
              color: AppColors.ink3,
            ),
          ),
      ],
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        child: row,
      ),
    );
  }
}
