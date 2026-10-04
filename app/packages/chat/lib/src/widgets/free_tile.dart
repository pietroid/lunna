import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';

/// {@template free_tile}
/// A stretch of the day with nothing programmed.
///
/// A gap is not an empty screen, and it is not a missing card either: it is
/// room, drawn as its own quiet card in a faint green so it reads as time to
/// breathe. It says no hour: it is now, and the card after it says when now
/// ends.
///
/// The one happening now is also the break, and adds a line saying so. The
/// line is picked from where the stretch starts, so it stays the same for the
/// whole gap instead of changing every time the list is read. It is as tall
/// as the running card it stands in for, so Agora keeps its shape whether or
/// not something is in it.
///
/// It is also somewhere a card can be dropped, and lights up while one is
/// aimed at it, and somewhere to tap, with a ripple, to write something down
/// from the moment it starts.
/// {@endtemplate}
class FreeTile extends StatelessWidget {
  /// {@macro free_tile}
  const FreeTile({
    required this.slot,
    this.now = false,
    this.targeted = false,
    this.onTap,
    super.key,
  });

  /// The stretch.
  final FreeSlot slot;

  /// Whether it is the stretch being lived through, which is the break.
  final bool now;

  /// Whether a card in the air would land here.
  final bool targeted;

  /// Called when it is tapped.
  final VoidCallback? onTap;

  /// Twenty ways of saying the same thing.
  static const messages = <String>[
    'Respire fundo. Três vezes, devagar.',
    'Levante, alongue as costas e olhe pela janela.',
    'Beba um copo d’água antes de continuar.',
    'Feche os olhos por um minuto. Só isso.',
    'Deixe a cabeça vazia. O próximo passo espera.',
    'Solte os ombros. Eles estavam tensos, não estavam?',
    'Olhe para algo longe. Seus olhos agradecem.',
    'Nada para resolver agora. Aproveite.',
    'Caminhe um pouco, nem que seja até a cozinha.',
    'Um minuto de silêncio. Sem tela.',
    'Repare no que você está ouvindo agora.',
    'Você terminou algo. Reconheça isso.',
    'Inspire em quatro, segure em quatro, solte em quatro.',
    'Desligue a mente. Ela volta melhor.',
    'Mexa as mãos, gire os pulsos, relaxe o rosto.',
    'Pausa de verdade: sem celular.',
    'Sinta os pés no chão por alguns segundos.',
    'Descansar também é parte do trabalho.',
    'Deixe o último assunto ir embora.',
    'Medite por um instante. Só respire e observe.',
  ];

  /// The line for the break that is [slot].
  static String messageFor(FreeSlot slot) {
    final seed = slot.end.millisecondsSinceEpoch ~/ 60000;
    return messages[seed % messages.length];
  }

  /// The height of the running card, title, progress and buttons, which the
  /// break under Agora takes too.
  static const double nowHeight = 98;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: BoxConstraints(minHeight: now ? nowHeight : 0),
      decoration: BoxDecoration(
        color: targeted ? AppColors.fillStrong : AppColors.freeFill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.fillStrong,
          highlightColor: AppColors.fill,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s5,
              vertical: AppSpacing.s4,
            ),
            // Centred in whatever height the running card would have had.
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nada programado',
                    style: AppTypography.body.copyWith(
                      color: AppColors.freeInk,
                    ),
                  ),
                  if (now) ...[
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      messageFor(slot),
                      style: AppTypography.label.copyWith(
                        color: AppColors.ink2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
