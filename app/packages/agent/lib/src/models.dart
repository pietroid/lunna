import 'package:agent/src/surface.dart';
import 'package:equatable/equatable.dart';

/// {@template agent_subject}
/// What a conversation is about, when it is opened from a page rather than
/// from Tempo: a task's, or an artifact's. The agent reads it, with its notes,
/// and "isso" means it.
/// {@endtemplate}
class AgentSubject extends Equatable {
  /// The task [id], from its page.
  const AgentSubject.task(String id) : taskId = id, artifactId = null;

  /// The artifact [id], from its page.
  const AgentSubject.artifact(String id) : artifactId = id, taskId = null;

  final String? taskId;
  final String? artifactId;

  Map<String, String> toJson() => {
    'taskId': ?taskId,
    'artifactId': ?artifactId,
  };

  @override
  List<Object?> get props => [taskId, artifactId];
}

/// What one change of a plan does.
enum PlanChangeKind {
  /// A new task, at an hour.
  addTask,

  /// A task given another hour, or taken out of the backlog at one.
  moveTask,

  /// A new fixed block.
  addEvent,

  /// A fixed block given another hour.
  moveEvent,

  /// A task put in Para depois, or written down there: no hour.
  toBacklog,

  /// A task or a block renamed, or given another length.
  edit,

  /// Text added at the end of a card's or an artifact's notes.
  note,

  /// A task or a block ticked off.
  done,

  /// A task or a block deleted.
  remove,

  /// A new artifact, with the tasks it starts with.
  addArtifact,

  /// An artifact renamed, given another deadline, or closed.
  editArtifact,

  /// An artifact deleted, and the tasks of its backlog with it.
  removeArtifact,

  /// An artifact delivered: its value counts towards the goals.
  deliver,

  /// An artifact given another place in the queue of deliveries.
  moveArtifact,

  /// A new kind in the catalogue.
  addKind,

  /// A new goal.
  addGoal,

  /// A goal deleted.
  removeGoal;

  static PlanChangeKind fromWire(String? value) => switch (value) {
    'add_task' => addTask,
    'add_event' => addEvent,
    'move_event' => moveEvent,
    'to_backlog' => toBacklog,
    'edit' => edit,
    'note' => note,
    'done' => done,
    'remove' => remove,
    // Kept conversations may still say project.
    'add_artifact' || 'add_project' => addArtifact,
    'edit_artifact' || 'edit_project' => editArtifact,
    'remove_artifact' || 'remove_project' => removeArtifact,
    'deliver' => deliver,
    'move_artifact' => moveArtifact,
    'add_kind' => addKind,
    'add_goal' => addGoal,
    'remove_goal' => removeGoal,
    _ => moveTask,
  };

  /// Whether it adds something rather than moving it.
  bool get adds =>
      this == addTask ||
      this == addEvent ||
      this == addArtifact ||
      this == addKind ||
      this == addGoal;

  /// Whether it deletes something: drawn first, and the plan's button says
  /// so.
  bool get deletes =>
      this == remove || this == removeArtifact || this == removeGoal;

  /// Whether it is about a fixed block.
  bool get fixed => this == addEvent || this == moveEvent;
}

/// {@template plan_change}
/// One line of a plan.
/// {@endtemplate}
class PlanChange extends Equatable {
  /// {@macro plan_change}
  const PlanChange({
    required this.kind,
    required this.title,
    required this.minutes,
    this.at,
    this.id,
    this.before,
    this.routine = false,
    this.place,
    this.was,
    this.wasMinutes,
    this.note,
    this.artifact,
    this.deadline,
    this.wasDeadline,
    this.takes = const [],
    this.value,
    this.shelf,
    this.goal,
  });

