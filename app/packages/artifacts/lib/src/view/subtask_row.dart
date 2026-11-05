import 'package:app_ui/app_ui.dart';

/// {@template subtask_row}
/// A subtask's card with the calendar's swipes: right ticks it off, left deletes it (asking first).
///
/// Done needs no answer, as on the calendar; delete asks ([onDelete]).
/// The card always springs back, because the list redraws from the server.
/// [offset] and [lifted] seed a swipe or a drag already under way, for the
/// previews.
/// {@endtemplate}
class SubtaskRow extends StatefulWidget {
  /// {@macro subtask_row}
  const SubtaskRow({
    required this.child,
    required this.onDone,
    required this.onDelete,
    this.offset = 0,
    this.lifted = false,
    super.key,
  });

  final Widget child;
  final Future<void> Function() onDone;
  final Future<void> Function() onDelete;
  final double offset;
  final bool lifted;

  @override
  State<SubtaskRow> createState() => _SubtaskRowState();
}

class _SubtaskRowState extends State<SubtaskRow> {
  static const _threshold = 96.0;
  late double _dx = widget.offset;

  Future<void> _release() async {
    final dx = _dx;
    setState(() => _dx = 0);
    if (dx >= _threshold) await widget.onDone();
    if (dx <= -_threshold) await widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final done = _dx > 0;
    final shown = _dx.abs().clamp(0, 160).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) => setState(() => _dx += d.delta.dx),
      onHorizontalDragEnd: (_) => _release(),
      child: ClipRect(
        child: Stack(
          children: [
            // As on the calendar: only the icon, in the card's own corner, no
            // fill and no label.
            if (_dx != 0)
              Positioned.fill(
                child: Align(
                  alignment: done
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4,
                    ),
                    child: Opacity(
                      opacity: (shown / _threshold).clamp(0, 1).toDouble(),
                      child: AppIcon(
                        iconData: done ? AppIcons.check : AppIcons.trash,
                        color: done ? AppColors.success : AppColors.dangerInk,
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(_dx, 0),
              child: AnimatedScale(
                scale: widget.lifted ? 1.03 : 1,
                duration: const Duration(milliseconds: 120),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    boxShadow: widget.lifted
                        ? [
                            const BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
