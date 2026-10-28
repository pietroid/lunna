import 'package:equatable/equatable.dart';

/// `YYYY-MM-DD`, read as that day on this device.
DateTime _day(String raw) {
  final [year, month, day] = raw.split('-').map(int.parse).toList();
  return DateTime(year, month, day);
}

/// {@template catalog_type}
/// One kind of thing she delivers: a natal chart, a post, a course.
///
/// What a delivery of this kind usually takes and is worth, so writing one
/// down is picking it and naming who it is for.
/// {@endtemplate}
class CatalogType extends Equatable {
  /// {@macro catalog_type}
  const CatalogType({
    required this.id,
    required this.name,
    required this.minutes,
    this.price,
    this.blockMinutes,
  });

  /// Reads a kind off the wire.
  factory CatalogType.fromJson(Map<String, dynamic> json) => CatalogType(
    id: json['id'] as String,
    name: json['name'] as String,
    minutes: (json['minutes'] as num).toInt(),
    price: (json['price'] as num?)?.toInt(),
    blockMinutes: (json['blockMinutes'] as num?)?.toInt(),
  );

  /// Its id.
  final String id;

  /// What it is called.
  final String name;

  /// How long one takes, start to finish.
  final int minutes;

  /// What one is worth, in whole reais; null when it earns nothing directly.
  final int? price;

  /// The longest piece of it the day takes at once; null, it goes whole.
  final int? blockMinutes;

  @override
  List<Object?> get props => [id, name, minutes, price, blockMinutes];
}

/// {@template catalog_category}
/// A shelf of the catalogue: Atendimentos, Conteúdo, Produtos.
/// {@endtemplate}
class CatalogCategory extends Equatable {
  /// {@macro catalog_category}
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.types,
  });

  /// Reads a shelf, with its kinds, off the wire.
  factory CatalogCategory.fromJson(Map<String, dynamic> json) =>
      CatalogCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        types: [
          for (final type in json['types'] as List<dynamic>? ?? const [])
            CatalogType.fromJson(type as Map<String, dynamic>),
        ],
      );

  /// Its id.
  final String id;

  /// What it is called.
  final String name;

  /// The kinds on it, in the order she put them.
  final List<CatalogType> types;

  @override
  List<Object?> get props => [id, name, types];
}

/// Where a delivery's task is, as far as the day is concerned.
enum TaskPlace {
  /// In the backlog, "Para depois": no hour, in its order.
  backlog,

  /// In the queue, taking the next free hour it fits.
  queue,

  /// Keeping an hour of its own (an anchor).
  scheduled,

  /// Ticked off.
  done,
}

/// {@template artifact_task}
/// One task of a delivery.
///
/// It is the same task the day draws, in the backlog or on the timeline
/// like any other, and its hour is the queue's to give. [at] is that hour,
/// as the server last worked it out.
/// {@endtemplate}
class ArtifactTask extends Equatable {
  /// {@macro artifact_task}
  const ArtifactTask({
    required this.id,
    required this.title,
    required this.minutes,
    required this.place,
    this.notes = '',
    this.at,
    this.doneAt,
  });

  /// Reads a task off the wire.
  factory ArtifactTask.fromJson(Map<String, dynamic> json) {
    final at = json['at'] as String?;
    final doneAt = json['doneAt'] as String?;
    return ArtifactTask(
      id: json['id'] as String,
      title: json['title'] as String,
      minutes: (json['minutes'] as num).toInt(),
      place: TaskPlace.values.byName(json['place'] as String),
      notes: json['notes'] as String? ?? '',
      at: at == null ? null : DateTime.parse(at).toLocal(),
      doneAt: doneAt == null ? null : DateTime.parse(doneAt).toLocal(),
    );
  }

  /// The task's id, the same one the timeline knows it by.
  final String id;

  /// What it is.
  final String title;

  /// How long it takes.
  final int minutes;

