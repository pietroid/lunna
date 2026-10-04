import 'package:app_ui/app_ui.dart';

/// {@template app_fab}
/// The app's one floating action: a lit circle with a plus.
///
/// The only accent-coloured thing at the foot of the screen, so it is found
/// without looking for it. It presses in slightly under the finger rather
/// than rippling, which is how every other surface in the app answers a tap.
/// {@endtemplate}
class AppFab extends StatefulWidget {
  /// {@macro app_fab}
  const AppFab({
    required this.onPressed,
    this.iconData = AppIcons.plus,
    this.tooltip,
    this.diameter = 56,
    super.key,
  });

  /// Called when the button is tapped.
  final VoidCallback onPressed;

  /// The glyph in the middle.
  final AppIconData iconData;

  /// What a long press and a screen reader say it does.
  final String? tooltip;

  /// How wide the circle is.
  final double diameter;

  @override
  State<AppFab> createState() => _AppFabState();
}

class _AppFabState extends State<AppFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: Container(
            width: widget.diameter,
            height: widget.diameter,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Center(
              child: AppIcon(
                iconData: widget.iconData,
                color: AppColors.onAccent,
              ),
            ),
          ),
        ),
      ),
    );

    final tooltip = widget.tooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
