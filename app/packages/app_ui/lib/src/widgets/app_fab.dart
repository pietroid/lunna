import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';

/// {@template app_fab}
/// The app's one floating action: a lit circle with a plus.
///
/// The only accent-coloured thing at the foot of the screen, so it is found
/// without looking for it. It presses in slightly under the finger rather
/// than rippling, which is how every other surface in the app answers a tap.
///
/// Give the scaffold [AppFab.location] so the button sits at the end of the
/// content column rather than at the edge of a wide screen.
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

  /// Floats the button at the end of the content column: at the screen's
  /// edge on a phone, and at the column's edge when the screen is wider
  /// than [AppSpacing.maxContentWidth].
  static const FloatingActionButtonLocation location = _ColumnEndFloat();

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

/// [FloatingActionButtonLocation.endFloat], measured from the edge of the
/// centred content column instead of the edge of the screen.
class _ColumnEndFloat extends StandardFabLocation with FabFloatOffsetY {
  const _ColumnEndFloat();

  @override
  double getOffsetX(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) {
    final width = scaffoldGeometry.scaffoldSize.width;
    final column = math.min(width, AppSpacing.maxContentWidth);
    // What lies beside the column on each side, or the safe area if more.
    final beside = (width - column) / 2;
    final fabWidth = scaffoldGeometry.floatingActionButtonSize.width;

    switch (scaffoldGeometry.textDirection) {
      case TextDirection.ltr:
        final inset = math.max(beside, scaffoldGeometry.minInsets.right);
        return width - inset - kFloatingActionButtonMargin - fabWidth;
      case TextDirection.rtl:
        final inset = math.max(beside, scaffoldGeometry.minInsets.left);
        return inset + kFloatingActionButtonMargin;
    }
  }

  @override
  String toString() => 'AppFab.location';
}
