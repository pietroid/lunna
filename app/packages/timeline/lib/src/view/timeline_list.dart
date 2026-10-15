import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/bloc/timeline_bloc.dart';
import 'package:timeline/src/bloc/timeline_mode_cubit.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/widgets.dart';

/// A place a card can land, and where it is on the screen.
///
/// Most places are an edge of a card, above it or below it. The rest are free
/// stretches of the day, which carry the stretch itself, measured as it would
/// be with the dragged card lifted out, because landing in one asks for that
/// stretch. A stretch also carries how far down the screen it runs and which
/// row on screen it is, because a finger anywhere inside it is aiming at it,
/// however tall an empty evening has made it, and the stretch as it is drawn,
/// because that is what turns a height on the screen into an hour.
typedef _Anchor = ({
  int index,
  double y,
  FreeSlot? slot,
  FreeSlot? shown,
  ({double top, double bottom})? area,
  _Row? row,
});

/// Where a card would sit if it were let go now.
typedef _Span = ({DateTime start, DateTime end});

/// One row of the day: a card, or a stretch with nothing on it and the
/// heading it is drawn under.
typedef _Entry = ({TimelineEvent? card, _Room? room});

/// The heading a row is drawn under: null for Agora, otherwise the day, at
/// midnight.
typedef _Heading = DateTime?;

/// A free stretch as it is drawn, under one heading.
///
/// The room from now until the next block is drawn twice: as the break under
/// Agora, and as the empty room that opens Ainda hoje. Both are the same
/// stretch, and two places to drop: the break is now, and the room is its
/// hours.
typedef _Room = ({FreeSlot slot, _Heading heading});

/// Which drawn stretch a row is: where it starts, and under which heading.
typedef _Row = (DateTime, _Heading);

/// A solved card on its way off the screen, frozen as it was let go.
typedef _Flying = ({
  TimelineEvent card,
  double top,
  double height,
  double dx,
});

/// One row as it was drawn, in the order it was drawn: the key it is
/// measured by, the section it belongs to, and what it is.
///
/// What the screen reads after every scroll to know which day is at the
/// top, where the + goes and where the button at the foot of the app
/// writes. `room` is set for a free stretch, `card` for a card, and
/// `heading` for the line that opens its section.
typedef _Drawn = ({
  GlobalKey key,
  Object? section,
  bool heading,
  _Room? room,
  TimelineEvent? card,
});

/// The heading pinned over the top of the list, and how far the next one
/// has pushed it up.
typedef _Pin = ({String label, double dy});

/// The section of the backlog, in the list.
const Object _backlog = #backlog;

/// The section of every task with an hour, in the list: one stage, not cut
/// into days.
const Object _soon = #soon;

/// The section of a row that is not under any heading: the failure line.
const Object _loose = #loose;

/// {@template timeline_list}
/// The day: one list in clock order, cut into days by the clock.
///
/// Drawn one of two ways, [mode]. The calendar is everything, events and
/// tasks, as tall as its time, a day after another for as far as it is
/// scrolled: reaching the end of it asks for another week. The list is the
/// tasks alone, each as tall as it needs, in two stages that are always
/// drawn, empty or not. Fazer em breve is the queue and the tasks that keep
/// an hour, in the order of their hours, in one run that is not cut into
/// days. Depois
/// eu priorizo is the backlog: an order and a length, no hours, and nothing
/// the calendar draws. Both stages are the same list to a drag, so a task
/// goes from one to the other the way it goes up or down either. Each stage
/// ends in a +, which writes something down at its end.
///
/// The headings are not containers. Every card has an hour, the hour says
/// which heading it falls under, and a drop is a place in the one list
/// underneath all of them. The heading of whatever is at the top of the
/// screen stays pinned there while it scrolls, so the day being looked at is
/// always named, and once Agora is out of sight a chip brings it back.
///
/// One [Listener] over the whole thing owns every gesture: a tap opens a
/// block, a press held for a moment picks its card up, and the card then
/// follows the finger while the rest of the list opens a place for it. The
/// place is whichever one is nearest, so the card lands wherever it is let go
/// rather than only on something it managed to hit. Held near the top or
/// the bottom of the list, the card carries the list with it, so a task
/// goes to another day by being taken there.
///
/// Agora is always drawn, as it always was: what is running, or the break
/// with its line. Let go there, a task is begun now. Below it the day reads
/// like a calendar: every card is as tall as its time, near enough, and the
/// free stretches between them are drawn as empty room just as tall. Room of
/// ten minutes or less is not drawn, and neither is the pause between two
/// blocks.
///
/// A card let go over a stretch lands where it was let go, on the five
/// minutes nearest, sticking to the block above or below when it is close.
/// The room draws it there while it is aimed at, hours and all, so the drop
/// is read before it happens. A task that lands so keeps that hour, and the
/// queue flows around it. One too long for the room asks whether to cut it
/// to fit, and stays where it was on a no. A card let go between two cards
/// takes that place in the queue, or, when the card above it keeps an hour
/// of its own, the hour right after it. A fixed card only lands in empty
/// room, because its hour is the point of it.
///
/// A tap on empty room writes something down at that hour, flexible like
/// everything: at the start of the room in its first part, and on the full
/// hour in any hour after it.
///
/// A drag picks an axis as soon as it starts moving and keeps it. Up and down
/// reorders; right carries the card out of the day and marks it done, and
/// left deletes it once the user has confirmed.
/// Nothing does both at once, because a card that slid sideways while
/// being reordered would be asking which of the two the finger meant, and the
/// finger has already said.
///
/// The list does not re-lay-out while a card is up. The cards that move are
/// moved by a transform over a layout that is measured at rest, so the place
/// being aimed at cannot shift out from under the finger that is aiming at
/// it. When the list scrolls under the card, it is measured again.
/// {@endtemplate}
class TimelineList extends StatefulWidget {
  /// {@macro timeline_list}
  const TimelineList({
    required this.onCardTap,
    this.onWriteDown,
    this.aim,
    this.mode = TimelineMode.calendar,
    super.key,
  });

  /// How the day is drawn.
  final TimelineMode mode;

  /// Called with the block whose card was tapped.
  ///
  /// The whole card rather than an id, so the screen that opens has the
  /// block to draw before it has asked for anything.
  final ValueChanged<TimelineEvent> onCardTap;

  /// Called with where something is to be written down: an hour of empty
  /// room that was tapped, the hour a + is on, or the section a + ends.
  final ValueChanged<Placement>? onWriteDown;

  /// Where the button at the foot of the app writes, which this keeps
  /// pointed at the day on screen.
  final TimelineAim? aim;

  @override
  State<TimelineList> createState() => _TimelineListState();
}

class _TimelineListState extends State<TimelineList> {
  /// How long a finger has to stay down before a card comes up with it.
  static const _holdDuration = Duration(milliseconds: 280);

  /// Moving further than this before the hold fires means the list is being
  /// scrolled, not a card picked up.
  static const _slop = 8.0;

  /// How far a card has to move before the drag picks its axis.
  static const _axisSlop = 12.0;

