import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';
import 'package:chat/src/widgets/timeline_scale.dart';

/// What a tap on empty room asked for.
///
/// `from` is where the room starts, which is the earliest anything written
/// down there may start. `fixedAt` is the hour that was tapped, when a full
/// hour was, and the block is fixed there. Switched to flexible in the
/// sheet, it goes back to `from` rather than to now: it was written down in
/// that room, not at the top of the day.
typedef FreeTap = ({DateTime from, DateTime? fixedAt});

/// {@template free_stretch}
/// Empty room later in the day, drawn as a negative block.
///
/// The shape of a card with nothing in it: no fill, a faint dashed edge, and
/// the hours it runs between where a card keeps its own. It is as tall as
/// the time it covers, so an empty evening looks long, and a faint line
/// crosses it at every full hour, which is the only grid the day has. Where
/// there are blocks the blocks say the time themselves.
///
/// It is somewhere a card can be dropped, and lights up while one is aimed
/// at it. While one is, [preview] is where it would land, drawn inside the
/// room as a solid block with its hours, so the drop can be read before the
/// finger comes off.
///
/// It is also somewhere to tap, which writes something down at that hour.
/// Each hour of it answers a tap with its own faint ripple, so empty room
/// reads as hours that can be used and not only as a gap. The first part,
/// up to the first full hour, writes down something flexible that starts no
/// earlier than the room does. Every hour after it writes down something
/// fixed at that hour.
/// {@endtemplate}
class FreeStretch extends StatelessWidget {
  /// {@macro free_stretch}
  const FreeStretch({
    required this.slot,
    this.targeted = false,
    this.preview,
    this.onTap,
    super.key,
  });

  /// The room.
  final FreeSlot slot;

  /// Whether a card in the air would land here.
  final bool targeted;

  /// Where the card in the air would land, when it is aimed here.
  final ({DateTime start, DateTime end})? preview;

  /// Called with what a tap asked for: the start of the room, flexible, or a
  /// later hour, fixed.
  final ValueChanged<FreeTap>? onTap;

  @override
  Widget build(BuildContext context) {
    final height = TimelineScale.stretchHeight(slot);
    final lines = TimelineScale.hourLines(slot);
    final landing = preview;

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _StretchPainter(hourLines: lines, targeted: targeted),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (onTap != null)
                for (final band in _bands(lines, height))
                  Positioned(
                    left: 0,
                    right: 0,
                    top: band.top,
                    height: band.bottom - band.top,
                    child: InkWell(
                      onTap: () => onTap!(band.tap),
                      splashColor: AppColors.fillStrong,
                      highlightColor: AppColors.fill,
                    ),
                  ),
              // Drawn over the hours and let through, so a tap on the label
              // is a tap on the hour under it.
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4,
                    vertical: AppSpacing.s3,
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      '${_hhmm(slot.start)}–${_hhmm(slot.end)}',
                      style: AppTypography.label.copyWith(
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                ),
              ),
              if (landing != null) _landing(landing, height),
            ],
          ),
        ),
      ),
    );
  }

  /// The room cut at every hour line, and what a tap on each part asks for.
  ///
  /// The first part is the room itself: something flexible that starts no
  /// earlier than the room does. Every part after it starts on a full hour,
  /// and a tap there is something fixed at that hour. A first part shorter
  /// than a quarter of an hour is too thin to hit, so it runs on into the
  /// hour after it.
  List<({double top, double bottom, FreeTap tap})> _bands(
    List<double> lines,
    double height,
  ) {
    final from = slot.earliest;
    final hours = <({double y, DateTime at})>[
      for (final (index, y) in lines.indexed)
        if (y > 0 && y < height)
          (
            y: y,
            at: DateTime(
              from.year,
              from.month,
              from.day,
              from.hour + 1 + index,
            ),
          ),
    ];
    if (hours.isNotEmpty &&
        hours.first.at.difference(from).inMinutes < TimelineScale.step) {
      hours.removeAt(0);
    }

    final edges = [0.0, for (final hour in hours) hour.y, height];

    return [
      for (var i = 0; i < edges.length - 1; i++)
        (
          top: edges[i],
          bottom: edges[i + 1],
          tap: (from: from, fixedAt: i == 0 ? null : hours[i - 1].at),
        ),
    ];
  }

  /// The block as it would sit here, to the same scale as the room.
  Widget _landing(({DateTime start, DateTime end}) landing, double height) {
    final top = TimelineScale.offsetOf(slot, landing.start, height);
    final bottom = TimelineScale.offsetOf(slot, landing.end, height);
    // Never so thin its hours cannot be read, and never past the room.
    final tall = (bottom - top).clamp(AppSpacing.s8, height);
    final at = (top + tall > height ? height - tall : top).clamp(0.0, height);

    return Positioned(
      left: 0,
      right: 0,
      top: at,
      height: tall,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.fillStrong,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_hhmm(landing.start)}–${_hhmm(landing.end)}',
              style: AppTypography.labelStrong.copyWith(color: AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }

  static String _hhmm(DateTime at) {
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }
}

/// The dashed edge, the hour lines, and the fill while a card is aimed here.
class _StretchPainter extends CustomPainter {
  const _StretchPainter({required this.hourLines, required this.targeted});

  final List<double> hourLines;
  final bool targeted;

  static const _dash = 4.0;
  static const _space = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppSpacing.chipRadius),
    );

    if (targeted) canvas.drawRRect(shape, Paint()..color = AppColors.fill);

    final edge = Paint()
      ..color = AppColors.ink3.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    _dashed(canvas, Path()..addRRect(shape.deflate(0.5)), edge);

    final hour = Paint()
      ..color = AppColors.ink3.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (final y in hourLines) {
      if (y <= 0 || y >= size.height) continue;
      _dashed(
        canvas,
        Path()
          ..moveTo(AppSpacing.s4, y)
          ..lineTo(size.width - AppSpacing.s4, y),
        hour,
      );
    }
  }

  static void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _dash + _space) {
        canvas.drawPath(metric.extractPath(at, at + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StretchPainter old) =>
      old.targeted != targeted || old.hourLines.length != hourLines.length;
}