  /// Where it is.
  final TaskPlace place;

  /// The free text kept on it.
  final String notes;

  /// Its hour, when it is on the timeline.
  final DateTime? at;

  /// When it was ticked off.
  final DateTime? doneAt;

  @override
  List<Object?> get props => [id, title, minutes, place, notes, at, doneAt];
}

/// {@template artifact}
/// One delivery: something she owes someone, or the market, by a day.
///
/// It replaces the project. It has a total time, from its kind or given by
/// hand (or else the sum of its tasks), the day may take it whole or a block
/// at a time, and its value counts towards a money goal once delivered.
/// {@endtemplate}
class Artifact extends Equatable {
  /// {@macro artifact}
  const Artifact({
    required this.id,
    required this.title,
    required this.minutes,
    required this.createdAt,
    this.startedAt,
    this.notes = '',
    this.category,
    this.type,
    this.doneMinutes = 0,
    this.value,
    this.deadline,
    this.blockMinutes,
    this.doneAt,
    this.tasks = const [],
  });

  /// Reads a delivery off the wire, finding its kind and shelf in
  /// [catalog]. The deadline is a day, read as that day on this device.
  factory Artifact.fromJson(
    Map<String, dynamic> json, {
    List<CatalogCategory> catalog = const [],
  }) {
    final typeId = json['typeId'] as String?;
    CatalogCategory? category;
    CatalogType? type;
    for (final shelf in catalog) {
      for (final kind in shelf.types) {
        if (kind.id == typeId) (category, type) = (shelf, kind);
      }
    }
    final deadline = json['deadline'] as String?;
    final doneAt = json['doneAt'] as String?;
    final startedAt = json['startedAt'] as String?;
    return Artifact(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      startedAt: startedAt == null ? null : DateTime.parse(startedAt).toLocal(),
      category: category,
      type: type,
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      doneMinutes: (json['doneMinutes'] as num?)?.toInt() ?? 0,
      value: (json['value'] as num?)?.toInt(),
      blockMinutes: (json['blockMinutes'] as num?)?.toInt(),
      deadline: deadline == null ? null : _day(deadline),
      doneAt: doneAt == null ? null : DateTime.parse(doneAt).toLocal(),
      tasks: [
        for (final task in json['tasks'] as List<dynamic>? ?? const [])
          ArtifactTask.fromJson(task as Map<String, dynamic>),
      ],
    );
  }

  /// Its id.
  final String id;

  /// What it is called, usually the kind and who it is for.
  final String title;

  /// Free text.
  final String notes;

  /// When it was written down, which is where its bar starts.
  final DateTime createdAt;

  /// When it was begun: moved into Em andamento, or a task of it begun on
  /// the day. Null while it waits in Não iniciadas. Its time runs from here.
  final DateTime? startedAt;

  /// The shelf it came from; null for a one-off.
  final CatalogCategory? category;

  /// The kind it is; null for a one-off.
  final CatalogType? type;

  /// How long it takes in all.
  final int minutes;

  /// How much of that its finished tasks took.
  final int doneMinutes;

  /// What it is worth, in whole reais.
  final int? value;

  /// The day it is due by.
  final DateTime? deadline;

  /// The longest piece of it the day takes at once.
  final int? blockMinutes;

  /// When it was delivered.
  final DateTime? doneAt;

  /// Its tasks, in their order.
  final List<ArtifactTask> tasks;

  /// Whether it has been delivered.
  bool get isDone => doneAt != null;

  /// How many steps (tasks) it has.
  int get steps => tasks.length;

  /// How many of its tasks are done.
  int get stepsDone => tasks.where((t) => t.place == TaskPlace.done).length;

  /// The moment it is due: the end of its deadline's day.
  DateTime? get dueAt {
    final day = deadline;
    if (day == null) return null;
    return DateTime(day.year, day.month, day.day + 1);
  }

