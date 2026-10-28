import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';

/// {@template app_add_row}
/// The last line of a section, a + and Adicionar in the quiet ink: what
/// writes something down at the end of it. Tempo's stages end in one, and
/// so do Entregas' two groups.
/// {@endtemplate}
class AppAddRow extends StatelessWidget {
  /// {@macro app_add_row}
  const AppAddRow({required this.onTap, super.key});

  /// Writes something down there.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s3,
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