  factory PlanChange.fromJson(Map<String, dynamic> json) {
    final at = json['at'] as String?;
    final before = json['before'] as String?;
    final place = json['place'] as Map<String, dynamic>?;
    final deadline = json['deadline'] as String?;
    final wasDeadline = json['wasDeadline'] as String?;
    final goal = json['goal'] as Map<String, dynamic>?;

    return PlanChange(
      kind: PlanChangeKind.fromWire(json['kind'] as String?),
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      at: at == null ? null : DateTime.parse(at).toLocal(),
      before: before == null ? null : DateTime.parse(before).toLocal(),
      routine: json['routine'] as bool? ?? false,
      place: place == null ? null : PlanPlace.fromJson(place),
      was: json['was'] as String?,
      note: json['note'] as String?,
      artifact: json['artifact'] as String?,
      // A day, read as that day wherever the phone is.
      deadline: deadline == null ? null : DateTime.parse(deadline),
      wasDeadline: wasDeadline == null ? null : DateTime.parse(wasDeadline),
      takes: [
        for (final it in json['takes'] as List<dynamic>? ?? const [])
          it as String,
      ],
      value: (json['value'] as num?)?.toInt(),
      shelf: json['shelf'] as String?,
      goal: goal == null ? null : PlanGoal.fromJson(goal),
    );
  }

  final PlanChangeKind kind;

  /// The card it moves. Null for what it adds.
  final String? id;

  final String title;

  final int minutes;

  /// The hour it will have. Null in the backlog, which has none.
  final DateTime? at;

  /// The hour it had, for a move. Null when it came from the backlog.
  final DateTime? before;

  /// Whether it is a day of a routine.
  final bool routine;

  /// The place in the queue it takes, when it takes one rather than an hour
  /// of its own: [at] is then only where the queue packs it today.
  final PlanPlace? place;

  /// The name it had, when [kind] renames it.
  final String? was;

  /// The length it had, when [kind] gives it another.
  final int? wasMinutes;

  /// The text a [PlanChangeKind.note] adds, in full.
  final String? note;

  /// The artifact it belongs to.
  final String? artifact;

  /// An artifact's deadline, as the change leaves it.
  final DateTime? deadline;

  /// An artifact's deadline before the change.
  final DateTime? wasDeadline;

  /// What goes with it: the tasks a deleted artifact takes along, the ones
  /// a new artifact starts with, or the ones a delivered one leaves open.
  final List<String> takes;

  /// What it is worth, in whole reais: an artifact's value, a kind's price.
  final int? value;

  /// The catalogue shelf a new kind goes on.
  final String? shelf;

  /// What a goal counts, for a goal added or deleted.
  final PlanGoal? goal;

  DateTime? get end => at?.add(Duration(minutes: minutes));

  @override
  List<Object?> get props => [
    kind,
    id,
    title,
    minutes,
    at,
    before,
    routine,
    place,
    was,
    wasMinutes,
    note,
    artifact,
    deadline,
    wasDeadline,
    takes,
    value,
    shelf,
    goal,
  ];
}

/// {@template plan_goal}
/// What a goal counts: reais delivered, or deliveries of one kind, per week
/// or per month.
/// {@endtemplate}
class PlanGoal extends Equatable {
  /// {@macro plan_goal}
  const PlanGoal({
    required this.money,
    required this.monthly,
    required this.target,
  });

  factory PlanGoal.fromJson(Map<String, dynamic> json) => PlanGoal(
    money: json['kind'] == 'money',
    monthly: json['period'] == 'month',
    target: (json['target'] as num?)?.toInt() ?? 0,
  );

  /// Reais delivered, rather than a count of one kind.
  final bool money;

  /// Per month, rather than per week.
  final bool monthly;

  final int target;

  @override
  List<Object?> get props => [money, monthly, target];
}

/// {@template plan_place}
/// A place in the queue, named by the cards around it, as a drag between
/// them would leave it. Neither named: the end of the queue.
/// {@endtemplate}
class PlanPlace extends Equatable {
  /// {@macro plan_place}
  const PlanPlace({this.after, this.before});

  factory PlanPlace.fromJson(Map<String, dynamic> json) => PlanPlace(
    after: json['after'] as String?,
    before: json['before'] as String?,
  );

  /// The title of the card right above it.
  final String? after;

  /// The title of the card right under it.
  final String? before;

  @override
  List<Object?> get props => [after, before];
}

/// What a plan took without being told, which its card names.
enum PlanAssumptionKind {
  /// How long it takes.
  minutes,

  /// That it is for today.
  today,

  /// That it goes at the end of the queue.
  endOfQueue;

  static PlanAssumptionKind? fromWire(String? value) => switch (value) {
    'minutes' => minutes,
    'today' => today,
    'end_of_queue' => endOfQueue,
    _ => null,
  };
}