  /// How far sideways a card has to be carried before letting it go finishes
  /// the block rather than dropping it back into the list.
  static const _solveTravel = 96.0;

  /// How close to the top of the list a card has to be held for the list
  /// to scroll up under it.
  static const _edgeTop = 72.0;

  /// The same at the bottom, which is taller: the bar at the foot of the
  /// app is drawn over the list.
  static const _edgeBottom = 160.0;

  /// How far a card has to be carried towards an edge before that edge
  /// scrolls the list.
  static const _edgeLead = 24.0;

  /// How often the list scrolls under a held card: once a frame.
  static const _frame = Duration(milliseconds: 16);

  /// The furthest the list scrolls under a held card in one frame.
  static const _edgeSpeed = 16.0;

  /// The height of the heading pinned over the top of the list.
  static const _pinHeight = 40.0;

  /// The section itself, for turning the pointer into local coordinates.
  final GlobalKey _sectionKey = GlobalKey();

  /// The scrolling list, for where its top and bottom are on screen.
  final GlobalKey _listKey = GlobalKey();

  final ScrollController _scroll = ScrollController();

  /// One key per card, so the laid-out list can be measured.
  final _cardKeys = <String, GlobalKey>{};

  /// One key per free stretch on screen, by where it starts and the heading
  /// it is drawn under.
  final _freeKeys = <_Row, GlobalKey>{};

  /// One key per heading, and per + that ends a section of the list.
  final _headingKeys = <Object?, GlobalKey>{};
  final _addKeys = <Object?, GlobalKey>{};

  /// The line between the two stages of the list, which is where the queue
  /// ends and the backlog begins.
  final GlobalKey _dividerKey = GlobalKey();

  /// The free stretches drawn in the last build.
  List<_Room> _shownRooms = const [];

  /// Every row drawn in the last build, in order.
  List<_Drawn> _drawn = const [];

  /// The heading pinned over the top of the list, when one is.
  final _pinned = ValueNotifier<_Pin?>(null);

  /// Whether Agora is out of sight, which shows the chip that brings it back.
  final _away = ValueNotifier<bool>(false);

  /// The free stretch the card in the air is over, when it is over one.
  ///
  /// Kept apart from [_target] because nothing opens up for it: the stretch
  /// is already the room, and it lights up instead.
  FreeSlot? _aimedSlot;

  /// Which stretch on screen [_aimedSlot] is, so that one lights up.
  _Row? _aimedRow;

  /// Where the card in the air would sit in [_aimedSlot], drawn there before
  /// it is let go.
  _Span? _landing;

  /// One key per row of buttons on a running card, so a tap on a button is
  /// left to the button rather than read as a tap on the card.
  final _actionKeys = <String, GlobalKey>{};

  Timer? _hold;
  Offset? _down;

  /// Where the finger is, while a card is up.
  Offset? _finger;

  /// The list scrolling under a card held near its edge.
  Timer? _edgeTimer;
  double _edgeVelocity = 0;

  /// The card the finger is on, whether or not it has been picked up yet.
  String? _pressed;

  /// The card in the air.
  String? _dragging;

  /// Where the card came from, and what it measured, taken once at pick-up.
  Rect? _originRect;
  double _slotHeight = 0;

  /// The dragged card's place in the list, taken once at pick-up.
  int _originIndex = 0;

  /// Every place the card could land, measured at pick-up and again
  /// whenever the list scrolls under it.
  List<_Anchor> _anchors = const [];

  /// The place it would land, and how far the finger has come since pick-up.
  int? _target;
  Offset _travel = Offset.zero;

  /// Which way this drag is going, decided once and then kept.
  Axis? _axis;

  /// The card thrown off the day after being finished, still on screen while
  /// it plays out.
  _Flying? _flight;

  @override
  void dispose() {
    _hold?.cancel();
    _edgeTimer?.cancel();
    _scroll.dispose();
    _pinned.dispose();
    _away.dispose();
    super.dispose();
  }

  TimelineState get _state => context.read<TimelineBloc>().state;

  bool get _isList => widget.mode == TimelineMode.list;

  /// Everything drawn, in the order it is drawn: everything in the
  /// calendar; in the list, the queue, then the line between the stages as
  /// a null, then the backlog.
  ///
  /// The line takes a place of its own so that the end of the queue and the
  /// top of the backlog are two different places to drop, even though no
  /// card sits between them.
  List<TimelineEvent?> get _slots =>
      _isList ? [..._state.tasks, null, ..._state.backlog] : _state.cards;

  /// Where [id] sits in what is drawn, or -1.
  int _indexOf(String id) => _slots.indexWhere((card) => card?.id == id);

  /// Where a drop at [index] in what is drawn lands: a place in the list of
  /// tasks, or in the backlog, which are the only orders the server keeps.
  ///
  /// In the list, everything above the line is the tasks and everything
  /// below it the backlog. The calendar counts the tasks above the drop that
  /// the list draws too, and skips the events and the days of routines the
  /// list leaves out, because a place is counted on the list.
  ({int index, bool backlog}) _placeOf(String id, int index) {
    final rest = _slots.where((card) => card?.id != id).toList();
    if (_isList) {
      final line = rest.indexOf(null);
      return index <= line
          ? (index: index, backlog: false)
          : (index: index - line - 1, backlog: true);
    }

    final listed = {for (final card in _state.tasks) card.id};
    return (
      index: rest.take(index).where((card) => listed.contains(card?.id)).length,
      backlog: false,
    );
  }

  /// The card right above a drop at [index], with [id] lifted out, when it
  /// is one whose hour a drop below it should follow: an event, or a task
  /// that keeps an hour of its own. Its place in the queue says nothing about
  /// where it is, so the drop lands on the hour after it instead.
  TimelineEvent? _hourAbove(String id, int index) {
    if (index == 0) return null;

    final rest = _slots.where((card) => card?.id != id).toList();
    final above = rest[index - 1];
    if (above == null || above.isBacklog) return null;

    return above.isAnchored || above.keepsHour ? above : null;
  }

  /// How far the card in the air has come towards being finished, 0 to 1.
  ///
  /// Always zero on a drag that went up or down, so a reorder never shows the
  /// check and never has to be read as anything but a reorder.
  double get _solveProgress {
    if (_dragging == null || _axis != Axis.horizontal) return 0;

    return (_travel.dx.abs() / _solveTravel).clamp(0.0, 1.0);
  }

  /// Whether letting go now would finish the block instead of dropping it.
  bool get _armedSolve => _solveProgress == 1;

