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
/// The app's four destinations, with the orb sitting in the middle of them.
///
/// The orb is the one action the app has, so it is not a button parked on top
/// of the bar: the bar is built around it, two destinations to its left and
/// two to its right. Nothing here is drawn in a colour, because the orb is
/// already the only lit thing at the foot of the screen.
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
    required this.center,
    super.key,
  }) : assert(
         items.length == 4,
         'The bar holds two destinations on each side of the orb.',
       );

  /// The four destinations, in order: two left of the orb, two right of it.
  final List<AppBottomBarItem> items;

  /// Which destination is being shown.
  final int currentIndex;

  /// Called with the index of a tapped destination.
  final ValueChanged<int> onSelected;

  /// What sits in the middle. The orb, in practice.
  final Widget center;

  /// How tall the row of destinations is, before the safe area.
  ///
  /// Taller than a glyph and a word need, so the orb has black around it
  /// inside the bar and its glow is mostly spent before it leaves.
  static const _height = 80.0;

  /// The width reserved for [center], wide enough that the orb's glow does
  /// not spill onto the labels beside it.
  static const _centerWidth = 80.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // The orb is painted by this stack, not by the clipped fog behind it,
      // so its glow carries up over the screen instead of stopping at the
      // top edge of the bar.
      clipBehavior: Clip.none,
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
            height: _height,
            child: Row(
              children: [
                for (var index = 0; index < 2; index++)
                  Expanded(
                    child: _Destination(index: index, bar: this),
                  ),
                SizedBox(
                  width: _centerWidth,
                  child: Center(child: center),
                ),
                for (var index = 2; index < 4; index++)
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
    // pill, a dot, a filled glyph — would compete with the orb.
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
