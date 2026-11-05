import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';

/// {@template subtask_row}
/// A subtask's card with its swipes: right ticks it off, left deletes it.
///
/// Both only reveal their button past the threshold and ask before they
/// do anything ([onDone], [onDelete] return whether the answer was yes);
/// the card always springs back, because the list redraws from the server.
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
    final l10n = context.l10n;
    final done = _dx > 0;
    final shown = _dx.abs().clamp(0, 160).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) => setState(() => _dx += d.delta.dx),
      onHorizontalDragEnd: (_) => _release(),
      child: Stack(
        children: [
          if (_dx != 0)
            Positioned.fill(
              child: Container(
                alignment: done ? Alignment.centerLeft : Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
                decoration: BoxDecoration(
                  color: done ? AppColors.success : AppColors.dangerInk,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Opacity(
                  opacity: (shown / _threshold).clamp(0, 1).toDouble(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        iconData: done ? AppIcons.check : AppIcons.trash,
                        color: AppColors.bg,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        done ? l10n.subtaskSwipeDone : l10n.subtaskSwipeDelete,
                        style: AppTypography.label.copyWith(
                          color: AppColors.bg,
                        ),
                      ),
                    ],
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
    );
  }
}
