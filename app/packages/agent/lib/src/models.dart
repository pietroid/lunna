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
  });

  factory AgentPlan.fromJson(Map<String, dynamic> json) => AgentPlan(
    id: json['id'] as String,
    changes: (json['changes'] as List<dynamic>? ?? [])
        .map((it) => PlanChange.fromJson(it as Map<String, dynamic>))
        .toList(),
    pushed: (json['pushed'] as List<dynamic>? ?? [])
        .map((it) => PushedTask.fromJson(it as Map<String, dynamic>))
        .toList(),
  );

  final String id;

  final List<PlanChange> changes;

  /// What applying it pushes later, which the person is asked about.
  final List<PushedTask> pushed;

  @override
  List<Object?> get props => [id, changes, pushed];
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
  const ReplyEntry(this.reply, {this.status = PlanStatus.pending});

  final AgentReply reply;

  final PlanStatus status;

  ReplyEntry withStatus(PlanStatus status) => ReplyEntry(reply, status: status);

  @override
  List<Object?> get props => [reply, status];
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
