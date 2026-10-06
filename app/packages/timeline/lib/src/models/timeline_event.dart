import 'package:equatable/equatable.dart';

/// Which heading a card falls under.
///
/// A section is not a place anything is put. It is what the card's own hour
/// works out to when the list is read, on the server, so a heading is always
/// literally true of everything under it. What is running is Agora; the rest
/// is under the day it falls on, [TimelineEvent.day], as far ahead as the
/// screen was scrolled.
enum TimelineSection {
  /// Running, or overdue and still owed.
  agora('agora'),

  /// Later, under its day.
  dia('dia');

  const TimelineSection(this.wire);

  /// The name the API uses.
  final String wire;

  /// The section [wire] names, defaulting to a day.
  static TimelineSection fromWire(String? wire) {
    return TimelineSection.values.firstWhere(
      (section) => section.wire == wire,
      orElse: () => TimelineSection.dia,
    );
  }
}

/// What a card is.
enum CardKind {
  /// Something to do, with a place in the queue and an hour the queue gives
  /// it. The only kind the list shows.
  task('task', 'tasks'),

  /// A block whose hour is the point of it: a fixed block, a day of a
  /// routine, a meeting.
  event('event', 'events');

  const CardKind(this.wire, this.path);

  /// The name the API uses.
  final String wire;

  /// Where the API keeps this kind: `/tasks` or `/events`.
  final String path;

  /// The kind [wire] names, defaulting to an event.
  static CardKind fromWire(String? wire) {
    return CardKind.values.firstWhere(
      (kind) => kind.wire == wire,
      orElse: () => CardKind.event,
    );
  }
}

/// {@template timeline_event}
/// One card: a task, or an event on the calendar.
///
/// A task has the hour the queue gives it, and keeps it once it is begun.
/// An event has the hour that is the point of it. What the user wants to
/// remember about either goes in [notes].
/// {@endtemplate}
class TimelineEvent extends Equatable {
  /// {@macro timeline_event}
  TimelineEvent({
    required this.id,
    required this.title,
    required this.section,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.kind = CardKind.task,
    DateTime? day,
    this.started = false,
    this.fixed = false,
    this.managed = true,
    this.notes = '',
    this.pausedAt,
    this.remainingSeconds = 0,
    this.pausedSeconds = 0,
    int? workMinutes,
    this.awaitingStart = false,
    this.notBefore,
    this.routine,
  }) : workMinutes = workMinutes ?? durationMinutes,
       day = day ?? DateTime(startTime.year, startTime.month, startTime.day);

