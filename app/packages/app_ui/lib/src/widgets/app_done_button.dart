import 'package:app_ui/app_ui.dart';

/// {@template app_done_button}
/// The button a task or a project is ticked off with, on its own page.
///
/// It says what it does in words ("Marcar como feita"), a check before
/// them, on a quiet fill with no border, so it can never be read as "save"
/// the way a bare check in the corner of an editor is, nor as a stray
/// circle before the name. Done, it says so ("Feita") in the accent and
/// takes no taps unless [onChanged] can undo it.
/// {@endtemplate}
class AppDoneButton extends StatelessWidget {
  /// {@macro app_done_button}
  const AppDoneButton({
    required this.done,
    required this.label,
    required this.doneLabel,
    this.onChanged,
    super.key,
  });

  /// Whether it is ticked.
  final bool done;

  /// What it says while not done: "Marcar como feita".
  final String label;

  /// What it says once done: "Feita".
  final String doneLabel;

  /// Called with the new value; null draws it but takes no taps.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final ink = done ? AppColors.accent : AppColors.ink;

    return Semantics(
      button: true,
      checked: done,
      child: Material(
        color: done ? AppColors.accentWash : AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged(!done),
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s3,
              AppSpacing.s2,
              AppSpacing.s4,
              AppSpacing.s2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(iconData: AppIcons.check, size: 16, color: ink),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  done ? doneLabel : label,
                  style: AppTypography.labelStrong.copyWith(color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
