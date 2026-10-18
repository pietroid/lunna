import 'package:app_ui/app_ui.dart';

/// {@template answer_card}
/// The one shape every block of an answer takes: a borderless fill, a
/// heading in the quiet ink with what it counts on the right, and rows
/// parted by a seam of the page's own colour.
///
/// A plan, a slice of the day, some cards and a project all sit in it, so a
/// surface reads as one thing however the model stacked it.
/// {@endtemplate}
class AnswerCard extends StatelessWidget {
  /// {@macro answer_card}
  const AnswerCard({
    required this.children,
    this.title,
    this.trailing,
    this.onTitleTap,
    this.footer,
    super.key,
  });

  final String? title;

  /// Beside the heading, on the right: a count, a length.
  final String? trailing;

  /// Opens what the heading names; a chevron says it can.
  final VoidCallback? onTitleTap;

  final List<Widget> children;

  /// Under a seam, for the card's actions.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final trailing = this.trailing;
    final heading = title == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s3,
              AppSpacing.s4,
              AppSpacing.s2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelStrong.copyWith(
                      color: AppColors.ink2,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing,
                    style: AppTypography.label.copyWith(color: AppColors.ink3),
                  ),
                if (onTitleTap != null) ...[
                  const SizedBox(width: AppSpacing.s1),
                  const AppIcon(
                    iconData: AppIcons.chevronRight,
                    size: 14,
                    color: AppColors.ink3,
                  ),
                ],
              ],
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius + 4),
      child: ColoredBox(
        color: AppColors.fill,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heading != null)
              onTitleTap == null
                  ? heading
                  : InkWell(onTap: onTitleTap, child: heading),
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const AnswerSeam(),
              child,
            ],
            if (footer != null) ...[const AnswerSeam(), footer!],
          ],
        ),
      ),
    );
  }
}

/// The parting between two rows of an [AnswerCard]: the page showing
/// through.
class AnswerSeam extends StatelessWidget {
  /// The parting between two rows.
  const AnswerSeam({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 2, thickness: 2, color: AppColors.bg);
}

/// {@template answer_row}
/// One row of an [AnswerCard]: a mark, a title, and a quiet line under it.
/// {@endtemplate}
class AnswerRow extends StatelessWidget {
  /// {@macro answer_row}
  const AnswerRow({
    required this.title,
    this.mark,
    this.detail,
    this.below,
    this.struck = false,
    super.key,
  });

  /// The square on the left, when the row has one.
  final AnswerMark? mark;

  final String title;

  /// The quiet line under the title.
  final InlineSpan? detail;

  /// Anything else, under [detail]: added notes, what goes along.
  final Widget? below;

  /// Whether the title is struck through: something that goes.
  final bool struck;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    final below = this.below;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mark != null) ...[mark!, const SizedBox(width: AppSpacing.s3)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyStrong.copyWith(
                    decoration: struck ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.ink3,
                    color: struck ? AppColors.ink2 : AppColors.ink,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text.rich(detail, style: AppTypography.label),
                ],
                if (below != null) ...[
                  const SizedBox(height: AppSpacing.s2),
                  below,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// {@template answer_mark}
/// The 28-point square that says what a row is, by its glyph and its
/// colour.
/// {@endtemplate}
class AnswerMark extends StatelessWidget {
  /// {@macro answer_mark}
  const AnswerMark({
    required this.icon,
    this.fill = AppColors.bg,
    this.ink = AppColors.ink2,
    super.key,
  });

  final AppIconData icon;

  final Color fill;

  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        child: AppIcon(iconData: icon, size: 15, color: ink),
      ),
    );
  }
}
