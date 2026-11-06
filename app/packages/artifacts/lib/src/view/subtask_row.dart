import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/services.dart';

/// {@template subtask_row}
/// A subtask's card with the calendar's swipes: right ticks it off, left
/// deletes it.
///
/// Past [threshold], letting go calls [onDone] or [onDelete]; delete asks
/// first, done does not, as on the calendar. Either way the card springs
/// back, because the list redraws from the server. Only the icon shows
/// under the card, in its corner, with no fill and no label.
/// {@endtemplate}
class SubtaskRow extends StatefulWidget {
  /// {@macro subtask_row}
  const SubtaskRow({
    required this.child,
    required this.onDone,
    required this.onDelete,
    super.key,
  });

  /// How far the card must travel for letting go to count.
  static const threshold = 96.0;

  /// The card.
  final Widget child;

  /// A swipe right let go past [threshold].
  final VoidCallback onDone;

  /// A swipe left let go past [threshold].
  final VoidCallback onDelete;

  @override
  State<SubtaskRow> createState() => _SubtaskRowState();
}

class _SubtaskRowState extends State<SubtaskRow> {
  double _dx = 0;

  void _release() {
    final dx = _dx;
    setState(() => _dx = 0);
    if (dx >= SubtaskRow.threshold) {
      unawaited(HapticFeedback.mediumImpact());
      widget.onDone();
    } else if (dx <= -SubtaskRow.threshold) {
      unawaited(HapticFeedback.mediumImpact());
      widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _dx > 0;
    final shown = _dx.abs().clamp(0, 160).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) => setState(() => _dx += d.delta.dx),
      onHorizontalDragEnd: (_) => _release(),
      onHorizontalDragCancel: () => setState(() => _dx = 0),
      child: ClipRect(
        child: Stack(
          children: [
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
                      opacity: (shown / SubtaskRow.threshold)
                          .clamp(0, 1)
                          .toDouble(),
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
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
