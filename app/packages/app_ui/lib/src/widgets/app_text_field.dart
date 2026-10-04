import 'package:app_ui/app_ui.dart';

/// {@template app_text_field}
/// The app's single-line field: a borderless pill on [AppColors.fill], sized
/// to [AppSpacing.fieldHeight] so it matches every other control on the grid.
/// {@endtemplate}
class AppTextField extends StatelessWidget {
  /// {@macro app_text_field}
  const AppTextField({
    this.controller,
    this.focusNode,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  /// Controls the text being edited.
  final TextEditingController? controller;

  /// Controls the focus of the field.
  final FocusNode? focusNode;

  /// Text that suggests what sort of input the field accepts.
  final String? hintText;

  /// The type of keyboard to use for editing the text.
  final TextInputType? keyboardType;

  /// The action button to show on the keyboard.
  final TextInputAction? textInputAction;

  /// Whether to hide the text being edited.
  final bool obscureText;

  /// Whether the field is interactive.
  final bool enabled;

  /// Whether the field takes focus as soon as it is shown.
  final bool autofocus;

  /// How the text is aligned inside the field.
  final TextAlign textAlign;

  /// Called when the user changes the field's value.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the field.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.fieldHeight),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: autofocus,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: obscureText,
        textAlign: textAlign,
        textAlignVertical: TextAlignVertical.center,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        cursorColor: AppColors.ink,
        cursorWidth: 1.5,
        cursorRadius: const Radius.circular(AppSpacing.s1),
        style: AppTypography.body,
        decoration: InputDecoration(hintText: hintText),
      ),
    );
  }
}