  GlobalKey _cardKey(String id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  /// The global rect a key has been laid out into, if it is on screen.
  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;

    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The id of the card under [global], if there is one that can be touched.
  ///
  /// A meeting Lunna did not book is drawn in the list and is not the app's
  /// to move: it goes where the calendar says. The gesture passes straight
  /// through it.
  String? _cardAt(Offset global) {
    for (final entry in _cardKeys.entries) {
      if (_rectOf(entry.value)?.contains(global) ?? false) {
        return (_state.byId(entry.key)?.isInteractive ?? false)
            ? entry.key
            : null;
      }
    }

    return null;
  }

  /// Measures every place [id] could go, in the layout as it stands.
  ///
  /// A list of n cards has n + 1 places: above each card, and below the last.
  /// Each is measured at both edges it touches, the top of the card after it
  /// and the bottom of the card before it, because an empty stretch can sit
  /// between the two and push them far apart. They are measured with [id]
  /// taken out, because that is the list a drop is applied to, and from the
  /// resting layout: the keys sit outside the transforms that move cards out
  /// of the way, so where a card was laid out is where it is measured.
  ///
  /// A card scrolled out of the list's reach has no rect and no edges, but
  /// still counts, so the places on either side of it keep their numbers.
  List<_Anchor> _measure(String id) {
    final rest = _slots.where((card) => card?.id != id).toList();
    final anchors = <_Anchor>[];

    for (var index = 0; index < rest.length; index++) {
      // The line between the stages is measured like a card, so dropping
      // just above it ends the queue and just below it heads the backlog,
      // whichever of the two is empty.
      final card = rest[index];
      final rect = _rectOf(card == null ? _dividerKey : _cardKey(card.id));
      if (rect == null) continue;

      anchors
        ..add(_edge(index, rect.top))
        ..add(_edge(index + 1, rect.bottom));
    }
    if (anchors.isEmpty) anchors.addAll([?_centerOf(id)]);
    if (_isList) return anchors;

    // The stretches are priced with the card lifted out, because that is the
    // day the drop lands in: a card that sat right beside a gap makes the gap
    // bigger by leaving it. The break under Agora is now, whatever was
    // lifted, so it is taken as drawn.
    final lifted = TimelinePlan.freeSlots(
      rest.nonNulls.toList(),
      days: _state.days,
      workDay: _state.workDay,
    );
    for (final room in _shownRooms) {
      final shown = room.slot;
      final rect = _rectOf(_freeKey(_rowOf(room)));
      if (rect == null) continue;

      final slot = room.heading == null
          ? shown
          : lifted.where((it) => it.contains(shown.start)).firstOrNull;
      if (slot == null) continue;

      anchors.add((
        index: slot.index,
        y: rect.center.dy,
        slot: slot,
        shown: shown,
        area: (top: rect.top, bottom: rect.bottom),
        row: _rowOf(room),
      ));
    }

    return anchors;
  }

  static _Anchor _edge(int index, double y) =>
      (index: index, y: y, slot: null, shown: null, area: null, row: null);

  _Anchor? _centerOf(String id) {
    final rect = _rectOf(_cardKey(id));
    return rect == null ? null : _edge(0, rect.center.dy);
  }

  GlobalKey _freeKey(_Row row) => _freeKeys.putIfAbsent(row, GlobalKey.new);

  GlobalKey _headingKey(Object? section) =>
      _headingKeys.putIfAbsent(section, GlobalKey.new);

  GlobalKey _addKey(Object? section) =>
      _addKeys.putIfAbsent(section, GlobalKey.new);

  static _Row _rowOf(_Room room) => (room.slot.start, room.heading);

  /// The card in the air, when there is one.
  TimelineEvent? get _draggedCard {
    final id = _dragging;
    return id == null ? null : _state.byId(id);
  }

  /// The place a drop at [global] lands on.
  ///
  /// A finger inside a free stretch is aiming at that stretch, wherever in it
  /// the finger is. Anywhere else it is aiming at the nearest edge of a card,
  /// unless the card is fixed: a fixed card keeps its hour between two cards,
  /// so only empty room is somewhere for it to go.
  _Anchor? _nearest(Offset global) {
    if (_anchors.isEmpty) return null;

    final inside = _anchors.where((anchor) {
      final area = anchor.area;
      return area != null && global.dy >= area.top && global.dy < area.bottom;
    }).firstOrNull;
    if (inside != null) return inside;
    if (_draggedCard?.isAnchored ?? false) return null;

    return _anchors.reduce(
      (a, b) => (global.dy - a.y).abs() <= (global.dy - b.y).abs() ? a : b,
    );
  }

  /// Points the card in the air at [anchor]: a place between two cards opens
  /// up, a free stretch lights up.
  void _aim(_Anchor? anchor) {
    _target = anchor?.slot == null ? anchor?.index : null;
    _aimedSlot = anchor?.slot;
    _aimedRow = anchor?.row;
    _landing = anchor == null ? null : _landingFor(anchor);
  }

  /// Where the card in the air would sit if it were let go over [anchor].
  ///
  /// Where its top edge is, on the five minutes nearest, sticking to either
  /// end of the room when it is close. Under Agora the room is not drawn to
  /// scale, and it is now anyway, so it goes to the start. A card too long
  /// for the room is shown cut to what fits, which is what the drop will
  /// offer.
  _Span? _landingFor(_Anchor anchor) {
    final slot = anchor.slot;
    final card = _draggedCard;
    if (slot == null || card == null) return null;

    var start = slot.earliest;
    final shown = anchor.shown;
    final area = anchor.area;
    final origin = _originRect;
    if (shown != null &&
        area != null &&
        origin != null &&
        anchor.row?.$2 != null) {
      final aimed = TimelineScale.timeAt(
        shown,
        origin.top + _travel.dy - area.top,
        area.bottom - area.top,
      );
      start = TimelineScale.landingIn(slot, aimed, card.durationMinutes);
    }

    final room = slot.end.difference(start).inMinutes;
    final minutes = card.durationMinutes <= room ? card.durationMinutes : room;

    return (start: start, end: start.add(Duration(minutes: minutes)));
  }

  /// How far a row with [before] cards above it has to move to open the
  /// place the card in the air is aiming at.
  ///
  /// One card leaves and one card arrives, and a row moves by however many of
  /// those two happened above it. It works for a heading as well as a card,
  /// because a heading is only a row that happens to have no card in it: what
  /// moves either one is how many cards crossed the line it sits on.
  double _shift(int before) {
    final target = _target;
    if (target == null) return 0;

    final left = _originIndex < before ? 1 : 0;
    final arrived = target <= before - left ? 1 : 0;

    return (arrived - left) * _slotHeight;
  }

  void _onDown(PointerDownEvent event) {
    final onButton = _actionKeys.values.any(
      (key) => _rectOf(key)?.contains(event.position) ?? false,
    );
    if (onButton) return;

    _down = event.position;
    final id = _cardAt(event.position);
    if (id == null) return;

    setState(() => _pressed = id);
    _hold = Timer(_holdDuration, () => _lift(id));
  }

  void _lift(String id) {
    final rect = _rectOf(_cardKey(id));
    final origin = _indexOf(id);
    if (rect == null || origin == -1) return;

    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _dragging = id;
      _axis = null;
      _originIndex = origin;
      _originRect = rect;
      _slotHeight = rect.height + AppSpacing.s1;
      _anchors = _measure(id);
      _travel = Offset.zero;
      _finger = _down;
      _aim(_nearest(_down!));
    });
  }

  void _onMove(PointerMoveEvent event) {
    final down = _down;
    if (down == null) return;

    if (_dragging != null) {
      _finger = event.position;
      _follow(event.position - down);
      _edgeScrollFor(event.position);
      return;
    }

    // Past the slop the gesture belongs to the list, which scrolls: the hold
    // is called off and the card under the finger stops looking pressed.
    if ((event.position - down).distance > _slop) _cancel();
  }

  /// Moves the card in the air by [travel] since pick-up, and aims it.
  void _follow(Offset travel) {
    final wasArmed = _armedSolve;
    final wasLanding = _landing?.start;
    final wasTarget = _target;
    final finger = _finger;

    setState(() {
      _axis = _axisFor(travel);
      // The card moves along the axis the drag chose and not a pixel along
      // the other one, so a reorder cannot drift sideways into finishing
      // the block and a card being carried out cannot drift into the list.
      _travel = _axis == Axis.horizontal
          ? Offset(travel.dx, 0)
          : Offset(0, travel.dy);
      // A card on its way out of the timeline is not aiming at a place, so
      // nothing opens one for it: the list stays where it is and the only
      // thing left to read is the check.
      _aim(
        _axis == Axis.horizontal || finger == null ? null : _nearest(finger),
      );
    });

    // One tick as the gesture changes what letting go will do, and only on
    // the change: arming the check, a new place, a new five minutes.
    if (_armedSolve != wasArmed ||
        _target != wasTarget ||
        (_landing != null && _landing?.start != wasLanding)) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  /// Scrolls the list under a card held near its top or bottom.
  ///
  /// The nearer the edge, the faster, so a card can be eased into the next
  /// hour or carried across a week. Every step measures the list again,
  /// because the places the card can land have moved under it.
  void _edgeScrollFor(Offset finger) {
    final view = _rectOf(_listKey);
    if (view == null || _axis == Axis.horizontal) {
      _stopEdge();
      return;
    }

    // Only once the card has been carried towards the edge: one picked up
    // near the bottom does not set the list off before it has moved.
    final travel = finger.dy - (_down?.dy ?? finger.dy);
    final top = travel < -_edgeLead ? view.top + _edgeTop - finger.dy : 0.0;
    final bottom = travel > _edgeLead
        ? finger.dy - (view.bottom - _edgeBottom)
        : 0.0;
    _edgeVelocity = top > 0
        ? -_edgeSpeed * (top / _edgeTop).clamp(0.0, 1.0)
        : bottom > 0
        ? _edgeSpeed * (bottom / _edgeTop).clamp(0.0, 1.0)
        : 0;

    if (_edgeVelocity == 0) {
      _stopEdge();
    } else {
      _edgeTimer ??= Timer.periodic(_frame, _edgeStep);
    }
  }

  void _edgeStep(Timer timer) {
    final id = _dragging;
    final down = _down;
    if (!mounted || id == null || down == null || !_scroll.hasClients) {
      _stopEdge();
      return;
    }

    final position = _scroll.position;
    final next = (position.pixels + _edgeVelocity).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return;

    _scroll.jumpTo(next);
    // The rows that scrolled in are only laid out on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dragging != id) return;

      _anchors = _measure(id);
      _follow((_finger ?? down) - down);
    });
  }

  void _stopEdge() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
    _edgeVelocity = 0;
  }

  /// The axis this drag is on: whichever way it went first, and then that one
  /// for the rest of the drag.
  ///
  /// Undecided counts as vertical, so the card is already following the finger
  /// up the list before the gesture has travelled far enough to be sure. A
  /// reorder is much the commoner of the two, and guessing it costs nothing
  /// when it is wrong: the first twelve pixels of a sideways drag simply do
  /// not move the card.
  Axis? _axisFor(Offset travel) {
    if (_axis != null || travel.distance < _axisSlop) return _axis;

    return travel.dx.abs() > travel.dy.abs() ? Axis.horizontal : Axis.vertical;
  }

  void _onUp(PointerUpEvent event) {
    final id = _dragging;
    final target = _target;
    final slot = _aimedSlot;
    final row = _aimedRow;
    final landing = _landing;
    final pressed = _pressed;
    final solving = _armedSolve;
    final travel = _travel;
    final rect = _originRect;
    // A timer still ticking means the hold never fired, so this was a tap.
    final tapped = _hold?.isActive ?? false;
    final card = id == null ? null : _state.byId(id);
    final origin = _originIndex;
    _cancel();

    if (id == null) {
      if (tapped && pressed != null) {
        final card = _state.byId(pressed);
        if (card != null) widget.onCardTap(card);
      }
      return;
    }

    // Let go out to the right and the block is done: it leaves the day, the
    // hour goes back, and the card is thrown after it. Out to the left is a
    // delete, which asks first because it cannot be taken back.
    if (solving && card != null && rect != null) {
      if (travel.dx.isNegative) {
        unawaited(_delete(card));
      } else {
        _finish(id, card, rect, travel);
      }
      return;
    }

    // Let go on the break under Agora, it is now.
    if (slot != null && card != null && row != null && row.$2 == null) {
      _now(card);
      return;
    }

    if (slot != null && card != null) {
      unawaited(_dropInto(card, slot, landing?.start ?? slot.earliest));
      return;
    }

    if (target == null || card == null) return;

    // A card put back exactly where it came from is not a move, and does not
    // need to be written anywhere. The target counts the list with the card
    // already lifted out, which is the same list the server splices it into,
    // so its old place is just its old index.
    if (target == origin) return;

    // Let go at the very top of the day, above whatever was first, is the
    // user saying they are doing it now. Let go in an empty queue it is only
    // next, and waits to be begun like any first task.
    final place = _placeOf(id, target);
    final ahead = !_isList || _state.tasks.any((it) => it.id != id);
    final above = place.backlog ? null : _hourAbove(id, target);
    context.read<TimelineBloc>().add(
      EventMoved(
        id: id,
        index: place.index,
        backlog: place.backlog,
        start: target == 0 && !place.backlog && ahead,
        // Below something that keeps an hour, the hour after it.
        after: above?.endTime.add(TimelinePlan.gap),
      ),
    );
  }

  /// Puts [card] at the top of the day: a task is begun, which asks first
  /// when something else is running, and a fixed block moves to this minute.
  void _now(TimelineEvent card) {
    final bloc = context.read<TimelineBloc>();
    if (card.isTask) {
      if (card.section == TimelineSection.agora && card.started) return;
      bloc.add(EventMoved(id: card.id, index: 0, start: true));
      return;
    }

    final now = clock.now();
    bloc.add(
      EventEdited(
        card.id,
        startTime: DateTime(now.year, now.month, now.day, now.hour, now.minute),
      ),
    );
  }

  /// Takes a block off the day, and throws its card off screen.
  ///
  /// This is the moment it is finished: everything before it was the gesture
  /// saying what it was about to do. The card is drawn from what was captured
  /// here rather than from the list, because the list has already let go of
  /// it by the time this runs, and everything below it closes up while the
  /// card is still on its way out.
  void _finish(String id, TimelineEvent card, Rect rect, Offset travel) {
    final box = _sectionKey.currentContext?.findRenderObject() as RenderBox?;
    unawaited(HapticFeedback.mediumImpact());

    if (box != null) {
      setState(() {
        _flight = (
          card: card,
          top: box.globalToLocal(rect.topLeft).dy + travel.dy,
          height: rect.height,
          dx: travel.dx,
        );
      });
    }

    context.read<TimelineBloc>().add(EventFinished(id));
  }

  /// Puts [card] into the free stretch [slot], starting at [start].
  ///
  /// A card that fits goes straight in. One that is longer than the stretch
  /// asks whether to cut it to the room there is, pause included, and a no
  /// leaves the day exactly as it was. One let go on the hour it already had
  /// has not moved.
  ///
  /// A task keeps the hour it was let go at, and the queue flows around it.
  /// An event takes that hour, because an hour is all it has.
  Future<void> _dropInto(
    TimelineEvent card,
    FreeSlot slot,
    DateTime start,
  ) async {
    final room = slot.end.difference(start).inMinutes;

    if (start == card.startTime) return;

    if (card.durationMinutes <= room) {
      _place(card, slot, start);
      return;
    }

    // Under five minutes there is nothing worth cutting a block down to.
    if (room < 5) {
      unawaited(HapticFeedback.heavyImpact());
      return;
    }

    if (await confirmShorten(context, card, room)) {
      _place(card, slot, start, room);
    }
  }

  void _place(
    TimelineEvent card,
    FreeSlot slot,
    DateTime start, [
    int? minutes,
  ]) {
    context.read<TimelineBloc>().add(
      card.isTask
          ? EventMoved(
              id: card.id,
              index: _placeOf(card.id, slot.index).index,
              after: start,
              minutes: minutes,
            )
          : EventEdited(card.id, startTime: start, workMinutes: minutes),
    );
  }

  /// Asks, and takes the block off the calendar if the answer was yes.
  Future<void> _delete(TimelineEvent card) async {
    unawaited(HapticFeedback.mediumImpact());
    final bloc = context.read<TimelineBloc>();

    if (await confirmDelete(context, card.title)) {
      bloc.add(EventDeleted(card.id));
    }
  }

  void _cancel() {
    _hold?.cancel();
    _hold = null;
    _down = null;
    _finger = null;
    _stopEdge();
    setState(() {
      _pressed = null;
      _dragging = null;
      _axis = null;
      _originRect = null;
      _anchors = const [];
      _target = null;
      _aimedSlot = null;
      _aimedRow = null;
      _landing = null;
      _travel = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineBloc, TimelineState>(
      builder: (context, state) {
        if (state.isInitialLoad) return const _Loading();

        final dragging = _dragging;
        // What is on screen is only known once it is laid out.
        _surveySoon();

        return Stack(
          key: _sectionKey,
          children: [
            Listener(
              // Translucent, so the list underneath still scrolls whenever
              // the gesture turns out not to be a drag.
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onDown,
              onPointerMove: _onMove,
              onPointerUp: _onUp,
              onPointerCancel: (_) => _cancel(),
              // The list is frozen to the finger for as long as a card is up.
              // The pointer that picked the card up is one the scrollable is
              // still watching, and without this it would drag the list out
              // from under the place the card is aiming at. Only the card's
              // own edges scroll it then.
              child: AbsorbPointer(
                absorbing: dragging != null,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrolled,
                  child: ListView(
                    key: _listKey,
                    controller: _scroll,
                    physics: dragging == null
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s6,
                      0,
                      AppSpacing.s6,
                      // Room under the last card so the bar never covers it.
                      AppSpacing.s16 + AppSpacing.s12,
                    ),
                    children: _rows(state, dragging),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: AppSpacing.s6,
              right: AppSpacing.s6,
              child: _PinnedHeading(
                pin: _pinned,
                away: _away,
                height: _pinHeight,
                onBackToNow: _backToNow,
              ),
            ),
            // The card in the air is drawn over the list rather than in it,
            // so it passes over the cards it is moving between instead of
            // sliding under them.
            if (dragging != null) _lifted(state, dragging),
            if (_flight != null) _flying(_flight!),
          ],
        );
      },
    );
  }

  /// Scrolls back to the top of the day, where Agora is.
  void _backToNow() {
    if (!_scroll.hasClients) return;

    unawaited(
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Keeps up with the scroll: what is pinned, where the + goes, and asks
  /// for another week once the calendar is scrolled near its end.
  ///
  /// The list has every task already, however far ahead, so it never asks.
  bool _onScrolled(ScrollNotification notification) {
    _surveySoon();
    if (notification is! ScrollUpdateNotification) return false;

    final state = _state;
    if (_isList || state.extending || state.isInitialLoad) return false;
    if (state.days >= TimelineState.maxDays) return false;

    if (notification.metrics.extentAfter < _extendWithin) {
      context.read<TimelineBloc>().add(const TimelineExtended());
    }

    return false;
  }

  /// How close to the end of the calendar the next week is asked for: about
  /// a day of empty room, so it has arrived by the time it is reached.
  static const _extendWithin = 1600.0;

  /// Whether a [_survey] is waiting for the end of this frame.
  bool _surveying = false;

  /// Reads what is on screen once this frame is laid out, once however many
  /// times it is asked for. A scroll can be told about in the middle of
  /// laying out, when nothing can be measured yet.
  void _surveySoon() {
    if (_surveying) return;
    _surveying = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _surveying = false;
      _survey();
    });
  }

  /// Reads what is on screen, after a scroll or a build.
  ///
  /// The heading of whatever is at the top is pinned there, pushed up by the
  /// next heading as it arrives. And the button at the foot of the app is
  /// pointed at what is in sight: the first free hour of the first stretch
  /// in sight, or, in the list, the end of the day at the top.
  void _survey() {
    if (!mounted) return;
    final view = _rectOf(_listKey);
    if (view == null) return;

    final top = view.top;
    final seen = top + _pinHeight;
    final now = clock.now();

    _Drawn? first;
    double? next;
    var nowInSight = false;
    // The list has no Agora of its own: now is the top of Fazer em breve.
    final nowSection = _isList ? _soon : null;
    for (final row in _drawn) {
      final rect = _rectOf(row.key);
      if (rect == null) continue;
      if (row.section == nowSection &&
          rect.bottom > top &&
          rect.top < view.bottom) {
        nowInSight = true;
      }
      if (first == null) {
        if (rect.bottom > top + 0.5) first = row;
      } else if (next == null && row.heading && rect.top > top) {
        next = rect.top;
      }
    }

    // The heading of the section at the top, unless that heading is itself
    // still in sight where it was drawn.
    final section = first?.section;
    final heading = first == null ? null : _headingKeys[section];
    final headingRect = heading == null ? null : _rectOf(heading);
    final pinned =
        first != null &&
        section != _loose &&
        (headingRect == null || headingRect.top < top - 0.5);
    _pinned.value = pinned
        ? (
            label: _labelOf(section, now),
            dy: next == null
                ? 0.0
                : (next - top - _pinHeight).clamp(
                    -_pinHeight,
                    0.0,
                  ),
          )
        : null;
    _away.value =
        _scroll.hasClients && _scroll.offset > _pinHeight && !nowInSight;

    widget.aim?.value = _aimFor(first, _firstFreeHour(view, seen));
  }

  /// The first free hour in sight: the first of the hours of the first
  /// stretch in sight that is not under the pinned heading.
  DateTime? _firstFreeHour(Rect view, double seen) {
    for (final row in _drawn) {
      final room = row.room;
      if (room == null || room.heading == null) continue;
      final rect = _rectOf(row.key);
      if (rect == null || rect.bottom <= seen + AppSpacing.tapTarget) continue;
      if (rect.top >= view.bottom) continue;

      final dy = (seen - rect.top).clamp(0.0, rect.height);
      final at = dy <= 0
          ? room.slot.earliest
          : _upToStep(TimelineScale.timeAt(room.slot, dy, rect.height));
      if (!at.isBefore(room.slot.end.subtract(TimelinePlan.gap))) continue;

      return at;
    }

    return null;
  }

  /// Where the button at the foot of the app writes, for what is on screen.
  Placement? _aimFor(_Drawn? first, DateTime? free) {
    if (!_isList) {
      if (free != null) return Placement.at(free);

      // No room in sight: from the first thing in sight, wherever the day
      // has room after it.
      final card = first?.card;
      if (card == null) return null;
      final now = clock.now();
      return Placement.at(card.startTime.isAfter(now) ? card.startTime : now);
    }

    // The end of the stage at the top.
    if (first?.section == _backlog) return const Placement.backlog();

    return Placement.queue(_state.tasks.length);
  }

  /// [at] moved on to the next five minutes on the clock, if it is not on
  /// one.
  static DateTime _upToStep(DateTime at) {
    final minutes =
        (at.minute / TimelineScale.step).ceil() * TimelineScale.step;
    return DateTime(at.year, at.month, at.day, at.hour, minutes);
  }

  /// The one list, with a heading dropped in wherever the day changes.
  ///
  /// The headings are written out of the cards rather than wrapped around
  /// them, so nothing has to be laid out twice and a section with nothing in
  /// it simply is not drawn. The free stretches are written in between the
  /// cards they separate, and fall under a heading by where they start, like
  /// any card.
  ///
  /// Under Agora nothing changed: the cards take the height they need and the
  /// break is its own quiet card, there whenever nothing is running, even
  /// with the working day over. Later in the day every row is as tall as its
  /// time, and room too short to be worth a drop is left out, so the next
  /// card simply follows.
  List<Widget> _rows(TimelineState state, String? dragging) {
    final now = clock.now();
    final drawn = <_Drawn>[];
    _drawn = drawn;
    final rows = <Widget>[
      // A write that never landed used to be entirely silent: the card the
      // user had just typed simply did not appear, which reads as the button
      // being broken rather than as the server being unreachable.
      if (state.failure != null)
        _Failed(
          reason: state.failure!.message ?? context.l10n.failureUnreachable,
          onRetry: () =>
              context.read<TimelineBloc>().add(const TimelineRequested()),
        ),
    ];

    if (_isList) return [...rows, ..._listRows(state, dragging, now, drawn)];

    final cards = state.cards;
    final rooms = _rooms(
      TimelinePlan.freeSlots(
        cards,
        now: now,
        days: state.days,
        workDay: state.workDay,
      ),
      cards,
      now,
    );
    _shownRooms = rooms;

    var first = true;
    _Heading section = _unset;

    for (final entry in _entries(cards, rooms)) {
      final card = entry.card;
      final room = entry.room;
      final entrySection = card == null ? room!.heading : _headingOf(card);
      final before = card == null ? room!.slot.index : _indexOf(card.id);

      // A row only moves while there is a card in the air; the rest of the
      // time the offset is zero, so a dropped card cannot animate after it
      // has landed.
      final dy = dragging == null ? 0.0 : _shift(before);

      if (entrySection != section) {
        section = entrySection;
        final key = _headingKey(entrySection);
        drawn.add((
          key: key,
          section: entrySection,
          heading: true,
          room: null,
          card: null,
        ));
        rows.add(
          _Slid(
            key: key,
            dy: dy,
            child: _HeadingRow(
              label: _label(entrySection, now),
              first: first,
            ),
          ),
        );
        first = false;
      }

      final key = card == null ? _freeKey(_rowOf(room!)) : _cardKey(card.id);
      drawn.add((
        key: key,
        section: entrySection,
        heading: false,
        room: room,
        card: card,
      ));
      final aimed =
          dragging != null && room != null && _aimedRow == _rowOf(room);

      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s1),
          child: _Slid(
            key: key,
            dy: dy,
            child: switch ((card, entrySection)) {
              (null, null) => FreeTile(
                slot: room!.slot,
                now: true,
                targeted: aimed,
                // The break is not cut into hours, so a tap on it is always
                // now.
                onTap: widget.onWriteDown == null
                    ? null
                    : () => widget.onWriteDown!(
                        Placement.at(room.slot.earliest),
                      ),
              ),
              (null, _) => FreeStretch(
                slot: room!.slot,
                targeted: aimed,
                preview: aimed ? _landing : null,
                onTap: widget.onWriteDown,
                stickBelow: _pinHeight,
              ),
              // Agora is drawn as it needs rather than to scale.
              (final card?, null) => _tile(card, dragging),
              (final card?, _) => SizedBox(
                height: TimelineScale.blockHeight(card),
                child: _tile(card, dragging),
              ),
            },
          ),
        ),
      );
    }

    if (state.extending) rows.add(const _More());

    return rows;
  }

  /// The list's two stages, both always drawn: every task with an hour in
  /// one run, in the order of their hours and not cut into days, ending in
  /// a +, then the backlog and its +.
  ///
  /// Every row is as tall as it needs; there is no room in either stage.
  /// The backlog's heading is a row like any card to a drag, keyed so it can
  /// be measured, and slides out of the way like one.
  List<Widget> _listRows(
    TimelineState state,
    String? dragging,
    DateTime now,
    List<_Drawn> drawn,
  ) {
    _shownRooms = const [];
    final l10n = context.l10n;
    double shift(int before) => dragging == null ? 0.0 : _shift(before);

    final soonKey = _headingKey(_soon);
    drawn.add((
      key: soonKey,
      section: _soon,
      heading: true,
      room: null,
      card: null,
    ));
    final rows = <Widget>[
      _HeadingRow(key: soonKey, label: l10n.stageSoon, first: true),
      if (state.tasks.isEmpty)
        _Slid(
          dy: shift(0),
          child: _StageEmpty(text: l10n.stageSoonEmpty),
        ),
    ];

    final tasks = state.tasks;
    for (final card in tasks) {
      drawn.add((
        key: _cardKey(card.id),
        section: _soon,
        heading: false,
        room: null,
        card: card,
      ));
      rows.add(_listTile(card, dragging, shift(_indexOf(card.id))));
    }
    rows.add(
      _addRow(
        _soon,
        Placement.queue(tasks.length),
        shift(tasks.length),
        drawn,
      ),
    );

    drawn.add((
      key: _dividerKey,
      section: _backlog,
      heading: true,
      room: null,
      card: null,
    ));
    rows.add(
      _Slid(
        key: _dividerKey,
        dy: shift(state.tasks.length),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeadingRow(label: l10n.stageBacklog, first: false),
            if (state.backlog.isEmpty)
              _StageEmpty(text: l10n.stageBacklogEmpty),
          ],
        ),
      ),
    );

    for (final card in state.backlog) {
      drawn.add((
        key: _cardKey(card.id),
        section: _backlog,
        heading: false,
        room: null,
        card: card,
      ));
      rows.add(_listTile(card, dragging, shift(_indexOf(card.id))));
    }
    rows.add(
      _addRow(
        _backlog,
        const Placement.backlog(),
        shift(_slots.length),
        drawn,
      ),
    );

    return rows;
  }

  /// The + that ends [section] of the list, writing something down at
  /// [placement].
  Widget _addRow(
    Object? section,
    Placement placement,
    double dy,
    List<_Drawn> drawn,
  ) {
    final key = _addKey(section);
    drawn.add((
      key: key,
      section: section,
      heading: false,
      room: null,
      card: null,
    ));

    return _Slid(
      key: key,
      dy: dy,
      child: _AddRow(
        onTap: widget.onWriteDown == null
            ? null
            : () => widget.onWriteDown!(placement),
      ),
    );
  }

  Widget _listTile(TimelineEvent card, String? dragging, double dy) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s1),
      child: _Slid(
        key: _cardKey(card.id),
        dy: dy,
        child: _tile(card, dragging),
      ),
    );
  }

  /// Not a heading: what the heading being written starts as, so the first
  /// row always writes one.
  static final DateTime _unset = DateTime(0);

  /// The heading [card] is drawn under: Agora while it is running, its day
  /// otherwise.
  static _Heading _headingOf(TimelineEvent card) =>
      card.section == TimelineSection.agora ? null : card.day;

  /// What the heading over [heading] says, looking from [now].
  String _label(_Heading heading, DateTime now) {
    final l10n = context.l10n;
    if (heading == null) return l10n.sectionNow;

    final today = DateTime(now.year, now.month, now.day);
    final days = heading.difference(today).inDays;
    if (days <= 0) return l10n.sectionToday;
    if (days == 1) return l10n.sectionTomorrow;

    final date = l10n.sectionDay(heading);
    return date.isEmpty ? date : date[0].toUpperCase() + date.substring(1);
  }

  /// What a pinned heading over [section] says.
  String _labelOf(Object? section, DateTime now) {
    if (section == _backlog) return context.l10n.stageBacklog;
    if (section == _soon) return context.l10n.stageSoon;

    return _label(section as _Heading, now);
  }

  Widget _tile(TimelineEvent card, String? dragging) {
    final bloc = context.read<TimelineBloc>();

    return EventTile(
      card: card,
      pressed: card.id == _pressed,
      // The list rebuilds on every state, so reading it here is enough.
      touched: bloc.state.touched.contains(card.id),
      // The card in the air is drawn over the list, so the one left behind
      // only holds its place open.
      hidden: card.id == dragging,
      actionsKey: _actionKeys.putIfAbsent(card.id, GlobalKey.new),
      onPauseToggled: () => bloc.add(EventPauseToggled(card.id)),
      onAdjusted: (minutes) => unawaited(adjustTime(context, card, minutes)),
      onDone: () => bloc.add(EventFinished(card.id)),
      onStarted: () => bloc.add(EventStarted(card.id)),
      onSnoozed: () => bloc.add(EventSnoozed(card.id)),
    );
  }

  /// The free stretches as they are drawn, each under its heading.
  ///
  /// Under Agora the break is drawn whatever its length, as it always was,
  /// and whenever nothing is running at all, even outside the working day:
  /// now is always somewhere to look and to drop. Later in the day only room
  /// worth a drop is drawn. The break is also the start of the rest of
  /// today, so when it is long enough it opens Ainda hoje as well, the way
  /// any empty room there would.
  static List<_Room> _rooms(
    List<FreeSlot> slots,
    List<TimelineEvent> cards,
    DateTime now,
  ) {
    final rooms = <_Room>[
      for (final slot in slots)
        if (!slot.start.isAfter(now)) ...[
          (slot: slot, heading: null),
          if (TimelineScale.shows(slot)) (slot: slot, heading: _dayOf(slot)),
        ] else if (TimelineScale.shows(slot))
          (slot: slot, heading: _dayOf(slot)),
    ];

    final busy = cards.any((card) => card.section == TimelineSection.agora);
    if (busy || rooms.any((room) => room.heading == null)) return rooms;

    // Nothing running and no room at this minute: the day is over, or the
    // next block is moments away. Agora is drawn anyway, up to whatever is
    // next.
    final minute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final next = cards
        .where((card) => card.startTime.isAfter(now))
        .map((card) => card.startTime)
        .firstOrNull;

    return [
      (
        slot: FreeSlot(
          start: minute,
          end: next ?? minute.add(const Duration(hours: 1)),
          earliest: minute,
          index: 0,
        ),
        heading: null,
      ),
      ...rooms,
    ];
  }

  /// The cards and the free stretches as one list, in the order they happen.
  static List<_Entry> _entries(List<TimelineEvent> cards, List<_Room> rooms) {
    final entries = <_Entry>[];
    var next = 0;

    for (var index = 0; index <= cards.length; index++) {
      while (next < rooms.length && rooms[next].slot.index == index) {
        entries.add((card: null, room: rooms[next++]));
      }
      if (index < cards.length) entries.add((card: cards[index], room: null));
    }

    return entries;
  }

  /// The day a free stretch falls under, by where it starts.
  static DateTime _dayOf(FreeSlot slot) =>
      DateTime(slot.start.year, slot.start.month, slot.start.day);

  Widget _lifted(TimelineState state, String id) {
    final rect = _originRect;
    final card = state.byId(id);
    final box = _sectionKey.currentContext?.findRenderObject() as RenderBox?;
    if (rect == null || card == null || box == null) {
      return const SizedBox.shrink();
    }

    final top = box.globalToLocal(rect.topLeft).dy + _travel.dy;

    return Positioned(
      left: AppSpacing.s6,
      right: AppSpacing.s6,
      top: top,
      height: rect.height,
      child: IgnorePointer(
        child: _Lifted(
          card: card,
          dx: _travel.dx,
          progress: _solveProgress,
          landing: _landing,
        ),
      ),
    );
  }

  /// The card that has just been solved, playing itself out.
  Widget _flying(_Flying flight) {
    return Positioned(
      left: AppSpacing.s6,
      right: AppSpacing.s6,
      top: flight.top,
      height: flight.height,
      child: IgnorePointer(
        child: _Flight(
          key: ValueKey(flight.card.id),
          card: flight.card,
          dx: flight.dx,
          onEnd: () {
            if (mounted) setState(() => _flight = null);
          },
        ),
      ),
    );
  }
}

