import 'dart:ui';

import 'package:app_ui/app_ui.dart';

/// One destination in the [AppBottomBar].
class AppBottomBarItem {
  /// {@macro app_bottom_bar_item}
  const AppBottomBarItem({required this.iconData, required this.label});

  /// The glyph that stands for the destination.
  final AppIconData iconData;

  /// The word under the glyph.
  final String label;
}

/// {@template app_bottom_bar}
/// The app's destinations, side by side.
///
/// Nothing here is drawn in a colour: the one lit thing at the foot of the
/// screen is the [AppFab] floating above it, and the bar stays out of its
/// way.
///
/// The bar has no border and no hard edge. It blurs what scrolls under it
/// just enough to read as fog and darkens as it falls, so a list dims out
/// under the labels rather than stopping against a panel.
/// {@endtemplate}
class AppBottomBar extends StatelessWidget {
  /// {@macro app_bottom_bar}
  const AppBottomBar({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  /// The destinations, in order.
  final List<AppBottomBarItem> items;

  /// Which destination is being shown.
  final int currentIndex;

  /// Called with the index of a tapped destination.
  final ValueChanged<int> onSelected;

  /// How tall the row of destinations is, before the safe area.
  static const height = 72.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0xE6000000)],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _Destination(index: index, bar: this),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One tappable destination: a glyph, and the word for it.
class _Destination extends StatelessWidget {
  const _Destination({required this.index, required this.bar});

  final int index;
  final AppBottomBar bar;

  @override
  Widget build(BuildContext context) {
    final item = bar.items[index];
    final selected = index == bar.currentIndex;
    // Selection is carried by brightness alone. A second signal here — a
    // pill, a dot, a filled glyph — would compete with the button above.
    final color = selected ? AppColors.ink : AppColors.ink3;

    return InkWell(
      onTap: () => bar.onSelected(index),
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The default icon size, which is the largest the row fits with a
          // word under it. A destination is read by its glyph first.
          AppIcon(iconData: item.iconData, color: color),
          const SizedBox(height: AppSpacing.s1),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