  /// How much of its time has gone by, from 0 to 1: the time since it was
  /// begun out of the time from then to the end of its deadline's day.
  /// Null with no deadline or not begun, since no clock runs then.
  double? progressAt(DateTime now) {
    final due = dueAt;
    final start = startedAt;
    if (due == null || start == null) return null;

    final total = due.difference(start).inMinutes;
    if (total <= 0) return 1;
    return (now.difference(start).inMinutes / total).clamp(0, 1);
  }

  /// Whole days from [now]'s day to the deadline: 0 on the day itself,
  /// negative once it has passed. Null with no deadline.
  int? daysLeftAt(DateTime now) {
    final day = deadline;
    if (day == null) return null;
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }

  /// A copy with the given fields changed.
  Artifact copyWith({
    String? title,
    DateTime? Function()? deadline,
    DateTime? Function()? doneAt,
    DateTime? Function()? startedAt,
    int? Function()? value,
    String? notes,
    List<ArtifactTask>? tasks,
  }) {
    return Artifact(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      startedAt: startedAt == null ? this.startedAt : startedAt(),
      category: category,
      type: type,
      minutes: minutes,
      doneMinutes: doneMinutes,
      value: value == null ? this.value : value(),
      blockMinutes: blockMinutes,
      deadline: deadline == null ? this.deadline : deadline(),
      doneAt: doneAt == null ? this.doneAt : doneAt(),
      tasks: tasks ?? this.tasks,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    notes,
    createdAt,
    startedAt,
    category,
    type,
    minutes,
    doneMinutes,
    value,
    deadline,
    blockMinutes,
    doneAt,
    tasks,
  ];
}

/// What a goal counts.
enum GoalKind {
  /// Money earned by what was delivered.
  money,

  /// Deliveries of one kind.
  count,
}

/// {@template goal}
/// An amount to reach by a day: R\$ 10.000 billed by 30 November.
///
/// Goals follow each other: each counts what was delivered from its
/// [start] to its last day. What the open deliveries due by then would
/// add is [queued]: no delivery names a goal, the server finds them.
/// {@endtemplate}
class Goal extends Equatable {
  /// {@macro goal}
  const Goal({
    required this.id,
    required this.kind,
    required this.target,
    required this.start,
    required this.end,
    this.done = 0,
    this.queued = 0,
    this.queuedCount = 0,
    this.type,
  });

  /// Reads a goal off the wire, finding the kind it counts in [catalog].
  factory Goal.fromJson(
    Map<String, dynamic> json, {
    List<CatalogCategory> catalog = const [],
  }) {
    final typeId = json['typeId'] as String?;
    return Goal(
      id: json['id'] as String,
      kind: GoalKind.values.byName(json['kind'] as String),
      target: (json['target'] as num).toInt(),
      start: _day(json['start'] as String),
      end: _day(json['end'] as String),
      done: (json['done'] as num?)?.toInt() ?? 0,
      queued: (json['queued'] as num?)?.toInt() ?? 0,
      queuedCount: (json['queuedCount'] as num?)?.toInt() ?? 0,
      type: catalog
          .expand((c) => c.types)
          .where((t) => t.id == typeId)
          .firstOrNull,
    );
  }

  /// Its id.
  final String id;

  /// What it counts.
  final GoalKind kind;

  /// The number to reach: reais, or deliveries.
  final int target;

  /// Its first day.
  final DateTime start;

  /// The day after its last.
  final DateTime end;

  /// What has been reached so far.
  final int done;

  /// What the open deliveries due by its last day would add, were they
  /// delivered in time.
  final int queued;

  /// How many open deliveries [queued] adds up.
  final int queuedCount;

  /// The kind counted, for a [GoalKind.count] goal.
  final CatalogType? type;

  /// Whether it is being measured on [now], rather than waiting to start.
  bool isActiveAt(DateTime now) => !now.isBefore(start);

  /// Whether its last day has gone by at [now].
  bool isOverAt(DateTime now) => !now.isBefore(end);

