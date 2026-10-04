import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:chat/src/bloc/timeline_bloc.dart';
import 'package:chat/src/models/models.dart';
import 'package:chat/src/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

/// A free stretch as it is drawn, under one heading.
///
/// The room from now until the next block is drawn twice: as the break under
/// Agora, and as the empty room that opens Ainda hoje. Both are the same
/// stretch and the same place to drop.
typedef _Room = ({FreeSlot slot, TimelineSection section});

/// Which drawn stretch a row is: where it starts, and under which heading.
typedef _Row = (DateTime, TimelineSection);

/// A solved card on its way off the screen, frozen as it was let go.
typedef _Flying = ({
  TimelineEvent card,
  double top,
  double height,
  double dx,
});

/// {@template timeline_list}
/// The day: one list in clock order, cut into sections by the clock.
///
/// The headings are not containers. Every card has an hour, the hour says
/// which heading it falls under, and a drop is a place in the one list
/// underneath all of them. That is what took the arithmetic out of this
/// screen: there is no list a card can be in the wrong one of, and no index
/// that means something different depending on which heading it is near.
///
/// One [Listener] over the whole thing owns every gesture: a tap opens the
/// conversation about a block, a press held for a moment picks its card up,
/// and the card then
/// follows the finger while the rest of the list opens a place for it. The
/// place is whichever one is nearest, so the card lands wherever it is let go
/// rather than only on something it managed to hit.
///
/// Agora is drawn as it always was. Below it the day reads like a calendar:
/// every card is as tall as its time, near enough, and the free stretches
/// between them, from the end of what is running or seven in the morning to
/// ten at night, are drawn as empty room just as tall. Room of ten minutes
/// or less is not drawn, and neither is the pause between two blocks. A card
/// let go over a stretch lands at the start of it, and one too long for it
/// asks whether to cut it to fit, and stays where it was on a no.
///
/// A fixed card, a routine's day included, is different, because its hour is
/// the point of it. It only lands in empty room, and wherever in the room it
/// is let go, on the nearest quarter of an hour that leaves it whole. The
/// room draws it there while it is aimed at, hours and all, so the drop is
/// read before it happens.
///
/// A tap on empty room writes something down there. In the first part of the
/// room, up to its first full hour, it is flexible and starts no earlier than
/// the room does. In any hour after that it is fixed at that hour.
///
/// A drag picks an axis as soon as it starts moving and keeps it. Up and down
/// reorders; right carries the card out of the day and marks it done, and
/// left deletes it once the user has confirmed.
/// Nothing does both at once, because a card that slid sideways while
/// being reordered would be asking which of the two the finger meant, and the
/// finger has already said.
///
/// The list does not re-lay-out while a card is up. The cards that move are
/// moved by a transform over a layout that was measured once, when the card
/// came up, so the place being aimed at cannot shift out from under the
/// finger that is aiming at it.
/// {@endtemplate}
class TimelineList extends StatefulWidget {
  /// {@macro timeline_list}
  const TimelineList({required this.onCardTap, this.onFreeTap, super.key});

  /// Called with the block whose card was tapped.
  ///
  /// The whole card rather than an id, because what a tap opens depends on
  /// whether the block already has a conversation behind it, and the card is
  /// the only thing that knows.
  final ValueChanged<TimelineEvent> onCardTap;

  /// Called with what a tap on empty room asked for: where the room starts,
  /// flexible, or a later hour in it, fixed.
  final ValueChanged<FreeTap>? onFreeTap;

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

  /// The section itself, for turning the pointer into local coordinates.
  final GlobalKey _sectionKey = GlobalKey();

  /// One key per card, so the laid-out list can be measured.
  final _cardKeys = <String, GlobalKey>{};

  /// One key per free stretch on screen, by where it starts and the heading
  /// it is drawn under.
  final _freeKeys = <_Row, GlobalKey>{};

  /// The free stretches drawn in the last build.
  List<_Room> _shownRooms = const [];

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

  /// The card the finger is on, whether or not it has been picked up yet.
  String? _pressed;

  /// The card in the air.
  String? _dragging;

  /// Where the card came from, and what it measured, taken once at pick-up.
  Rect? _originRect;
  double _slotHeight = 0;

  /// The dragged card's place in the list, taken once at pick-up.
  int _originIndex = 0;

