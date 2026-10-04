import 'package:app_ui/app_ui.dart';

/// {@template app_text_editor}
/// A multiline editor that expands to fill its parent. Same fill as
/// [AppTextField], but squared off to [AppSpacing.cardRadius], because a pill
/// stops reading as a field once it is taller than it is round.
/// {@endtemplate}
class AppTextEditor extends StatelessWidget {
  /// {@macro app_text_editor}
  const AppTextEditor({
    this.controller,
    this.hintText,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    super.key,
  });

  /// Controls the text being edited.
  final TextEditingController? controller;

  /// Text that suggests what sort of input the editor accepts.
  final String? hintText;

  /// Whether the editor is interactive.
  final bool enabled;

  /// Whether the editor takes focus as soon as it is shown.
  final bool autofocus;

  /// Called when the user changes the editor's value.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.cardRadius)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        onChanged: onChanged,
        cursorColor: AppColors.ink,
        cursorWidth: 1.5,
        cursorRadius: const Radius.circular(AppSpacing.s1),
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: hintText,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s5,
            vertical: AppSpacing.s4,
          ),
        ),
      ),
    );
  }
}
