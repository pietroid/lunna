import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/format.dart';
import 'package:timeline/src/widgets/timeline_scale.dart';

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
/// It is also somewhere to tap, which writes something down at that hour,
/// flexible like everything. Each hour of it answers a tap with its own faint
/// ripple, so empty room reads as hours that can be used and not only as a
/// gap. The first part, up to the first full hour, writes down at the start
/// of the room; every hour after it at that hour. Between two blocks, when
/// what is left from that hour to the next block is short
/// ([fillsWithin] or less), what is written down is as long as all of it.
///
/// Every stretch also carries a small +, and its hours on the right, both
/// stuck to the top of the part of it in sight ([stickBelow] under the top
/// of the list), so a long empty evening scrolled deep into still says
/// where it is. The hours run from the first in sight, which is where the
/// + writes something down.
/// {@endtemplate}
class FreeStretch extends StatelessWidget {
  /// {@macro free_stretch}
  const FreeStretch({
    required this.slot,
    this.targeted = false,
    this.preview,
    this.onTap,
    this.stickBelow = 0,
    super.key,
  });

  /// The room.
  final FreeSlot slot;

  /// Whether a card in the air would land here.
  final bool targeted;

  /// Where the card in the air would land, when it is aimed here.
  final ({DateTime start, DateTime end})? preview;

  /// Called with where a tap asked for: the start of the room, or a later
  /// full hour, and how long, when that is the rest of a short room.
  final ValueChanged<Placement>? onTap;

  /// How far under the top of the list the + stops, so it stays clear of
  /// what is pinned there.
  final double stickBelow;

  /// The longest room between two blocks that a tap fills whole: the usual
  /// length, and the little that would be left over after it.
  static const fillsWithin = Duration(minutes: 45);