/// The heading of whatever is at the top of the list, pinned there while it
/// scrolls, and the chip back to Agora once Agora is out of sight.
///
/// Drawn over the list and let through, so a press on it lands on whatever
/// card is under it. Built off two listenables rather than with the list, so
/// a scroll redraws a line of text and not the day.
class _PinnedHeading extends StatelessWidget {
  const _PinnedHeading({
    required this.pin,
    required this.away,
    required this.height,
    required this.onBackToNow,
  });

  final ValueListenable<_Pin?> pin;
  final ValueListenable<bool> away;
  final double height;

  final VoidCallback onBackToNow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<_Pin?>(
                valueListenable: pin,
                builder: (context, pinned, _) => pinned == null
                    ? const SizedBox.shrink()
                    : Transform.translate(
                        offset: Offset(0, pinned.dy),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: ColoredBox(
                                color: AppColors.bg,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    pinned.label,
                                    style: AppTypography.title,
                                  ),
                                ),
                              ),
                            ),
                            // What scrolls under it fades in rather than
                            // being cut by a hard edge.
                            Positioned(
                              left: 0,
                              right: 0,
                              top: height,
                              height: AppSpacing.s3,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.bg,
                                      AppColors.bg.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: away,
              builder: (context, show, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: show
                    ? _BackToNow(onTap: onBackToNow)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The chip that takes the list back to Agora.
class _BackToNow extends StatelessWidget {
  const _BackToNow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: context.l10n.timelineBackToNow,
        child: Material(
          color: AppColors.fillStrong,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s1 + 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(
                    iconData: AppIcons.arrowUp,
                    size: AppSpacing.s4,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: AppSpacing.s1),
                  Text(
                    context.l10n.sectionNow,
                    style: AppTypography.labelStrong.copyWith(
                      color: AppColors.ink,
                    ),
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

/// The + that ends a section of the list.
class _AddRow extends StatelessWidget {
  const _AddRow({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return const SizedBox(height: AppSpacing.s2);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s1),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(
                  iconData: AppIcons.plus,
                  size: AppSpacing.s4,
                  color: AppColors.ink3,
                ),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  context.l10n.timelineAdd,
                  style: AppTypography.label.copyWith(color: AppColors.ink3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One heading, which is a line and not a container: a day of the
/// calendar, or one of the list's two stages, set alike.
class _HeadingRow extends StatelessWidget {
  const _HeadingRow({required this.label, required this.first, super.key});

  final String label;

  /// Whether it is the first thing on the screen, and so needs no room above.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: first ? AppSpacing.s2 : AppSpacing.s6,
        bottom: AppSpacing.s1,
      ),
      child: Text(label, style: AppTypography.title),
    );
  }
}

/// What an empty stage says, which is also where a drop into it goes.
class _StageEmpty extends StatelessWidget {
  const _StageEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: Text(
        text,
        style: AppTypography.label.copyWith(color: AppColors.ink3),
      ),
    );
  }
}

/// The card in the air: the tile itself, and the check it is being carried
/// towards.
class _Lifted extends StatelessWidget {
  const _Lifted({
    required this.card,
    required this.dx,
    required this.progress,
    this.landing,
  });

  final TimelineEvent card;

  /// Where it would land, which its hours read while it is aimed somewhere.
  final _Span? landing;

  /// How far sideways the finger has taken it.
  final double dx;

  /// How far along the way to being solved it is, 0 to 1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The check sits in the room the card opened as it left, so it is
        // read beside the card rather than through it.
        Positioned.fill(
          child: Align(
            alignment: dx.isNegative
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: _SolveMark(progress: progress, delete: dx.isNegative),
            ),
          ),
        ),
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: EventTile(card: card, lifted: true, landing: landing),
          ),
        ),
      ],
    );
  }
}

