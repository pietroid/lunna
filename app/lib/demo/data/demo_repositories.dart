import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// One task in the demo's queue, or in its backlog.
class _Task {
  _Task(
    this.id,
    this.title,
    this.minutes, {
    this.startedAt,
    this.backlog = false,
  });

  final String id;
  String title;
  String notes = '';
  int minutes;

  /// When it was begun, or null while it waits its turn.
  DateTime? startedAt;
  DateTime? pausedAt;

  /// Whether it waits in the backlog, with no hour.
  bool backlog;
}

/// {@template demo_timeline_repository}
/// A timeline that answers from memory, well enough to press the buttons.
///
/// It is what the landing page's phone and the preview entry point run on,
/// so the timeline can be used without a backend or a login. What the server
/// would work out, where each task in the queue lands among the fixed
/// blocks, is worked out here just closely enough to look right.
/// {@endtemplate}
class DemoTimelineRepository implements TimelineRepository {
  /// {@macro demo_timeline_repository}
  ///
  /// [resting] leaves out the task that would be running, so the day starts
  /// on the break between two blocks instead.
  DemoTimelineRepository(AppLocalizations l10n, {bool resting = false}) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9);

    _tasks.addAll([
      if (!resting)
        _Task(
          'lunna',
          l10n.demoBuilding,
          45,
          startedAt: now.subtract(const Duration(minutes: 12)),
        ),
      _Task('mercado', l10n.demoGroceries, 30),
      _Task('fotos', l10n.demoBacklog, 60, backlog: true),
    ]);
    _events.addAll([
      _event(
        'standup',
        l10n.demoStandup,
        now.add(const Duration(hours: 2)),
        15,
      ),
      _event('dentista', l10n.demoDentist, tomorrow, 30),
    ]);
  }

  final _tasks = <_Task>[];
  final _events = <TimelineEvent>[];
  var _next = 0;

  @override
  Future<Timeline> fetch({int days = TimelineRepository.defaultDays}) async =>
      _timeline(days);

  @override
  Future<Timeline> createTask({
    required String title,
    required int minutes,
    int days = TimelineRepository.defaultDays,
  }) async {
    _tasks.add(_Task('demo-task-${_next++}', title, minutes, backlog: true));
    return _timeline(days);
  }

  @override
  Future<Timeline> createEvent({
    required String title,
    required int durationMinutes,
    required DateTime startTime,
    int days = TimelineRepository.defaultDays,
  }) async {
    _events.add(
      _event('demo-event-${_next++}', title, startTime, durationMinutes),
    );
    return _timeline(days);
  }

  @override
  Future<Timeline> moveTask(
    String id,
    int index, {
    bool backlog = false,
    bool start = false,
    DateTime? after,
    int? minutes,
    int days = TimelineRepository.defaultDays,
  }) async {
    final task = _task(id);
    if (task != null) {
      _tasks.remove(task);
      // The index counts only the list it was dropped in, so it is turned
      // into a place among all of them by finding that list's neighbour.
      final list = _tasks.where((it) => it.backlog == backlog).toList();
      final at = index.clamp(0, list.length);
      _tasks.insert(
        at < list.length ? _tasks.indexOf(list[at]) : _tasks.length,
        task,
      );
      task.backlog = backlog;
      if (backlog) task.startedAt = null;
      if (minutes != null) task.minutes = minutes;
      if (start) _begin(task);
    }
    return _timeline(days);
  }

  @override
  Future<Timeline> startTask(
    String id, {
    int days = TimelineRepository.defaultDays,
  }) async {
    final task = _task(id);
    if (task != null) {
      _tasks
        ..remove(task)
        ..insert(0, task);
      task.backlog = false;
      _begin(task);
    }
    return _timeline(days);
  }

  @override
  Future<Timeline> snoozeTask(
    String id, {
    int minutes = 15,
    int days = TimelineRepository.defaultDays,
  }) async => _timeline(days);

  @override
  Future<Timeline> applyTiming(
    Map<String, dynamic> action, {
    int days = TimelineRepository.defaultDays,
  }) async => _timeline(days);

  @override
  Future<Timeline> finish(
    CardKind kind,
    String id, {
    int days = TimelineRepository.defaultDays,
  }) async => delete(kind, id, days: days);

  @override
  Future<Timeline> delete(
    CardKind kind,
    String id, {
    int days = TimelineRepository.defaultDays,
  }) async {
    _tasks.removeWhere((task) => task.id == id);
    _events.removeWhere((event) => event.id == id);
    return _timeline(days);
  }

  @override
  Future<Timeline> pause(
    CardKind kind,
    String id, {
    int days = TimelineRepository.defaultDays,
  }) async {
    _task(id)?.pausedAt = DateTime.now();
    return _timeline(days);
  }

  @override
  Future<Timeline> resume(
    CardKind kind,
    String id, {
    int days = TimelineRepository.defaultDays,
  }) async {
    _task(id)?.pausedAt = null;
    return _timeline(days);
  }

  @override
  Future<Timeline> extend(
    CardKind kind,
    String id,
    int minutes, {
    int days = TimelineRepository.defaultDays,
  }) async {
    final task = _task(id);
    if (task != null && task.minutes + minutes >= 5) task.minutes += minutes;
    return _timeline(days);
  }

  @override
  Future<Timeline> edit(
    CardKind kind,
    String id, {
    String? title,
    String? notes,
    int? workMinutes,
    DateTime? startTime,
    int days = TimelineRepository.defaultDays,
  }) async {
    final task = _task(id);
    if (task != null) {
      task
        ..title = title ?? task.title
        ..notes = notes ?? task.notes
        ..minutes = workMinutes ?? task.minutes;
    }
    return _timeline(days);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not in the demo');

  _Task? _task(String id) => _tasks.where((task) => task.id == id).firstOrNull;

  /// Begins [task] now, and stops whatever else had been begun.
  void _begin(_Task task) {
    for (final other in _tasks) {
      other.startedAt = null;
    }
    task.startedAt = DateTime.now();
  }

  /// The day as the server would draw it: the begun task where it began,
  /// the rest of the queue one after another in the first room among the
  /// fixed blocks.
  Timeline _timeline(int days) {
    final now = DateTime.now();
    final dayAt = DateTime(now.year, now.month, now.day);
    final until = DateTime(dayAt.year, dayAt.month, dayAt.day + days);
    final busy = [..._events];
    final tasks = <TimelineEvent>[];
    var cursor = now;

    final queue = _tasks.where((it) => !it.backlog);
    for (final task in [
      ...queue.where((it) => it.startedAt != null),
      ...queue.where((it) => it.startedAt == null),
    ]) {
      final duration = Duration(minutes: task.minutes);
      final start =
          task.startedAt ??
          TimelinePlan.nextFreeStart(busy, duration, now: cursor);
      final card = TimelineEvent(
        id: task.id,
        title: task.title,
        section: start.isAfter(now)
            ? TimelineSection.dia
            : TimelineSection.agora,
        startTime: start,
        endTime: start.add(duration),
        durationMinutes: task.minutes,
        started: task.startedAt != null,
        awaitingStart: task.startedAt == null && !start.isAfter(now),
        notes: task.notes,
        pausedAt: task.pausedAt,
      );

      tasks.add(card);
      busy.add(card);
      cursor = card.endTime.add(TimelinePlan.gap);
    }

    final cards =
        [
            ...tasks,
            ..._events.where((event) => event.endTime.isAfter(now)),
          ].where((card) => card.startTime.isBefore(until)).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Timeline(
      tasks: tasks,
      backlog: [
        for (final task in _tasks.where((it) => it.backlog))
          TimelineEvent(
            id: task.id,
            title: task.title,
            section: TimelineSection.backlog,
            startTime: now,
            endTime: now,
            durationMinutes: task.minutes,
            notes: task.notes,
          ),
      ],
      cards: cards,
    );
  }
}

TimelineEvent _event(String id, String title, DateTime start, int minutes) {
  return TimelineEvent(
    id: id,
    title: title,
    kind: CardKind.event,
    section: TimelineSection.dia,
    startTime: start,
    endTime: start.add(Duration(minutes: minutes)),
    durationMinutes: minutes,
    fixed: true,
  );
}