  /// Every place the card could land, measured once at pick-up.
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
    super.dispose();
  }

  TimelineState get _state => context.read<TimelineBloc>().state;

  /// The whole timeline, in the order it is drawn.
  List<TimelineEvent> get _cards => _state.cards;

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
    if (box == null || !box.hasSize) return null;

    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The id of the card under [global], if there is one that can be touched.
  ///
  /// A meeting Focus did not book is drawn in the list and is not the app's
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
  /// resting layout, because the cards that move out of the way are moved by
  /// a transform and never change where they were laid out.
  ///
  /// A card scrolled out of the list's reach has no rect and no edges, but
  /// still counts, so the places on either side of it keep their numbers.
  List<_Anchor> _measure(String id) {
    final rest = _cards.where((card) => card.id != id).toList();
    final anchors = <_Anchor>[];

    for (var index = 0; index < rest.length; index++) {
      final rect = _rectOf(_cardKey(rest[index].id));
      if (rect == null) continue;

      anchors
        ..add(_edge(index, rect.top))
        ..add(_edge(index + 1, rect.bottom));
    }
    if (anchors.isEmpty) anchors.addAll([?_centerOf(id)]);

    // The stretches are priced with the card lifted out, because that is the
    // day the drop lands in: a card that sat right beside a gap makes the gap
    // bigger by leaving it.
    final lifted = TimelinePlan.freeSlots(rest);
    for (final room in _shownRooms) {
      final shown = room.slot;
      final rect = _rectOf(_freeKey(_rowOf(room)));
      if (rect == null) continue;

      final slot = lifted.where((it) => it.contains(shown.start)).firstOrNull;
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

  static _Row _rowOf(_Room room) => (room.slot.start, room.section);

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
  /// A flexible card goes to the start of the room. A fixed one goes where
  /// its top edge is, on the nearest quarter of an hour that keeps it whole.
  /// Under Agora the room is not drawn to scale, so there is no height to
  /// read an hour from, and it goes to the start too. A card too long for
  /// the room is shown cut to what fits, which is what the drop will offer.
  _Span? _landingFor(_Anchor anchor) {
    final slot = anchor.slot;
    final card = _draggedCard;
    if (slot == null || card == null) return null;

    var start = slot.earliest;
    final shown = anchor.shown;
    final area = anchor.area;
    final origin = _originRect;
    if (card.isAnchored &&
        shown != null &&
        area != null &&
        origin != null &&
        anchor.row?.$2 != TimelineSection.agora) {
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
    final origin = _state.indexOf(id);
    if (rect == null || origin == -1) return;

    setState(() {
      _dragging = id;
      _axis = null;
      _originIndex = origin;
      _originRect = rect;
      _slotHeight = rect.height + AppSpacing.s1;
      _anchors = _measure(id);
      _travel = Offset.zero;
      _aim(_nearest(_down!));
    });
  }

  void _onMove(PointerMoveEvent event) {
    final down = _down;
    if (down == null) return;

    if (_dragging != null) {
      final wasArmed = _armedSolve;
      final wasLanding = _landing?.start;
      final travel = event.position - down;

      setState(() {
        _axis = _axisFor(travel);
        // The card moves along the axis the drag chose and not a pixel along
        // the other one, so a reorder cannot drift sideways into solving the
        // thread and a card being carried out cannot drift into the list.
        _travel = _axis == Axis.horizontal
            ? Offset(travel.dx, 0)
            : Offset(0, travel.dy);
        // A card on its way out of the timeline is not aiming at a place, so
        // nothing opens one for it: the list stays where it is and the only
        // thing left to read is the check.
        _aim(_axis == Axis.horizontal ? null : _nearest(event.position));
      });

      // One tick as the gesture changes what letting go will do, and only on
      // the change. A fixed card crossing a quarter of an hour is one.
      if (_armedSolve != wasArmed ||
          (_landing != null && _landing?.start != wasLanding)) {
        unawaited(HapticFeedback.selectionClick());
      }
      return;
    }

    // Past the slop the gesture belongs to the list, which scrolls: the hold
    // is called off and the card under the finger stops looking pressed.
    if ((event.position - down).distance > _slop) _cancel();
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

    if (slot != null && card != null) {
      unawaited(_dropInto(card, slot, landing?.start ?? slot.earliest));
      return;
    }

    if (target == null) return;

    // A card put back exactly where it came from is not a move, and does not
    // need to be written anywhere. The target counts the list with the card
    // already lifted out, which is the same list the server splices it into,
    // so its old place is just its old index.
    if (target == origin) return;

    context.read<TimelineBloc>().add(EventMoved(id: id, index: target));
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
  /// leaves the day exactly as it was. A fixed card let go on the hour it
  /// already had has not moved.
  Future<void> _dropInto(
    TimelineEvent card,
    FreeSlot slot,
    DateTime start,
  ) async {
    final bloc = context.read<TimelineBloc>();
    final room = slot.end.difference(start).inMinutes;

    if (card.isAnchored && start == card.startTime) return;

    if (card.durationMinutes <= room) {
      bloc.add(EventMoved(id: card.id, index: slot.index, after: start));
      return;
    }

    // Under five minutes there is nothing worth cutting a block down to.
    if (room < 5) {
      unawaited(HapticFeedback.heavyImpact());
      return;
    }

    if (await confirmShorten(context, card, room)) {
      bloc.add(
        EventMoved(
          id: card.id,
          index: slot.index,
          after: start,
          minutes: room,
        ),
      );
    }
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
              // The list is frozen for as long as a card is up. The pointer
              // that picked the card up is one the scrollable is still
              // watching, and without this it would drag the list out from
              // under the place the card is aiming at.
              child: AbsorbPointer(
                absorbing: dragging != null,
                child: ListView(
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

  /// The one list, with a heading dropped in wherever the section changes.
  ///
  /// The headings are written out of the cards rather than wrapped around
  /// them, so nothing has to be laid out twice and a section with nothing in
  /// it simply is not drawn. The free stretches are written in between the
  /// cards they separate, and fall under a heading by where they start, like
  /// any card.
  ///
  /// Under Agora nothing changed: the cards take the height they need and the
  /// break is its own quiet card. Later in the day every row is as tall as
  /// its time, and room too short to be worth a drop is left out, so the next
  /// card simply follows.
  List<Widget> _rows(TimelineState state, String? dragging) {
    final now = DateTime.now();
    var first = true;
    final rows = <Widget>[
      // A write that never landed used to be entirely silent: the card the
      // user had just typed simply did not appear, which reads as the button
      // being broken rather than as the server being unreachable.
      if (state.failure != null)
        _Failed(
          reason: state.failure!,
          onRetry: () =>
              context.read<TimelineBloc>().add(const TimelineRequested()),
        ),
    ];

    final rooms = _rooms(TimelinePlan.freeSlots(state.cards, now: now), now);
    _shownRooms = rooms;
    if (state.cards.isEmpty && rooms.isEmpty) return [...rows, const _Empty()];

    TimelineSection? section;

    for (final entry in _entries(state.cards, rooms)) {
      final card = entry.card;
      final room = entry.room;
      final entrySection = card?.section ?? room!.section;
      final before = card == null ? room!.slot.index : state.indexOf(card.id);

      // A row only moves while there is a card in the air; the rest of the
      // time the offset is zero, so a dropped card cannot animate after it
      // has landed.
      final dy = dragging == null ? 0.0 : _shift(before);

      if (entrySection != section) {
        section = entrySection;
        rows.add(
          _Slid(
            dy: dy,
            child: _Heading(label: entrySection.label, first: first),
          ),
        );
        first = false;
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s1),
          child: _Slid(
            dy: dy,
            child: switch ((card, entrySection)) {
              (null, TimelineSection.agora) => FreeTile(
                key: _freeKey(_rowOf(room!)),
                slot: room.slot,
                now: true,
                targeted: dragging != null && _aimedRow == _rowOf(room),
                // The break is not cut into hours, so a tap on it is always
                // the room itself.
                onTap: widget.onFreeTap == null
                    ? null
                    : () => widget.onFreeTap!(
                        (from: room.slot.earliest, fixedAt: null),
                      ),
              ),
              (null, _) => FreeStretch(
                key: _freeKey(_rowOf(room!)),
                slot: room.slot,
                targeted: dragging != null && _aimedRow == _rowOf(room),
                preview: dragging != null && _aimedRow == _rowOf(room)
                    ? _landing
                    : null,
                onTap: widget.onFreeTap,
              ),
              (final card?, TimelineSection.agora) => _tile(card, dragging),
              (final card?, _) => SizedBox(
                height: TimelineScale.blockHeight(card),
                child: _tile(card, dragging),
              ),
            },
          ),
        ),
      );
    }

    return rows;
  }

  Widget _tile(TimelineEvent card, String? dragging) {
    final bloc = context.read<TimelineBloc>();

    return EventTile(
      key: _cardKey(card.id),
      card: card,
      pressed: card.id == _pressed,
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
  /// Under Agora the break is drawn whatever its length, as it always was.
  /// Later in the day only room worth a drop is drawn. The break is also the
  /// start of the rest of today, so when it is long enough it opens Ainda
  /// hoje as well, the way any empty room there would.
  static List<_Room> _rooms(List<FreeSlot> slots, DateTime now) {
    return [
      for (final slot in slots)
        if (_sectionOf(slot, now) == TimelineSection.agora) ...[
          (slot: slot, section: TimelineSection.agora),
          if (TimelineScale.shows(slot))
            (slot: slot, section: TimelineSection.hoje),
        ] else if (TimelineScale.shows(slot))
          (slot: slot, section: _sectionOf(slot, now)),
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

  /// The heading a free stretch falls under, by where it starts.
  static TimelineSection _sectionOf(FreeSlot slot, DateTime now) {
    if (!slot.start.isAfter(now)) return TimelineSection.agora;

    final today =
        slot.start.year == now.year &&
        slot.start.month == now.month &&
        slot.start.day == now.day;
    return today ? TimelineSection.hoje : TimelineSection.amanha;
  }

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

/// One section heading, which is a line and not a container.
class _Heading extends StatelessWidget {
  const _Heading({required this.label, required this.first});

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
class _Slid extends StatelessWidget {
  const _Slid({required this.dy, required this.child});

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
                '$reason Toque para tentar de novo.',
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the timeline says when there is nothing on it.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s6),
      child: Text(
        'Nada marcado. Toque no orbe para escrever algo.',
        style: AppTypography.body.copyWith(color: AppColors.ink3),
      ),
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
