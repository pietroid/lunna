import 'package:agent/src/surface.dart';
import 'package:agent/src/view/answer_card.dart';
import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart' show durationLabel, hhmm;

/// {@template cards_peek}
/// Some cards, read only, under the heading the agent gave them: each one's
/// name, then where it is (its hours, or Depois eu priorizo), its length and
/// its project, as Lista says them. A card asked about for its notes shows
/// them under it.
/// {@endtemplate}
class CardsPeek extends StatelessWidget {
  /// {@macro cards_peek}
  const CardsPeek({required this.block, super.key});

  final CardsBlock block;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AnswerCard(
      title: block.title,
      trailing: block.title == null || block.cards.length < 2
          ? null
          : l10n.agentCardsCount(block.cards.length),
      children: [
        for (final card in block.cards) PeekCardRow(card: card),
      ],
    );
  }
}

/// {@template peek_card_row}
/// One card of a [CardsPeek], or of a project's next tasks.
/// {@endtemplate}
class PeekCardRow extends StatelessWidget {
  /// {@macro peek_card_row}
  const PeekCardRow({required this.card, super.key});

  final PeekCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final at = card.at;
    final notes = card.notes;
    final now = clock.now();
    // Another day is named, so "09:00" is never read as today's.
    final day = at == null || DateUtils.isSameDay(at, now)
        ? ''
        : '${AppWheelPicker.dayLabel(l10n, at, now: now).toLowerCase()} ';
    final where = at == null
        ? l10n.stageBacklog
        : '$day${hhmm(at)}–${hhmm(at.add(Duration(minutes: card.minutes)))}';

    return AnswerRow(
      mark: card.done
          ? const AnswerMark(icon: AppIcons.check, ink: AppColors.success)
          : card.fixed
          ? const AnswerMark(
              icon: AppIcons.pin,
              fill: AppColors.fixedFill,
              ink: AppColors.fixedInk,
            )
          : null,
      title: card.title,
      detail: TextSpan(
        text: [
          where,
          if (at == null) durationLabel(l10n, card.minutes),
          ?card.project,
        ].join(' · '),
      ),
      below: notes == null
          ? null
          : Text(
              notes,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(color: AppColors.ink2),
            ),
    );
  }
}