/// The check beside a card being carried out of the day.
///
/// It fades up with the drag and goes from grey to white once the card has
/// gone far enough, so the gesture says what letting go will do before it
/// does it. It never turns green here: green is the block being finished, and
/// that does not happen until the finger comes off.
class _SolveMark extends StatelessWidget {
  const _SolveMark({required this.progress, required this.delete});

  final double progress;

  /// Whether the card is on its way to being deleted rather than done.
  final bool delete;

  @override
  Widget build(BuildContext context) {
    final armed = progress == 1;

    return Opacity(
      opacity: 0.4 + 0.6 * progress,
      child: Transform.scale(
        scale: 0.8 + 0.2 * progress,
        child: AppIcon(
          iconData: delete ? AppIcons.trash : AppIcons.check,
          color: armed ? AppColors.ink : AppColors.ink3,
        ),
      ),
    );
  }
}

/// The last quarter second of a finished card.
///
/// The card carries on the way it was going and fades out while the check
/// swells behind it. It is drawn over a list that has already closed the gap,
/// so by the time it is gone there is nothing left to tidy up.
class _Flight extends StatefulWidget {
  const _Flight({
    required this.card,
    required this.dx,
    required this.onEnd,
    super.key,
  });

  final TimelineEvent card;

  /// Where the card was when it was let go, and which way it was headed.
  final double dx;

