import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';

/// {@template app_add_row}
/// The last line of a section, a + and Adicionar in the quiet ink: what
/// writes something down at the end of it. Tempo's stages end in one, and
/// so do Entregas' two groups.
/// {@endtemplate}
class AppAddRow extends StatelessWidget {
  /// {@macro app_add_row}
  const AppAddRow({required this.onTap, this.dense = false, super.key});

  /// Writes something down there.
  final VoidCallback onTap;

  /// Sits close under the card above it, its + in line with the cards'
  /// edge: Plano's Em seguida, where the queue runs straight on into it.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? AppSpacing.s1 : AppSpacing.s3,
            vertical: dense ? AppSpacing.s1 : AppSpacing.s3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(
                iconData: AppIcons.plus,
                size: AppSpacing.s4,
                color: AppColors.ink3,
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                context.l10n.timelineAdd,
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
