import 'package:chat/chat.dart';

/// The day the demo opens on, drawn around the moment it is opened.
///
/// [resting] leaves out the block that would be running, so the day starts
/// on the break between two blocks instead.
List<TimelineEvent> demoCards({bool resting = false}) {
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1, 9);

  return [
    if (!resting)
      _card(
        'focus',
        'Fazendo Focus',
        TimelineSection.agora,
        now.subtract(const Duration(minutes: 12)),
        45,
      ),
    _card(
      'mercado',
      'Comprar leite e ovos',
      TimelineSection.hoje,
      now.add(const Duration(minutes: 40)),
      30,
    ),
    _card(
      'standup',
      'Standup',
      TimelineSection.hoje,
      now.add(const Duration(hours: 2)),
      15,
      fixed: true,
    ),
    _card(
      'dentista',
      'Marcar dentista',
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
  DemoTimelineRepository({bool resting = false})
    : _cards = demoCards(resting: resting);

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
        card.id == id ? card.copyWith(awaitingStart: false) : card,
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
  Future<SyncOutcome> awaitSync() async => const SyncOutcome(ok: true);

  @override
  Future<Thread> startThread(String id) async =>
      Thread.fromJson({'slug': id, 'title': id, 'messages': const <dynamic>[]});

  @override
  Future<List<TimelineEvent>> pauseEvent(String id) async => _cards = [
    for (final card in _cards)
      card.id == id ? card.copyWith(pausedAt: DateTime.now()) : card,
  ];

  @override
  Future<List<TimelineEvent>> resumeEvent(String id) async => _cards = [
    for (final card in _cards)
      card.id == id ? card.copyWith(clearPause: true) : card,
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
    int? workMinutes,
    DateTime? startTime,
  }) async => _cards;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not in the demo');
}

/// {@template demo_chat_repository}
/// A chat that answers every message with the same line, after a beat.
/// {@endtemplate}
class DemoChatRepository implements ChatRepository {
  /// {@macro demo_chat_repository}
  DemoChatRepository();

  final _messages = <Map<String, dynamic>>[];

  @override
  Future<Thread> sendMessage(String slug, String message) async {
    // Long enough for the typing indicator to be seen, which is most of what
    // makes a canned answer read as an answer.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    _messages
      ..add({'id': '${_messages.length}', 'role': 'user', 'text': message})
      ..add({
        'id': '${_messages.length + 1}',
        'role': 'agent',
        'text': 'Entendi. Vamos por partes.',
      });

    return Thread.fromJson({
      'slug': slug,
      'title': 'Fazendo Focus',
      'messages': _messages,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not in the demo');
}
