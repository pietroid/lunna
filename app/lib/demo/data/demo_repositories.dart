import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
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
    this.anchor,
  });

  /// A copy, for a [DemoTimelineRepository.snapshot].
  _Task copy() =>
      _Task(
          id,
          title,
          minutes,
          startedAt: startedAt,
          backlog: backlog,
          anchor: anchor,
        )
        ..notes = notes
        ..pausedAt = pausedAt;

  final String id;
  String title;
  String notes = '';
  int minutes;

  /// When it was begun, or null while it waits its turn.
  DateTime? startedAt;
  DateTime? pausedAt;

  /// Whether it waits in the backlog, with no hour.
  bool backlog;

  /// The hour it keeps, or null while it takes its turn in the queue.
  DateTime? anchor;
}

/// {@template demo_day}
/// The demo's day as it stood at one moment, to be put back by
/// [DemoTimelineRepository.restore].
/// {@endtemplate}
class DemoDay {
  const DemoDay._(this._tasks, this._events);

  final List<_Task> _tasks;
  final List<TimelineEvent> _events;
}

/// {@template demo_timeline_repository}
/// A timeline that answers from memory, well enough to press the buttons.
///
/// It is what the landing page's phone and the preview entry point run on,
/// so the timeline can be used without a backend or a login. What the server
/// would work out, where each task lands among the fixed blocks, is worked
/// out here just closely enough to look right: the anchored ones at their
/// hours, then the queue in the room left.
/// {@endtemplate}
class DemoTimelineRepository implements TimelineRepository {
  /// {@macro demo_timeline_repository}
  ///
  /// [resting] leaves out the task that would be running, so the day starts
  /// on the break between two blocks instead.
  DemoTimelineRepository(AppLocalizations l10n, {bool resting = false}) {
    final now = clock.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9);

    _tasks.addAll([
      if (!resting)
        _Task(
          'lunna',
          l10n.demoBuilding(AppBrand.id),
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

  /// The day as it stands now.
  DemoDay snapshot() => DemoDay._(
    [for (final task in _tasks) task.copy()],
    [..._events],
  );

  /// Puts back the day [day] was taken of.
  void restore(DemoDay day) {
    _tasks
      ..clear()
      ..addAll([for (final task in day._tasks) task.copy()]);
    _events
      ..clear()
      ..addAll(day._events);
  }

  @override
  Future<Timeline> fetch({int days = TimelineRepository.defaultDays}) async =>
      _timeline(days);

  @override
  Future<Timeline> createTask({
    required String title,
    required int minutes,
    Placement placement = const Placement.backlog(),
    String? artifactId,
    int days = TimelineRepository.defaultDays,
  }) async {
    final task = _Task(
      'demo-task-${_next++}',
      title,
      minutes,
      backlog: placement.backlog,
      anchor: placement.at,
    );
    if (placement.minutes case final minutes?) task.minutes = minutes;
    final queue = _tasks.where((it) => !it.backlog).toList();
    final index = placement.index;
    if (index != null && index < queue.length) {
      _tasks.insert(_tasks.indexOf(queue[index]), task);
    } else {
      _tasks.add(task);
    }
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
      task
        ..backlog = backlog
        ..anchor = backlog ? null : after;
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
      task
        ..backlog = false
        ..anchor = null;
      _begin(task);
    }
    return _timeline(days);
  }

  @override
  Future<Timeline> snoozeTask(
    String id, {
    int minutes = 15,
    int days = TimelineRepository.defaultDays,
  }) async {
    _task(id)?.anchor = clock.now().add(Duration(minutes: minutes));
    return _timeline(days);
  }

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
    _task(id)?.pausedAt = clock.now();
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
  Future<Timeline> shiftTask(
    String id,
    int minutes, {
    int days = TimelineRepository.defaultDays,
  }) async => _timeline(days);

  @override
  Future<Timeline> swapTasks(
    String id,
    String other, {
    int days = TimelineRepository.defaultDays,
  }) async {
    final a = _tasks.indexWhere((it) => it.id == id);
    final b = _tasks.indexWhere((it) => it.id == other);
    if (a != -1 && b != -1) {
      final task = _tasks[a];
      _tasks[a] = _tasks[b];
      _tasks[b] = task;
    }
    return _timeline(days);
  }

  @override
  Future<Timeline> resize(
    CardKind kind,
    String id,
    int minutes, {
    int days = TimelineRepository.defaultDays,
  }) async {
    _task(id)?.minutes = minutes;
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
    // The demo's day has no routine with a list to tick.
    List<ChecklistItem>? checklist,
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
    task.startedAt = clock.now();
  }

  /// The day as the server would draw it: the begun task where it began,
  /// each anchored one at its hour or the first room after it, and the rest
  /// of the queue one after another in the room left.
  Timeline _timeline(int days) {
    final now = clock.now();
    final dayAt = DateTime(now.year, now.month, now.day);
    final until = DateTime(dayAt.year, dayAt.month, dayAt.day + days);
    final busy = [..._events];
    final tasks = <TimelineEvent>[];
    var cursor = now;

    final queue = _tasks.where((it) => !it.backlog);
    final waiting = queue.where((it) => it.startedAt == null);
    final anchored = waiting.where((it) => it.anchor != null).toList()
      ..sort((a, b) => a.anchor!.compareTo(b.anchor!));
    for (final task in [
      ...queue.where((it) => it.startedAt != null),
      ...anchored,
      ...waiting.where((it) => it.anchor == null),
    ]) {
      final duration = Duration(minutes: task.minutes);
      final from = switch (task.anchor) {
        final anchor? when anchor.isAfter(now) => anchor,
        _? => now,
        null => cursor,
      };
      final start =
          task.startedAt ??
          TimelinePlan.nextFreeStart(busy, duration, now: from);
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
      if (task.anchor == null || task.startedAt != null) {
        cursor = card.endTime.add(TimelinePlan.gap);
      }
    }
    // The running one first, then by their hours.
    tasks.sort(
      (a, b) => a.started != b.started
          ? (a.started ? -1 : 1)
          : a.startTime.compareTo(b.startTime),
    );

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