  /// Called once there is nothing left to draw.
  final VoidCallback onEnd;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  /// How far past the release point the card carries on.
  static const _throw = 140.0;

  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 260),
    vsync: this,
  )..forward().whenComplete(widget.onEnd);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sign = widget.dx.isNegative ? -1.0 : 1.0;

    return AnimatedBuilder(
      animation: _controller,
      child: EventTile(card: widget.card, lifted: true),
      builder: (context, child) {
        final t = Curves.easeIn.transform(_controller.value);

        return Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: sign.isNegative
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4,
                  ),
                  child: Transform.scale(
                    scale: 1 + 0.5 * t,
                    child: Opacity(
                      opacity: 1 - t,
                      child: const AppIcon(
                        iconData: AppIcons.check,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(widget.dx + sign * _throw * t, 0),
                child: Opacity(
                  opacity: 1 - t,
                  child: Transform.scale(scale: 1 - 0.08 * t, child: child),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A card moved out of the way, without being laid out anywhere else.
///
/// Keyed from outside the move, so what is measured is where it was laid
/// out, not where it has been moved to.
class _Slid extends StatelessWidget {
  const _Slid({required this.dy, required this.child, super.key});

  final double dy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: dy),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) =>
          Transform.translate(offset: Offset(0, value), child: child),
      child: child,
    );
  }
}

/// What the day says when the last thing it tried did not land.
///
/// Quiet, and above the cards rather than over them: nothing has been lost,
/// the screen is simply older than the user thinks it is, and the way out is
/// to ask again.
class _Failed extends StatelessWidget {
  const _Failed({required this.reason, required this.onRetry});

  /// The server's own sentence about what went wrong.
  final String reason;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s3),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: Row(
          children: [
            const AppIcon(
              iconData: AppIcons.warning,
              size: AppSpacing.s4,
              color: AppColors.ink3,
            ),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(
                context.l10n.failureRetry(reason),
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The next week on its way, at the end of the calendar.
class _More extends StatelessWidget {
  const _More();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.s4),
      child: AppSkeleton(height: AppSpacing.s16, radius: AppSpacing.chipRadius),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.s6),
      child: Column(
        children: [
          AppSkeleton(height: AppSpacing.s16, radius: AppSpacing.chipRadius),
          SizedBox(height: AppSpacing.s1),
          AppSkeleton(height: AppSpacing.s16, radius: AppSpacing.chipRadius),
        ],
      ),
    );
  }
}
