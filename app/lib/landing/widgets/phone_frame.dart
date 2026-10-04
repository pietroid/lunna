import 'package:app_ui/app_ui.dart';

/// {@template phone_frame}
/// A phone drawn around [child], at a phone's size, scaled to fit.
///
/// The child is laid out at [screen] with the insets of a phone's status bar
/// and home indicator, whatever the box it is put in, so an app screen inside
/// looks the way it does in a hand. The whole phone is then scaled to the
/// space it is given, and still takes taps.
/// {@endtemplate}
class PhoneFrame extends StatelessWidget {
  /// {@macro phone_frame}
  const PhoneFrame({required this.child, super.key});

  /// The screen.
  final Widget child;

  /// The logical size of the screen inside the frame.
  static const screen = Size(390, 844);

  /// What the status bar and the home indicator take from the screen.
  static const _insets = EdgeInsets.only(top: 54, bottom: 34);

  static const _bezel = 12.0;
  static const _outerRadius = 60.0;
  static const double _screenRadius = _outerRadius - _bezel;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return FittedBox(
      child: Container(
        width: screen.width + _bezel * 2,
        height: screen.height + _bezel * 2,
        padding: const EdgeInsets.all(_bezel),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(_outerRadius),
          border: Border.all(color: AppColors.fillStrong, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 80,
              offset: Offset(0, 40),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_screenRadius),
          child: MediaQuery(
            data: media.copyWith(
              size: screen,
              padding: _insets,
              viewPadding: _insets,
              viewInsets: EdgeInsets.zero,
            ),
            child: ColoredBox(
              color: AppColors.bg,
              child: Stack(
                children: [
                  Positioned.fill(child: child),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(child: _StatusBar()),
                  ),
                  const Positioned(
                    bottom: AppSpacing.s2,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(child: _HomeIndicator()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The clock, the island and the signal, drawn once rather than faked per
/// screen.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.onest(
      size: 16,
      weight: FontWeight.w600,
      tracking: -0.04,
    );

    return SizedBox(
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 124,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF000000),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Row(
              children: [
                AppMinuteBuilder(
                  builder: (context, now) => Text(
                    '${now.hour.toString().padLeft(2, '0')}:'
                    '${now.minute.toString().padLeft(2, '0')}',
                    style: style,
                  ),
                ),
                const Spacer(),
                const _Signal(),
                const SizedBox(width: 6),
                const _Battery(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final height in const [4.0, 6.0, 8.0, 10.0])
          Container(
            width: 3,
            height: height,
            margin: const EdgeInsets.only(left: 1.5),
            decoration: const BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.all(Radius.circular(1)),
            ),
          ),
      ],
    );
  }
}

class _Battery extends StatelessWidget {
  const _Battery();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 12,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(3.5)),
            border: Border.all(color: AppColors.ink3),
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
        ),
        Container(
          width: 1.5,
          height: 4,
          margin: const EdgeInsets.only(left: 1),
          color: AppColors.ink3,
        ),
      ],
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 134,
        height: 5,
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
      ),
    );
  }
}
