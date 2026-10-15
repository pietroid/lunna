import 'package:equatable/equatable.dart';

/// What one change of a plan does.
enum PlanChangeKind {
  /// A new task, at an hour.
  addTask,

  /// A task given another hour, or taken out of the backlog at one.
  moveTask,

  /// A new fixed block.
  addEvent,

  /// A fixed block given another hour.
  moveEvent;

  static PlanChangeKind fromWire(String? value) => switch (value) {
    'add_task' => addTask,
    'add_event' => addEvent,
    'move_event' => moveEvent,
    _ => moveTask,
  };

  /// Whether it adds something rather than moving it.
  bool get adds => this == addTask || this == addEvent;

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
    required this.at,
    this.id,
    this.before,
    this.routine = false,
  });

  factory PlanChange.fromJson(Map<String, dynamic> json) {
    final before = json['before'] as String?;

    return PlanChange(
      kind: PlanChangeKind.fromWire(json['kind'] as String?),
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      at: DateTime.parse(json['at'] as String).toLocal(),
      before: before == null ? null : DateTime.parse(before).toLocal(),
      routine: json['routine'] as bool? ?? false,
    );
  }

  final PlanChangeKind kind;

  /// The card it moves. Null for what it adds.
  final String? id;

  final String title;

  final int minutes;

  /// The hour it will have.
  final DateTime at;

  /// The hour it had, for a move. Null when it came from the backlog.
  final DateTime? before;

  /// Whether it is a day of a routine.
  final bool routine;

  DateTime get end => at.add(Duration(minutes: minutes));

  @override
  List<Object?> get props => [kind, id, title, minutes, at, before, routine];
}

/// {@template agent_plan}
/// Changes the agent proposes. Nothing has happened until it is applied.
/// {@endtemplate}
class AgentPlan extends Equatable {
  /// {@macro agent_plan}
  const AgentPlan({required this.id, required this.changes});

  factory AgentPlan.fromJson(Map<String, dynamic> json) => AgentPlan(
    id: json['id'] as String,
    changes: (json['changes'] as List<dynamic>? ?? [])
        .map((it) => PlanChange.fromJson(it as Map<String, dynamic>))
        .toList(),
  );

  final String id;

  final List<PlanChange> changes;

  @override
  List<Object?> get props => [id, changes];
}

/// {@template agent_reply}
/// What one turn answered.
/// {@endtemplate}
class AgentReply extends Equatable {
  /// {@macro agent_reply}
  const AgentReply({required this.text, this.steps = const [], this.plan});

  factory AgentReply.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>?;

    return AgentReply(
      text: json['reply'] as String? ?? '',
      steps: (json['steps'] as List<dynamic>? ?? []).cast<String>(),
      plan: plan == null ? null : AgentPlan.fromJson(plan),
    );
  }

  final String text;

  /// What the agent did, one short line each.
  final List<String> steps;

  final AgentPlan? plan;

  @override
  List<Object?> get props => [text, steps, plan];
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
enum PlanStatus { pending, applying, applied }

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
  const UserEntry(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// What the agent answered, and where its plan stands.
final class ReplyEntry extends AgentEntry {
  /// {@macro agent_entry}
  const ReplyEntry(this.reply, {this.status = PlanStatus.pending});

  final AgentReply reply;

  final PlanStatus status;

  ReplyEntry withStatus(PlanStatus status) => ReplyEntry(reply, status: status);

  @override
  List<Object?> get props => [reply, status];
}