/// {@template plan_assumption}
/// One thing a plan took without being told: never silent.
/// {@endtemplate}
class PlanAssumption extends Equatable {
  /// {@macro plan_assumption}
  const PlanAssumption(this.kind, {this.minutes});

  final PlanAssumptionKind kind;

  /// The length taken, for [PlanAssumptionKind.minutes].
  final int? minutes;

  @override
  List<Object?> get props => [kind, minutes];
}

/// {@template pushed_task}
/// A task a plan does not name that would start later because of it, as the
/// queue flows on after something put in its way.
/// {@endtemplate}
class PushedTask extends Equatable {
  /// {@macro pushed_task}
  const PushedTask({
    required this.id,
    required this.title,
    required this.before,
    required this.at,
  });

  factory PushedTask.fromJson(Map<String, dynamic> json) => PushedTask(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    before: DateTime.parse(json['before'] as String).toLocal(),
    at: DateTime.parse(json['at'] as String).toLocal(),
  );

  final String id;

  final String title;

  /// The hour it has now.
  final DateTime before;

  /// The hour it would have.
  final DateTime at;

  @override
  List<Object?> get props => [id, title, before, at];
}

/// {@template agent_plan}
/// Changes the agent proposes. Nothing has happened until it is applied.
/// {@endtemplate}
class AgentPlan extends Equatable {
  /// {@macro agent_plan}
  const AgentPlan({
    required this.id,
    required this.changes,
    this.pushed = const [],
    this.assumed = const [],
  });

  factory AgentPlan.fromJson(Map<String, dynamic> json) => AgentPlan(
    id: json['id'] as String,
    changes: (json['changes'] as List<dynamic>? ?? [])
        .map((it) => PlanChange.fromJson(it as Map<String, dynamic>))
        .toList(),
    pushed: (json['pushed'] as List<dynamic>? ?? [])
        .map((it) => PushedTask.fromJson(it as Map<String, dynamic>))
        .toList(),
    assumed: [
      for (final it
          in (json['assumed'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>())
        if (PlanAssumptionKind.fromWire(it['kind'] as String?) case final kind?)
          PlanAssumption(kind, minutes: (it['minutes'] as num?)?.toInt()),
    ],
  );

  final String id;

  final List<PlanChange> changes;

  /// What applying it pushes later, which the person is asked about.
  final List<PushedTask> pushed;

  /// What it took without being told.
  final List<PlanAssumption> assumed;

  @override
  List<Object?> get props => [id, changes, pushed, assumed];
}

/// {@template quick_reply}
/// An answer the agent offers, ready to tap: its plan, made with no other
/// turn. The label is the server's, in Portuguese.
/// {@endtemplate}
class QuickReply extends Equatable {
  /// {@macro quick_reply}
  const QuickReply({required this.label, this.plan, this.say});

  factory QuickReply.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>?;
    return QuickReply(
      label: json['label'] as String? ?? '',
      plan: plan == null ? null : AgentPlan.fromJson(plan),
      say: json['say'] as String?,
    );
  }

  final String label;

  /// The plan a tap applies, with no other turn.
  final AgentPlan? plan;

  /// Without a plan: what a tap says, as the user's next message.
  final String? say;

  @override
  List<Object?> get props => [label, plan, say];
}

/// {@template agent_reply}
/// What one turn answered.
/// {@endtemplate}
class AgentReply extends Equatable {
  /// {@macro agent_reply}
  const AgentReply({
    required this.text,
    this.steps = const [],
    this.plan,
    this.options = const [],
    this.blocks = const [],
  });

  factory AgentReply.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as List<dynamic>? ?? []).cast<String>();
    if (json['ui'] case final List<dynamic> ui when ui.isNotEmpty) {
      final surface = AgentSurface.decode(ui);
      return AgentReply(
        text: json['reply'] as String? ?? '',
        steps: steps,
        plan: surface.plan,
        options: surface.options,
        blocks: surface.blocks,
      );
    }

