import 'package:app_ui/app_ui.dart';

/// {@template app_icon_button}
/// An [IconButton] that displays an [AppIcon].
/// {@endtemplate}
class AppIconButton extends StatelessWidget {
  /// {@macro app_icon_button}
  const AppIconButton({
    required this.iconData,
    required this.onPressed,
    this.size = 24,
    this.color,
    super.key,
  });

  /// The data for the app icon to display.
  final AppIconData iconData;

  /// Called when the button is pressed.
  final VoidCallback onPressed;

  /// The size of the icon.
  final double size;

  /// Optional color to apply to the icon.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AppIcon(
        iconData: iconData,
        size: size,
        color: color,
      ),
      onPressed: onPressed,
    );
  }
}
