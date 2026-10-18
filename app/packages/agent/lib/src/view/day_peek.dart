import 'package:agent/src/surface.dart';
import 'package:agent/src/view/answer_card.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart' show durationLabel, hhmm;

/// {@template day_peek}
/// A slice of a day, as Tempo's calendar has it, small enough to read in
/// the conversation: each card at its hour in its own colour, and the free
/// room between them as the calendar draws it, with how long it is.
///
/// Heights follow the length, loosely: a long block is taller than a short
/// one, but nothing is shorter than a line or taller than three, so an
/// afternoon fits in a glance. The heading opens Tempo on that day.
/// {@endtemplate}
class DayPeek extends StatelessWidget {
  /// {@macro day_peek}
  const DayPeek({required this.block, this.onOpen, super.key});

  final DayBlock block;

  /// Opens Tempo on [DayBlock.day].
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final day = AppWheelPicker.dayLabel(l10n, block.day, now: clock.now());
    final free = block.free;

    return AnswerCard(
      title: '$day · ${hhmm(block.from)}–${hhmm(block.to)}',
      trailing: free == 0 ? null : l10n.agentFree(durationLabel(l10n, free)),
      onTitleTap: onOpen,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s3,
            AppSpacing.s1,
            AppSpacing.s4,
            AppSpacing.s3,
          ),
          child: Column(
            children: [
              for (final item in block.items) _PeekRow(item: item),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeekRow extends StatelessWidget {
  const _PeekRow({required this.item});

  final PeekItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final minutes = item.end.difference(item.start).inMinutes;
    final height = (minutes * 0.5).clamp(36.0, 84.0);
    final free = item.kind == PeekKind.free;
    final (fill, ink) = switch (item.kind) {
      PeekKind.fixed => (AppColors.fixedFill, AppColors.fixedInk),
      PeekKind.routine => (AppColors.routineFill, AppColors.routineInk),
      PeekKind.running => (AppColors.accentSoft, AppColors.accent),
      PeekKind.free => (AppColors.freeFill, AppColors.freeInk),
      PeekKind.task => (AppColors.bg, AppColors.ink),
    };
    final project = item.project;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: Text(
                hhmm(item.start),
                style: AppTypography.label.copyWith(
                  color: AppColors.ink3,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s2,
              ),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                border: free ? Border.all(color: AppColors.freeEdge) : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      free
                          ? l10n.agentFree(durationLabel(l10n, minutes))
                          : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: free
                          ? AppTypography.label.copyWith(color: ink)
                          : AppTypography.labelStrong.copyWith(color: ink),
                    ),
                  ),
                  if (!free)
                    Text(
                      [?project, durationLabel(l10n, minutes)].join(' · '),
                      style: AppTypography.label.copyWith(
                        color: ink == AppColors.ink ? AppColors.ink3 : ink,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
