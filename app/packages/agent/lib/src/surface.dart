import 'package:agent/src/models.dart';
import 'package:equatable/equatable.dart';

/// {@template answer_block}
/// One component of an answer's surface, from the agent's catalog: what the
/// model chose to show, with every fact filled in by the server.
///
/// The surface draws them in the order they come; the one the model marked
/// as its focus comes first.
/// {@endtemplate}
sealed class AnswerBlock extends Equatable {
  /// {@macro answer_block}
  const AnswerBlock();
}

/// One short line, only for what the other blocks can't show (the reason
/// for an hour). At most one per answer.
final class CaptionBlock extends AnswerBlock {
  /// {@macro answer_block}
  const CaptionBlock(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// Where the reply's plan is drawn. The plan itself is
/// `AgentReply.plan`, so its status is the entry's.
final class PlanBlock extends AnswerBlock {
  /// {@macro answer_block}
  const PlanBlock();

  @override
  List<Object?> get props => [];
}

/// Where the reply's choices are drawn: `AgentReply.options`.
final class ChoicesBlock extends AnswerBlock {
  /// {@macro answer_block}
  const ChoicesBlock();

  @override
  List<Object?> get props => [];
}

/// A slice of one day, as Tempo has it: the cards and the free room between
/// them.
final class DayBlock extends AnswerBlock {
  /// {@macro answer_block}
  const DayBlock({
    required this.day,
    required this.from,
    required this.to,
    required this.items,
  });

  /// The day, at midnight.
  final DateTime day;

  final DateTime from;

  final DateTime to;

  /// In clock order.
  final List<PeekItem> items;

  /// The free room in the slice, in minutes.
  int get free => items
      .where((it) => it.kind == PeekKind.free)
      .fold(0, (sum, it) => sum + it.end.difference(it.start).inMinutes);

  @override
  List<Object?> get props => [day, from, to, items];
}

/// What a row of a [DayBlock] is.
enum PeekKind { task, running, fixed, routine, free }

/// {@template peek_item}
/// One row of a [DayBlock]: a card, or a free stretch.
/// {@endtemplate}
class PeekItem extends Equatable {
  /// {@macro peek_item}
  const PeekItem({
    required this.kind,
    required this.start,
    required this.end,
    this.title = '',
    this.project,
  });

  factory PeekItem.fromJson(Map<String, dynamic> json) => PeekItem(
    kind: PeekKind.values.firstWhere(
      (it) => it.name == json['kind'],
      orElse: () => PeekKind.task,
    ),
    title: json['title'] as String? ?? '',
    start: DateTime.parse(json['start'] as String).toLocal(),
    end: DateTime.parse(json['end'] as String).toLocal(),
    project: json['project'] as String?,
  );

  final PeekKind kind;

  /// Empty for a free stretch.
  final String title;

  final DateTime start;

  final DateTime end;

  /// The project's name, for a task of one.
  final String? project;

  @override
  List<Object?> get props => [kind, title, start, end, project];
}

/// Some cards, picked by the model, in its order, under its heading.
final class CardsBlock extends AnswerBlock {
  /// {@macro answer_block}
  const CardsBlock({required this.cards, this.title});

  final String? title;

  final List<PeekCard> cards;

  @override
  List<Object?> get props => [title, cards];
}

/// {@template peek_card}
/// A task or a block, read only: what Lista says of it, and its notes when
/// they were asked about.
/// {@endtemplate}
class PeekCard extends Equatable {
  /// {@macro peek_card}
  const PeekCard({
    required this.id,
    required this.title,
    required this.minutes,
    this.at,
    this.fixed = false,
    this.done = false,
    this.project,
    this.notes,
  });

  factory PeekCard.fromJson(Map<String, dynamic> json) {
    final at = json['at'] as String?;
    return PeekCard(
      id: json['id'] as String,
      title: json['title'] as String,
      minutes: (json['minutes'] as num).toInt(),
      at: at == null ? null : DateTime.parse(at).toLocal(),
      fixed: json['fixed'] as bool? ?? false,
      done: json['done'] as bool? ?? false,
      project: json['project'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String id;

  final String title;

  final int minutes;

  /// Its hour. Null in Depois eu priorizo.
  final DateTime? at;

  /// Whether it is a fixed block.
  final bool fixed;

  final bool done;

  final String? project;

  final String? notes;

  @override
  List<Object?> get props => [
    id,
    title,
    minutes,
    at,
    fixed,
    done,
    project,
    notes,
  ];
}

/// A project at a glance: the Projetos row, and what comes next in it.
final class ProjectBlock extends AnswerBlock {
  /// {@macro answer_block}
  const ProjectBlock(this.project);

  final PeekProject project;

  @override
  List<Object?> get props => [project];
}

/// {@template peek_project}
/// What [ProjectBlock] draws of a project.
/// {@endtemplate}
class PeekProject extends Equatable {
  /// {@macro peek_project}
  const PeekProject({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.done,
    required this.total,
    this.deadline,
    this.next = const [],
  });

  factory PeekProject.fromJson(Map<String, dynamic> json) {
    final deadline = json['deadline'] as String?;
    return PeekProject(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      // A day, not an instant: midnight where the person is.
      deadline: deadline == null ? null : DateTime.parse(deadline),
      done: (json['done'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      next: (json['next'] as List<dynamic>? ?? [])
          .map((it) => PeekCard.fromJson(it as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;

  final String title;

  /// Where its bar starts.
  final DateTime createdAt;

  final DateTime? deadline;

  /// Tasks ticked off, of [total].
  final int done;

  final int total;

  /// Its next open tasks, at most three: those with an hour first, then the
  /// backlog in its order.
  final List<PeekCard> next;

  /// How much of its time has gone by at [now], 0 to 1; null with no
  /// deadline.
  double? progressAt(DateTime now) {
    final deadline = this.deadline;
    if (deadline == null) return null;
    final whole = deadline.difference(createdAt).inMinutes;
    if (whole <= 0) return 1;
    return (now.difference(createdAt).inMinutes / whole).clamp(0, 1);
  }

  @override
  List<Object?> get props => [
    id,
    title,
    createdAt,
    deadline,
    done,
    total,
    next,
  ];
}

/// {@template agent_surface}
/// One turn's answer, read from the A2UI v0.9 messages the server writes
/// (`createSurface`, `updateComponents`, `updateDataModel`) against our own
/// catalog: the blocks in order, and the plan and choices they draw.
///
/// The only place the app knows A2UI: moving to another version changes
/// this and the server's `toA2ui`, never the widgets. A component it does
/// not know is drawn as a caption when it has a text, and skipped when it
/// has none, as A2UI asks: keep going past what fails.
/// {@endtemplate}
class AgentSurface {
  /// {@macro agent_surface}
  const AgentSurface({
    this.blocks = const [],
    this.plan,
    this.options = const [],
  });

  /// Reads [messages], the `ui` of a turn.
  factory AgentSurface.decode(List<dynamic> messages) {
    final components = <String, Map<String, dynamic>>{};
    final data = <String, dynamic>{};
    for (final message in messages.whereType<Map<String, dynamic>>()) {
      if (message['updateComponents'] case {
        'components': final List<dynamic> list,
      }) {
        for (final it in list.whereType<Map<String, dynamic>>()) {
          if (it['id'] case final String id) components[id] = it;
        }
      }
      if (message['updateDataModel'] case {
        'path': final String path,
        'value': final Object? value,
      }) {
        if (path == '/' && value is Map<String, dynamic>) {
          data.addAll(value);
        } else if (path.startsWith('/')) {
          data[path.substring(1)] = value;
        }
      }
    }

    Object? bound(Object? prop) => switch (prop) {
      {'path': final String path} when path.startsWith('/') =>
        data[path.substring(1)],
      _ => prop,
    };

    final blocks = <AnswerBlock>[];
    AgentPlan? plan;
    var options = <QuickReply>[];
    final children = components['root']?['children'];
    for (final id
        in children is List ? children.whereType<String>() : <String>[]) {
      final it = components[id];
      if (it == null) continue;
      try {
        switch (it['component']) {
          case 'Caption':
            blocks.add(CaptionBlock(it['text'] as String));
          case 'Plan':
            plan = AgentPlan.fromJson(
              bound(it['plan'])! as Map<String, dynamic>,
            );
            blocks.add(const PlanBlock());
          case 'Choices':
            options = (bound(it['options'])! as List<dynamic>)
                .map((it) => QuickReply.fromJson(it as Map<String, dynamic>))
                .toList();
            blocks.add(const ChoicesBlock());
          case 'DayPeek':
            final day = bound(it['day'])! as Map<String, dynamic>;
            blocks.add(
              DayBlock(
                day: DateTime.parse(day['day'] as String),
                from: DateTime.parse(day['from'] as String).toLocal(),
                to: DateTime.parse(day['to'] as String).toLocal(),
                items: (bound(it['items'])! as List<dynamic>)
                    .map((it) => PeekItem.fromJson(it as Map<String, dynamic>))
                    .toList(),
              ),
            );
          case 'Cards':
            blocks.add(
              CardsBlock(
                title: it['title'] as String?,
                cards: (bound(it['cards'])! as List<dynamic>)
                    .map((it) => PeekCard.fromJson(it as Map<String, dynamic>))
                    .toList(),
              ),
            );
          case 'ProjectPeek':
            blocks.add(
              ProjectBlock(
                PeekProject.fromJson(
                  bound(it['project'])! as Map<String, dynamic>,
                ),
              ),
            );
          default:
            if (it['text'] case final String text) {
              blocks.add(CaptionBlock(text));
            }
        }
      } on Object {
        // A component that does not read is skipped; the rest is drawn.
        continue;
      }
    }

    return AgentSurface(blocks: blocks, plan: plan, options: options);
  }

  final List<AnswerBlock> blocks;

  final AgentPlan? plan;

  final List<QuickReply> options;
}