  /// Creates a [TimelineEvent] from the API's JSON.
  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      section: TimelineSection.fromWire(json['section'] as String?),
      kind: CardKind.fromWire(json['kind'] as String?),
      day: _day(json['day']),
      started: json['started'] as bool? ?? false,
      startTime: _date(json['startTime']),
      endTime: _date(json['endTime']),
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      fixed: json['fixed'] as bool? ?? false,
      managed: json['managed'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
      pausedAt: _maybeDate(json['pausedAt']),
      remainingSeconds: (json['remainingSeconds'] as num?)?.round() ?? 0,
      pausedSeconds: (json['pausedSeconds'] as num?)?.round() ?? 0,
      workMinutes: json['workMinutes'] as int?,
      awaitingStart: json['awaitingStart'] as bool? ?? false,
      notBefore: _maybeDate(json['notBefore']),
      routine: json['routine'] as String?,
    );
  }

  /// The event id, which is the only name it answers to.
  final String id;

  /// What the block is called.
  final String title;

  /// The heading it falls under.
  final TimelineSection section;

  /// Whether it is a task or an event.
  final CardKind kind;

  /// The day it starts on, at midnight, which is the heading it is drawn
  /// under when it is not running.
  final DateTime day;

  /// Whether it is a task the user began. A begun task has its own hour on
  /// the calendar, and is the one that pauses, runs late and finishes.
  final bool started;

  /// When it starts.
  final DateTime startTime;

  /// When it ends.
  final DateTime endTime;

  /// How long it takes.
  final int durationMinutes;

  /// Whether the hour is the point of it, and so cannot be rearranged.
  final bool fixed;

  /// Whether Lunna booked it.
  ///
  /// A block that is not managed is a meeting that reached the calendar from
  /// somewhere else. It is drawn, because the hour is not free, and it cannot
  /// be dragged or finished, because neither is the app's to do with it.
  final bool managed;

  /// Free text the user keeps on the block.
  final String notes;

  /// When it was paused, or null while it runs.
  ///
  /// A paused block still owes its work, so the server drags its end along
  /// with the clock for as long as this is set.
  final DateTime? pausedAt;

  /// Seconds of work still owed, while paused.
  final int remainingSeconds;

  /// Seconds it spent paused before the current pause.
  final int pausedSeconds;

  /// How long the work takes, pauses left out.
  ///
  /// [durationMinutes] is the span on the calendar, which a pause stretches.
  /// This is what the user estimated, and what the progress bar fills to.
  final int workMinutes;

  /// Whether its hour came and it is waiting for the user to begin it.
  ///
  /// Only a flexible block ever waits. Until the user says so the server
  /// slides it down the day a minute at a time, so the card asks rather than
  /// counting down.
  final bool awaitingStart;

  /// The earliest the server will lay it out, when the user asked for later.
  final DateTime? notBefore;

  /// Which days it repeats on, when it is one day of a routine: `daily`,
  /// `weekdays` or `weekend`.
  final String? routine;

  /// Whether it is something to do, rather than an hour on the calendar.
  bool get isTask => kind == CardKind.task;

  /// Whether it is one day of a routine.
  ///
  /// The routine as a whole changes in the menu. This card is one day of it,
  /// and changing it here changes that day and no other.
  bool get isRoutine => routine != null;

  /// Whether the card can be dragged or finished.
  ///
  /// A meeting is somebody else's hour, so it is never moved from here.
  bool get isInteractive => managed;

  /// Whether its hour is the point of it: any event. Moving one names a new
  /// hour for it rather than a new place in the queue, which only tasks have.
  bool get isAnchored => !isTask;

  /// Whether it is paused.
  bool get isPaused => pausedAt != null;

  /// Whether [now] falls inside it.
  bool isRunningAt(DateTime now) =>
      !startTime.isAfter(now) && endTime.isAfter(now);

  /// How much of the work is done at [now], 0 to 1.
  ///
  /// Time spent paused is not work, so it is taken out, and a paused block
  /// stands still at what it had done when it stopped.
  double progressAt(DateTime now) {
    final total = workMinutes * 60;
    if (total <= 0) return 0;

    final until = pausedAt ?? now;
    final done = until.difference(startTime).inSeconds - pausedSeconds;

    return (done / total).clamp(0.0, 1.0);
  }

  /// Whether [minutes] can come off it at [now] and still leave work to do.
  ///
  /// Five minutes of work at least, and an end that is still ahead: a block
  /// shortened into the past is a block that is done, and that is a
  /// different button.
  bool canShorten(int minutes, DateTime now) {
    return workMinutes - minutes >= 5 &&
        endTime.subtract(Duration(minutes: minutes)).isAfter(now);
  }

  /// A copy with the pause changed, for drawing a tap before the server
  /// answers it.
  TimelineEvent copyWith({
    DateTime? pausedAt,
    bool clearPause = false,
    bool? awaitingStart,
  }) {
    return TimelineEvent(
      id: id,
      title: title,
      section: section,
      kind: kind,
      day: day,
      started: started,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      fixed: fixed,
      managed: managed,
      notes: notes,
      pausedAt: clearPause ? null : pausedAt ?? this.pausedAt,
      remainingSeconds: remainingSeconds,
      pausedSeconds: pausedSeconds,
      workMinutes: workMinutes,
      awaitingStart: awaitingStart ?? this.awaitingStart,
      notBefore: notBefore,
      routine: routine,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    section,
    kind,
    day,
    started,
    startTime,
    endTime,
    durationMinutes,
    fixed,
    managed,
    notes,
    pausedAt,
    remainingSeconds,
    pausedSeconds,
    workMinutes,
    awaitingStart,
    notBefore,
    routine,
  ];
}