  /// What a tap at [at] writes down.
  Placement placementAt(DateTime at) {
    final left = slot.latestStart(0).difference(at);
    final fills =
        slot.beforeBlock && left > Duration.zero && left <= fillsWithin;

    return Placement.at(at, minutes: fills ? left.inMinutes : null);
  }

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
                      onTap: () => onTap!(placementAt(band.tap)),
                      splashColor: AppColors.fillStrong,
                      highlightColor: AppColors.fill,
                    ),
                  ),
              Positioned.fill(
                child: _Sticky(
                  stickBelow: stickBelow,
                  label: (dy) =>
                      '${hhmm(dy <= 0 ? slot.start : _hourAt(dy, height))}'
                      '–${hhmm(slot.end)}',
                  onAdd: onTap == null || landing != null
                      ? null
                      : (dy) => onTap!(placementAt(_hourAt(dy, height))),
                ),
              ),
              if (landing != null) _landing(landing, height),
            ],
          ),
        ),
      ),
    );
  }

  /// The room cut at every hour line, and the hour a tap on each part asks
  /// for.
  ///
  /// The first part is the start of the room. Every part after it starts on
  /// a full hour, and a tap there is that hour. A first part shorter than a
  /// quarter of an hour is too thin to hit, so it runs on into the hour after
  /// it.
  List<({double top, double bottom, DateTime tap})> _bands(
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
        hours.first.at.difference(from).inMinutes < _thinnest) {
      hours.removeAt(0);
    }

    final edges = [0.0, for (final hour in hours) hour.y, height];

    return [
      for (var i = 0; i < edges.length - 1; i++)
        (
          top: edges[i],
          bottom: edges[i + 1],
          tap: i == 0 ? from : hours[i - 1].at,
        ),
    ];
  }

  /// The hour [dy] down the room falls on, moved on to the next five
  /// minutes, and never so late nothing fits after it.
  DateTime _hourAt(double dy, double height) {
    if (dy <= 0) return slot.earliest;
    final at = TimelineScale.timeAt(slot, dy, height);
    final minutes =
        (at.minute / TimelineScale.step).ceil() * TimelineScale.step;
    final stepped = DateTime(at.year, at.month, at.day, at.hour, minutes);
    final latest = slot.latestStart(TimelineScale.step);

    return stepped.isAfter(latest) ? latest : stepped;
  }

  /// The shortest first part a tap can still hit, in minutes.
  static const _thinnest = 15;

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
              '${hhmm(landing.start)}–${hhmm(landing.end)}',
              style: AppTypography.labelStrong.copyWith(color: AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// The + of a stretch and its hours: a small circle a shade off the room on
/// the left, the hours on the right, stuck to the top of the part of the
/// room in sight.
///
/// They are placed while the list is painted, from where the room is at
/// that moment, so they move with the scroll in the same frame rather than
/// catching up after it. The hours are written again once a frame is done,
/// when the first in sight has changed.
class _Sticky extends StatefulWidget {
  const _Sticky({
    required this.stickBelow,
    required this.label,
    this.onAdd,
  });

  /// The circle.
  static const double dot = AppSpacing.s6;

  /// What answers a tap, around the circle, and the band both sit in.
  static const double size = AppSpacing.tapTarget;

  final double stickBelow;

  /// The hours, for the + this far down the room.
  final String Function(double dy) label;

  /// Called with how far down the room the + was when it was tapped. No +
  /// without it.
  final ValueChanged<double>? onAdd;

  @override
  State<_Sticky> createState() => _StickyState();
}

class _StickyState extends State<_Sticky> {
  /// How far down the room they are drawn, as of the last paint.
  double _dy = 0;

  late final _label = ValueNotifier<String>(widget.label(0));
  bool _relabelling = false;

  @override
  void didUpdateWidget(_Sticky old) {
    super.didUpdateWidget(old);
    _label.value = widget.label(_dy);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  /// How far down the room they belong: the top of what is in sight, and
  /// never past the end of the room.
  double _place(Size room) {
    final box = context.findRenderObject() as RenderBox?;
    final list = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box == null || !box.attached || list is! RenderBox) return 0;

    final top = list.localToGlobal(Offset.zero).dy + widget.stickBelow;
    final dy = top - box.localToGlobal(Offset.zero).dy;
    final last = (room.height - _Sticky.size).clamp(0.0, room.height);
    _dy = dy.clamp(0.0, last);
    _relabelSoon();

    return _dy;
  }

  /// Writes the hours again after this frame, if they changed. Nothing can
  /// be rebuilt while painting.
  void _relabelSoon() {
    if (_relabelling || widget.label(_dy) == _label.value) return;
    _relabelling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _relabelling = false;
      if (mounted) _label.value = widget.label(_dy);
    });
  }

  @override
  Widget build(BuildContext context) {
    final onAdd = widget.onAdd;

    return Flow(
      delegate: _Stick(
        place: _place,
        scroll: Scrollable.maybeOf(context)?.position,
      ),
      children: [
        // Drawn over the hours and let through, so a tap on the label is a
        // tap on the hour under it.
        IgnorePointer(
          child: ValueListenableBuilder<String>(
            valueListenable: _label,
            builder: (context, label, _) => Text(
              label,
              style: AppTypography.label.copyWith(color: AppColors.ink3),
            ),
          ),
        ),
        if (onAdd != null)
          Semantics(
            button: true,
            label: context.l10n.timelineAdd,
            child: SizedBox.square(
              dimension: _Sticky.size,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onAdd(_dy),
                child: Center(
                  child: Container(
                    width: _Sticky.dot,
                    height: _Sticky.dot,
                    decoration: const BoxDecoration(
                      color: AppColors.fill,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const AppIcon(
                      iconData: AppIcons.plus,
                      size: AppSpacing.s4,
                      color: AppColors.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Paints the hours (first child) on the right and the + (second, if any) on
/// the left, as far down as [place] says, again on every scroll.
class _Stick extends FlowDelegate {
  _Stick({required this.place, this.scroll}) : super(repaint: scroll);

  final double Function(Size room) place;
  final ScrollPosition? scroll;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      constraints.loosen();

  @override
  void paintChildren(FlowPaintingContext context) {
    final room = context.size;
    final dy = place(room);

    final label = context.getChildSize(0)!;
    context.paintChild(
      0,
      transform: Matrix4.translationValues(
        room.width - AppSpacing.s4 - label.width,
        dy + (_Sticky.size - label.height) / 2,
        0,
      ),
    );
    if (context.childCount > 1) {
      context.paintChild(1, transform: Matrix4.translationValues(0, dy, 0));
    }
  }

  @override
  bool shouldRepaint(_Stick old) => old.scroll != scroll;
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
