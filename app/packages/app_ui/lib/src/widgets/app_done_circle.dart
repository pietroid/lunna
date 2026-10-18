import 'package:app_ui/app_ui.dart';

/// {@template app_done_circle}
/// The round box a task or a project is ticked off with, before its name.
///
/// Empty, it is something still to do; a tap fills it with the accent and
/// a check. It sits where a checklist's box sits, so it reads as "done" and
/// never as "save", which a bare check in the corner of an editor does.
/// {@endtemplate}
class AppDoneCircle extends StatelessWidget {
  /// {@macro app_done_circle}
  const AppDoneCircle({
    required this.done,
    required this.label,
    this.onChanged,
    this.size = 24,
    super.key,
  });

  /// Whether it is ticked.
  final bool done;

  /// What a tap does, for a screen reader: "Marcar como feita".
  final String label;

  /// Called with the new value; null draws it but takes no taps.
  final ValueChanged<bool>? onChanged;

  /// Its diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;

    return Semantics(
      button: true,
      checked: done,
      label: label,
      child: InkResponse(
        onTap: onChanged == null ? null : () => onChanged(!done),
        radius: AppSpacing.tapTarget / 2,
        child: SizedBox.square(
          dimension: AppSpacing.tapTarget,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.accent : Colors.transparent,
                border: done
                    ? null
                    : Border.all(color: AppColors.ink3, width: 1.75),
              ),
              child: done
                  ? AppIcon(
                      iconData: AppIcons.check,
                      size: size * 0.55,
                      color: AppColors.onAccent,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
