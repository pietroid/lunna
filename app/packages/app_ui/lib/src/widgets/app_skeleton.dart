import 'package:app_ui/app_ui.dart';

/// {@template app_skeleton}
/// A placeholder that shimmers while real content is on its way.
///
/// The shimmer runs between [AppColors.fill] and [AppColors.fillStrong], so a
/// skeleton reads as the same surface a loaded element would sit on rather
/// than as a new colour appearing on the screen.
/// {@endtemplate}
class AppSkeleton extends StatefulWidget {
  /// {@macro app_skeleton}
  const AppSkeleton({
    this.width,
    this.height = AppSpacing.s4,
    this.radius = AppSpacing.s2,
    super.key,
  });

  /// How wide the placeholder is. Fills its parent when null.
  final double? width;

  /// How tall the placeholder is.
  final double height;

  /// The placeholder's corner radius.
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.fill,
              AppColors.fillStrong,
              Curves.easeInOut.transform(_controller.value),
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// {@template app_skeleton_lines}
/// A stack of [AppSkeleton] lines standing in for a paragraph.
///
/// The last line is short, the way a real last line of a paragraph is.
/// {@endtemplate}
class AppSkeletonLines extends StatelessWidget {
  /// {@macro app_skeleton_lines}
  const AppSkeletonLines({this.lines = 3, super.key});

  /// How many lines to draw.
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s2),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: i == lines - 1 ? 0.45 : 1,
            child: const AppSkeleton(height: AppSpacing.s3),
          ),
        ],
      ],
    );
  }
}