    final plan = json['plan'] as Map<String, dynamic>?;
    return AgentReply(
      text: json['reply'] as String? ?? '',
      steps: (json['steps'] as List<dynamic>? ?? []).cast<String>(),
      plan: plan == null ? null : AgentPlan.fromJson(plan),
      options: (json['options'] as List<dynamic>? ?? [])
          .map((it) => QuickReply.fromJson(it as Map<String, dynamic>))
          .toList(),
    );
  }

  final String text;

  /// What the agent did, one short line each.
  final List<String> steps;

  final AgentPlan? plan;

  /// The answers offered to tap, when the agent asks, or offers another way
  /// beside [plan].
  final List<QuickReply> options;

  /// The answer's surface, block by block. Empty for a reply from before
  /// the catalog, which draws [text], [plan] and [options] as they come.
  final List<AnswerBlock> blocks;

  /// Every plan the reply can make: its own, then its options'.
  Iterable<AgentPlan> get plans => [?plan, for (final it in options) ?it.plan];

  @override
  List<Object?> get props => [text, steps, plan, options, blocks];
}

/// {@template agent_suggestion}
/// A plan offered without being asked, and the sentence that offers it.
/// {@endtemplate}
class AgentSuggestion extends Equatable {
  /// {@macro agent_suggestion}
  const AgentSuggestion({required this.text, required this.plan});

  factory AgentSuggestion.fromJson(Map<String, dynamic> json) =>
      AgentSuggestion(
        text: json['text'] as String? ?? '',
        plan: AgentPlan.fromJson(json['plan'] as Map<String, dynamic>),
      );

  final String text;

  final AgentPlan plan;

  @override
  List<Object?> get props => [text, plan];
}

/// Where a plan shown in the conversation stands.
enum PlanStatus {
  pending,
  applying,
  applied,

  /// Applied, then taken back.
  undone;

  static PlanStatus fromWire(String? value) => switch (value) {
    'applied' => applied,
    'undone' => undone,
    _ => pending,
  };
}

/// {@template agent_entry}
/// One bubble of the conversation.
/// {@endtemplate}
sealed class AgentEntry extends Equatable {
  /// {@macro agent_entry}
  const AgentEntry();
}

/// What the user said.
final class UserEntry extends AgentEntry {
  /// {@macro agent_entry}
  const UserEntry(this.text, {this.voice});

  final String text;

  /// How long the user spoke for, when it was said rather than typed.
  ///
  /// Only the app keeps it; the agent reads the text alone.
  final Duration? voice;

  @override
  List<Object?> get props => [text, voice];
}

/// What the agent answered, and where its plan stands.
final class ReplyEntry extends AgentEntry {
  /// {@macro agent_entry}
  const ReplyEntry(
    this.reply, {
    this.status = PlanStatus.pending,
    this.chosen,
  });

  final AgentReply reply;

  final PlanStatus status;

  /// The plan [status] is about, once one of [AgentReply.plans] was taken.
  final String? chosen;

  ReplyEntry withStatus(PlanStatus status, {String? chosen}) =>
      ReplyEntry(reply, status: status, chosen: chosen ?? this.chosen);

  @override
  List<Object?> get props => [reply, status, chosen];
}

/// {@template past_conversation}
/// A conversation had before this one, kept for the user to read back.
///
/// It is not the agent's context: a new conversation starts with nothing of
/// it, and the agent looks the past up only when asked about it.
/// {@endtemplate}
class PastConversation extends Equatable {
  /// {@macro past_conversation}
  const PastConversation({
    required this.id,
    required this.startedAt,
    required this.entries,
  });

  factory PastConversation.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return PastConversation(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
      entries: [
        for (final message in messages)
          if (message['role'] == 'assistant')
            ReplyEntry(
              AgentReply(
                text: message['text'] as String? ?? '',
                steps: (message['steps'] as List<dynamic>? ?? [])
                    .cast<String>(),
                plan: message['plan'] is Map<String, dynamic>
                    ? AgentPlan.fromJson(
                        message['plan'] as Map<String, dynamic>,
                      )
                    : null,
              ),
              status: PlanStatus.fromWire(message['planStatus'] as String?),
            )
          else
            UserEntry(
              message['text'] as String? ?? '',
              voice: switch (message['voiceSeconds']) {
                final num seconds => Duration(seconds: seconds.round()),
                _ => null,
              },
            ),
      ],
    );
  }

  final String id;

  /// When its first message was said.
  final DateTime startedAt;

  final List<AgentEntry> entries;

  @override
  List<Object?> get props => [id, startedAt, entries];
}
