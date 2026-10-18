import 'package:app_ui/app_ui.dart';

/// {@template app_tag}
/// A quiet label of what something belongs to, such as a task's project:
/// a small icon and a name on a borderless fill.
///
/// It names, it does not ask: a tag with [onTap] opens what it names.
/// {@endtemplate}
class AppTag extends StatelessWidget {
  /// {@macro app_tag}
  const AppTag({
    required this.text,
    this.iconData = AppIcons.things,
    this.fill = AppColors.fillStrong,
    this.ink = AppColors.ink2,
    this.onTap,
    super.key,
  });

  /// The name of what it belongs to.
  final String text;

  /// What kind of thing that is; a project by default.
  final AppIconData iconData;

  /// The fill behind it.
  final Color fill;

  /// The colour of the icon and the name.
  final Color ink;

  /// Opens what it names; null, it is only a label.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tag = Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s2,
        3,
        AppSpacing.s2 + 2,
        3,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(iconData: iconData, size: 13, color: ink),
          const SizedBox(width: AppSpacing.s1),
          Flexible(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(
                color: ink,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return tag;

    return GestureDetector(onTap: onTap, child: tag);
  }
}