  /// The day it is to be reached by: the last it counts.
  DateTime get lastDay => DateTime(end.year, end.month, end.day - 1);

  /// The share of its time gone at [now], from 0 to 1: calendar time, from
  /// the start of its first day to the end of its last.
  double timeAt(DateTime now) {
    final whole = end.difference(start).inMinutes;
    if (whole <= 0) return 1;
    return (now.difference(start).inMinutes / whole).clamp(0, 1);
  }

  /// What it asks to have been reached by [now], were it reached evenly
  /// over its days: the red of its bar.
  int expectedAt(DateTime now) => (target * timeAt(now)).round();

  @override
  List<Object?> get props => [
    id,
    kind,
    target,
    start,
    end,
    done,
    queued,
    queuedCount,
    type,
  ];
}

/// {@template schedule}
/// The agenda against the queue: the time the deliveries due by [until]
/// still need, and the free working time left until then.
/// {@endtemplate}
class Schedule extends Equatable {
  /// {@macro schedule}
  const Schedule({
    required this.needMinutes,
    required this.freeMinutes,
    required this.until,
  });

  /// Reads it off the wire.
  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
    needMinutes: (json['needMinutes'] as num).toInt(),
    freeMinutes: (json['freeMinutes'] as num).toInt(),
    until: _day(json['until'] as String),
  );

  /// What the deliveries due by [until] still need.
  final int needMinutes;

  /// The free working time on the agenda until the end of [until].
  final int freeMinutes;

  /// The last day counted: the end of this month.
  final DateTime until;

  @override
  List<Object?> get props => [needMinutes, freeMinutes, until];
}

/// {@template artifacts_data}
/// Everything Entregas draws, as the server last sent it.
/// {@endtemplate}
class ArtifactsData extends Equatable {
  /// {@macro artifacts_data}
  const ArtifactsData({
    required this.schedule,
    this.artifacts = const [],
    this.catalog = const [],
    this.goals = const [],
    this.topTypes = const [],
  });

  /// Reads the server's answer.
  factory ArtifactsData.fromJson(Map<String, dynamic> json) {
    final catalog = [
      for (final shelf in json['catalog'] as List<dynamic>? ?? const [])
        CatalogCategory.fromJson(shelf as Map<String, dynamic>),
    ];
    final types = {
      for (final type in catalog.expand((c) => c.types)) type.id: type,
    };
    return ArtifactsData(
      artifacts: [
        for (final it in json['artifacts'] as List<dynamic>? ?? const [])
          Artifact.fromJson(it as Map<String, dynamic>, catalog: catalog),
      ],
      catalog: catalog,
      goals: [
        for (final it in json['goals'] as List<dynamic>? ?? const [])
          Goal.fromJson(it as Map<String, dynamic>, catalog: catalog),
      ],
      schedule: Schedule.fromJson(json['schedule'] as Map<String, dynamic>),
      topTypes: [
        for (final id in json['topTypes'] as List<dynamic>? ?? const [])
          ?types[id],
      ],
    );
  }

  /// Every delivery: the open ones in their order, then the delivered,
  /// newest first.
  final List<Artifact> artifacts;

  /// The catalogue's shelves, with their kinds.
  final List<CatalogCategory> catalog;

  /// The goals, those being measured first, then those to come.
  final List<Goal> goals;

  /// The agenda against the queue.
  final Schedule schedule;

  /// The kinds she uses most, most used first.
  final List<CatalogType> topTypes;

  /// The deliveries not made yet, in order of priority.
  List<Artifact> get queue => [
    for (final a in artifacts)
      if (!a.isDone) a,
  ];

  /// The deliveries made, newest first.
  List<Artifact> get done => [
    for (final a in artifacts)
      if (a.isDone) a,
  ];

  @override
  List<Object?> get props => [artifacts, catalog, goals, schedule, topTypes];
}