DateTime _date(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();
}

DateTime? _maybeDate(Object? value) {
  return DateTime.tryParse(value as String? ?? '')?.toLocal();
}

/// "2026-10-08" as that day at midnight, or null when there is none.
DateTime? _day(Object? value) {
  final parsed = DateTime.tryParse(value as String? ?? '');
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

/// What the user decided about the block that was already running.
enum TimingDecision {
  /// Finish it and give its hour away.
  solveCurrent('solve_current'),

  /// Keep it, further down the day.
  postponeCurrent('postpone_current');

  const TimingDecision(this.wire);

  /// The name the API uses.
  final String wire;
}

/// {@template start_now_guard}
/// The one question the timeline asks: something else is running, and a task
/// was just dropped at the top of the day.
///
/// Both answers start the dropped task now. They differ in what becomes of
/// [currentTitle]: finished, or further down the day.
/// {@endtemplate}
class StartNowGuard extends Equatable {
  /// {@macro start_now_guard}
  const StartNowGuard({
    required this.taskId,
    required this.index,
    required this.currentId,
    required this.currentTitle,
    required this.currentStart,
    required this.currentEnd,
  });

  /// Creates a [StartNowGuard] from the API's JSON.
  factory StartNowGuard.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? const {};

    return StartNowGuard(
      taskId: json['taskId'] as String? ?? '',
      index: json['index'] as int? ?? 0,
      currentId: current['id'] as String? ?? '',
      currentTitle: current['title'] as String? ?? '',
      currentStart: _date(current['startTime']),
      currentEnd: _date(current['endTime']),
    );
  }

  /// The task that was dropped.
  final String taskId;

  /// Where it was dropped.
  final int index;

  /// The block that is running now.
  final String currentId;

  /// What that block is called.
  final String currentTitle;

  /// When it started.
  final DateTime currentStart;

  /// When it ends.
  final DateTime currentEnd;

  /// The answer to send for [decision].
  Map<String, dynamic> answer(TimingDecision decision) => {
    'taskId': taskId,
    'index': index,
    'decision': decision.wire,
  };

  @override
  List<Object?> get props => [
    taskId,
    index,
    currentId,
    currentTitle,
    currentStart,
    currentEnd,
  ];
}

/// {@template timeline}
/// The day, as the server drew it: the list and the calendar, from one read.
///
/// Every write answers with one of these, so the two views are always the
/// same moment. A guard means nothing was applied: the cards that come back
/// are the ones that were already on screen, and they become real only once
/// the guard has been answered or dropped.
/// {@endtemplate}
class Timeline extends Equatable {
  /// {@macro timeline}
  const Timeline({this.tasks = const [], this.cards = const [], this.guard});

  /// Creates a [Timeline] from the API's JSON.
  factory Timeline.fromJson(Map<String, dynamic> json) {
    final rawGuard = json['guard'] as Map<String, dynamic>?;

    return Timeline(
      tasks: _cards(json['tasks']),
      cards: _cards(json['cards']),
      guard: rawGuard == null ? null : StartNowGuard.fromJson(rawGuard),
    );
  }

  /// Every task still to do, in queue order, however far ahead it lands.
  final List<TimelineEvent> tasks;

  /// Everything the calendar draws for the days that were asked for,
  /// earliest first.
  final List<TimelineEvent> cards;

  /// The question to put to the user, when a move raised one.
  final StartNowGuard? guard;

  static List<TimelineEvent> _cards(Object? raw) {
    return (raw as List<dynamic>? ?? <dynamic>[])
        .map((c) => TimelineEvent.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  @override
  List<Object?> get props => [tasks, cards, guard];
}
