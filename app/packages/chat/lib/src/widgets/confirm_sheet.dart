import 'package:app_ui/app_ui.dart';
import 'package:chat/src/bloc/timeline_bloc.dart';
import 'package:chat/src/models/models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Asks before a block is taken off the calendar for good.
///
/// Deleting is the one thing on the timeline that cannot be taken back, so it
/// asks. Resolves to true only on the delete button; anything else, including
/// tapping outside, is a no.
Future<bool> confirmDelete(
  BuildContext context,
  String title, {
  String body = 'Sai da agenda e não volta.',
}) {
  return _confirm(
    context,
    title: 'Excluir “$title”?',
    body: body,
    action: 'Excluir',
    color: AppColors.dangerInk,
  );
}

/// Asks whether [card] may be cut to [minutes] so it fits a free stretch.
///
/// The stretch is shorter than the block, so the drop cannot land as it is.
/// Yes cuts it and puts it there; anything else leaves the day as it was.
Future<bool> confirmShorten(
  BuildContext context,
  TimelineEvent card,
  int minutes,
) {
  return _confirm(
    context,
    title: 'Não cabe inteiro aqui',
    body:
        '“${card.title}” leva ${card.durationMinutes} min e esse intervalo '
        'tem espaço para $minutes min, já contando a pausa. Ajustar para '
        '$minutes min?',
    action: 'Ajustar para $minutes min',
  );
}

/// Asks before [minutes] are added to [card], or taken off it when negative.
///
/// Changing a block's length moves everything after it, so the sheet says
/// where the block will end and that the rest of the day follows.
Future<bool> confirmAdjust(
  BuildContext context,
  TimelineEvent card,
  int minutes,
) {
  final end = card.endTime.add(Duration(minutes: minutes));
  final more = minutes > 0;
  final after = more
      ? 'O que vem depois anda junto.'
      : 'O que vem depois adianta.';

  return _confirm(
    context,
    title: more
        ? 'Mais ${minutes.abs()} minutos?'
        : 'Menos ${minutes.abs()} minutos?',
    body: '“${card.title}” passa a terminar às ${_hhmm(end)}. $after',
    action: more ? 'Adicionar' : 'Tirar',
  );
}

/// Asks, then gives [card] [minutes] more, or fewer when negative.
///
/// The one path both the timeline and the detail screen take, so the
/// question is the same wherever the button was.
Future<void> adjustTime(
  BuildContext context,
  TimelineEvent card,
  int minutes,
) async {
  final bloc = context.read<TimelineBloc>();
  if (await confirmAdjust(context, card, minutes)) {
    bloc.add(EventExtended(card.id, minutes: minutes));
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  Color color = AppColors.accent,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (sheetContext) => Material(
      color: AppColors.bg,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.cardRadius),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s6,
            AppSpacing.s5,
            AppSpacing.s6,
            AppSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTypography.title),
              const SizedBox(height: AppSpacing.s1),
              Text(
                body,
                style: AppTypography.body.copyWith(color: AppColors.ink2),
              ),
              const SizedBox(height: AppSpacing.s5),
              AppButton(
                text: action,
                color: color,
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: AppSpacing.s2),
              AppButton.text(
                text: 'Cancelar',
                color: AppColors.ink2,
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return confirmed ?? false;
}

String _hhmm(DateTime at) {
  return '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}
