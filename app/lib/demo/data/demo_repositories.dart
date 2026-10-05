import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// The day the demo opens on, drawn around the moment it is opened.
///
/// [resting] leaves out the block that would be running, so the day starts
/// on the break between two blocks instead.
List<TimelineEvent> demoCards(AppLocalizations l10n, {bool resting = false}) {
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1, 9);

  return [
    if (!resting)
      _card(
        'lunna',
        l10n.demoBuilding,
        TimelineSection.agora,
        now.subtract(const Duration(minutes: 12)),
        45,
      ),
    _card(
      'mercado',
      l10n.demoGroceries,
      TimelineSection.hoje,
      now.add(const Duration(minutes: 40)),
      30,
    ),
    _card(
      'standup',
      l10n.demoStandup,
      TimelineSection.hoje,
      now.add(const Duration(hours: 2)),
      15,
      fixed: true,
    ),
    _card(
      'dentista',
      l10n.demoDentist,
      TimelineSection.amanha,
      tomorrow,
      30,
    ),
  ];
}

TimelineEvent _card(
  String id,
  String title,
  TimelineSection section,
  DateTime start,
  int minutes, {
  bool fixed = false,
}) {
  return TimelineEvent(
    id: id,
    title: title,
    section: section,
    startTime: start,
    endTime: start.add(Duration(minutes: minutes)),
    durationMinutes: minutes,
    fixed: fixed,
  );
}

/// {@template demo_timeline_repository}
/// A timeline that answers from memory, well enough to press the buttons.
///
/// It is what the landing page's phone and the preview entry point run on,
/// so the timeline can be used without a backend or a login. What the server
/// would work out, which section a new card lands in and where it goes, is
/// worked out here just closely enough to look right.
/// {@endtemplate}
class DemoTimelineRepository implements TimelineRepository {
  /// {@macro demo_timeline_repository}
  DemoTimelineRepository(AppLocalizations l10n, {bool resting = false})
    : _cards = demoCards(l10n, resting: resting);

  List<TimelineEvent> _cards;

  /// The cards as they stand.
  List<TimelineEvent> get cards => _cards;

  @override
  Future<List<TimelineEvent>> fetchEvents() async => _cards;

  @override
  Future<List<TimelineEvent>> createEvent({
    required String title,
    required int durationMinutes,
    required bool fixed,
    DateTime? startTime,
    DateTime? notBefore,
  }) async {
    final duration = Duration(minutes: durationMinutes);
    final start =
        startTime ??
        TimelinePlan.nextFreeStart(_cards, duration, now: notBefore);
    final card = _card(
      'demo-${_cards.length}-${start.millisecondsSinceEpoch}',
      title,
      _sectionOf(start),
      start,
      durationMinutes,
      fixed: fixed,
    );

    return _cards = [..._cards, card]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  static TimelineSection _sectionOf(DateTime start) {
    final now = DateTime.now();
    if (!start.isAfter(now)) return TimelineSection.agora;

    final sameDay =
        start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    return sameDay ? TimelineSection.hoje : TimelineSection.amanha;
  }

  @override
  Future<TimelineOutcome> moveEvent(
    String id,
    int index, {
    DateTime? after,
    int? minutes,
  }) async => TimelineOutcome(cards: _cards);

  @override
  Future<TimelineOutcome> startEvent(String id) async => TimelineOutcome(
    cards: _cards = [
      for (final card in _cards)
        if (card.id == id) card.copyWith(awaitingStart: false) else card,
    ],
  );

  @override
  Future<List<TimelineEvent>> snoozeEvent(
    String id, {
    int minutes = 15,
  }) async => _cards;

  @override
  Future<TimelineOutcome> applyTiming(Map<String, dynamic> action) async =>
      TimelineOutcome(cards: _cards);

  @override
  Future<List<TimelineEvent>> pauseEvent(String id) async => _cards = [
    for (final card in _cards)
      if (card.id == id) card.copyWith(pausedAt: DateTime.now()) else card,
  ];

  @override
  Future<List<TimelineEvent>> resumeEvent(String id) async => _cards = [
    for (final card in _cards)
      if (card.id == id) card.copyWith(clearPause: true) else card,
  ];

  @override
  Future<List<TimelineEvent>> extendEvent(String id, int minutes) async =>
      _cards;

  @override
  Future<List<TimelineEvent>> finishEvent(String id) async =>
      _cards = _cards.where((card) => card.id != id).toList();

  @override
  Future<List<TimelineEvent>> deleteEvent(String id) async =>
      _cards = _cards.where((card) => card.id != id).toList();

  @override
  Future<List<TimelineEvent>> editEvent(
    String id, {
    String? title,
    String? notes,
    int? workMinutes,
    DateTime? startTime,
  }) async => _cards;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not in the demo');
}
