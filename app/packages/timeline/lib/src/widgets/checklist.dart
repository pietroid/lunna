import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/models/models.dart';

/// {@template checklist_line}
/// One item of a routine's day, as a card draws it: a ring while it waits,
/// a check once it is ticked off, struck through, and its title.
///
/// The card of a day with a list draws the next item alone, with how many
/// are done at the end ([count]), or, on the calendar when the card has the
/// room, every item one under another.
/// {@endtemplate}
class ChecklistLine extends StatelessWidget {
  /// {@macro checklist_line}
  const ChecklistLine({
    required this.item,
    this.count,
    this.quiet = AppColors.ink3,
    super.key,
  });

  /// The next item of [card]'s list with how far the list has got, or
  /// "Tudo feito" once every item is ticked off.
  factory ChecklistLine.next(
    BuildContext context,
    TimelineEvent card, {
    Color quiet = AppColors.ink3,
  }) {
    final list = card.checklist;
    final done = list.where((item) => item.done).length;
    return ChecklistLine(
      item:
          card.nextItem ??
          ChecklistItem(title: context.l10n.checklistAllDone, done: true),
      count: context.l10n.checklistCount(done, list.length),
      quiet: quiet,
    );
  }

  /// The height of one line.
  static const double height = 20;

  /// The item.
  final ChecklistItem item;

  /// How far the list has got ("1 de 3"), drawn at the end, when given.
  final String? count;

  /// The colour of the mark and the count, lifted off the card's fill.
  final Color quiet;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.s4,
            child: Center(
              child: ChecklistMark(done: item.done, quiet: quiet),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              item.title,
              style: AppTypography.label.copyWith(
                color: item.done ? quiet : AppColors.ink2,
                decoration: item.done ? TextDecoration.lineThrough : null,
                decorationColor: quiet,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.s3),
            Text(count!, style: AppTypography.caption.copyWith(color: quiet)),
          ],
        ],
      ),
    );
  }
}

/// {@template checklist_mark}
/// The mark in front of an item: a ring while it waits, a check once done.
/// {@endtemplate}
class ChecklistMark extends StatelessWidget {
  /// {@macro checklist_mark}
  const ChecklistMark({
    required this.done,
    this.quiet = AppColors.ink3,
    this.size = 8,
    super.key,
  });

  /// Whether the item is ticked off.
  final bool done;

  /// The colour of the mark.
  final Color quiet;

  /// The ring's width; the check is drawn a little larger.
  final double size;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return AppIcon(iconData: AppIcons.check, size: size + 6, color: quiet);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: quiet, width: 1.5),
      ),
    );
  }
}
