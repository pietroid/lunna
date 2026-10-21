/// {@template catalog_type}
/// One kind of thing she delivers: a natal chart, a post, a course.
///
/// What a delivery of this kind usually takes and is worth, so writing one
/// down is picking it and naming who it is for.
/// {@endtemplate}
class CatalogType {
  /// {@macro catalog_type}
  const CatalogType({
    required this.id,
    required this.name,
    required this.minutes,
    this.price,
    this.blockMinutes,
  });

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
}

/// {@template catalog_category}
/// A shelf of the catalogue: Atendimentos, Conteúdo, Produtos.
/// {@endtemplate}
class CatalogCategory {
  /// {@macro catalog_category}
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.types,
  });

  /// Its id.
  final String id;

  /// What it is called.
  final String name;

  /// The kinds on it, in the order she put them.
  final List<CatalogType> types;
}

/// {@template artifact}
/// One delivery: something she owes someone, or the market, by a day.
///
/// It replaces the project. It has a total time, from its kind or given by
/// hand, and the day may take it whole or a block at a time.
/// {@endtemplate}
class Artifact {
  /// {@macro artifact}
  const Artifact({
    required this.id,
    required this.title,
    required this.minutes,
    this.category,
    this.type,
    this.doneMinutes = 0,
    this.stepsDone = 0,
    this.steps = 0,
    this.value,
    this.deadline,
    this.blockMinutes,
    this.doneAt,
  });

  /// Its id.
  final String id;

  /// What it is called, usually the kind and who it is for.
  final String title;

  /// The shelf it came from; null for a loose one.
  final CatalogCategory? category;

  /// The kind it is; null for a loose one.
  final CatalogType? type;

  /// How long it takes in all.
  final int minutes;

  /// How much of that has been worked.
  final int doneMinutes;

  /// Its steps ticked off, when it has any.
  final int stepsDone;

  /// How many steps it has; zero when it has none.
  final int steps;

  /// What it is worth, in whole reais.
  final int? value;

  /// The day it is due.
  final DateTime? deadline;

  /// The longest piece of it the day takes at once.
  final int? blockMinutes;

  /// When it was delivered.
  final DateTime? doneAt;

  /// Whether it has been delivered.
  bool get isDone => doneAt != null;
}

/// What a goal counts.
enum GoalKind {
  /// Money earned by what was delivered.
  money,

  /// Deliveries of one kind.
  count,
}

/// The stretch a goal is measured over.
enum GoalPeriod {
  /// A week, Monday to Sunday.
  week,

  /// A calendar month.
  month,
}

/// {@template goal}
/// A number to reach in a stretch of time: R$ 8.000 in October, three posts
/// a week.
///
/// What counts towards it is what was delivered; what is in the queue is
/// what could still count.
/// {@endtemplate}
class Goal {
  /// {@macro goal}
  const Goal({
    required this.id,
    required this.kind,
    required this.period,
    required this.target,
    required this.start,
    required this.end,
    this.done = 0,
    this.queued = 0,
    this.type,
  });

  /// Its id.
  final String id;

  /// What it counts.
  final GoalKind kind;

  /// The stretch it repeats over.
  final GoalPeriod period;

  /// The number to reach: reais, or deliveries.
  final int target;

  /// The first day of the stretch being measured.
  final DateTime start;

  /// The day after its last.
  final DateTime end;

  /// What has been reached so far.
  final int done;

  /// What the queue holds that would count, were it delivered in time.
  final int queued;

  /// The kind counted, for a [GoalKind.count] goal.
  final CatalogType? type;

  /// Whether it is being measured on [now], rather than waiting to start.
  bool isActiveAt(DateTime now) => !now.isBefore(start);
}
