import 'package:agent/src/models.dart';
import 'package:equatable/equatable.dart';
import 'package:timeline/timeline.dart';

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

/// What the reply's plan would make, drawn by the widgets of the tabs it
/// lands on (a goal as Objetivos draws it, a delivery as Entregas, a
/// routine as Rotina), on the page's own background. The server fills
/// every number from the dry run.
///
/// It turns the reply into three parts: the words above it, the preview,
/// and the plan under it as [applies] with Ajustar and Aplicar.
final class PreviewBlock extends AnswerBlock {
  /// {@macro answer_block}
  const PreviewBlock({required this.items, this.applies});

  final List<PreviewItem> items;

  /// What Aplicar makes, in a line, for what the preview can't draw ("Aplicar
  /// anota a meta e as duas entregas.").
  final String? applies;

  @override
  List<Object?> get props => [items, applies];
}

/// {@template preview_item}
/// One thing a plan would make, as its tab will draw it.
/// {@endtemplate}
sealed class PreviewItem extends Equatable {
  /// {@macro preview_item}
  const PreviewItem();

  /// The item the server wrote, or null for a type this build does not draw.
  static PreviewItem? fromJson(Map<String, dynamic> json) {
    int whole(Object? it) => (it as num?)?.round() ?? 0;
    DateTime? day(Object? it) => it is String ? DateTime.parse(it) : null;
    return switch (json['type']) {
      'goal' => GoalPreview(
        target: whole(json['target']),
        start: day(json['start'])!,
        end: day(json['end'])!,
        done: whole(json['done']),
        queued: whole(json['queued']),
        queuedCount: whole(json['queuedCount']),
      ),
      'artifact' => ArtifactPreview(
        title: json['title'] as String? ?? '',
        minutes: whole(json['minutes']),
        deadline: day(json['deadline']),
        value: json['value'] == null ? null : whole(json['value']),
      ),
      _ => null,
    };
  }
}

/// A goal, with what the open deliveries due by its end would bring in.
final class GoalPreview extends PreviewItem {
  /// {@macro preview_item}
  const GoalPreview({
    required this.target,
    required this.start,
    required this.end,
    this.done = 0,
    this.queued = 0,
    this.queuedCount = 0,
  });

  /// In whole reais.
  final int target;

  final DateTime start;

  /// The day after its last.
  final DateTime end;

  /// What was delivered in it so far.
  final int done;

  /// What the open deliveries due by [end] are worth, the plan's included.
  final int queued;

  final int queuedCount;

  @override
  List<Object?> get props => [target, start, end, done, queued, queuedCount];
}

/// A delivery.
final class ArtifactPreview extends PreviewItem {
  /// {@macro preview_item}
  const ArtifactPreview({
    required this.title,
    required this.minutes,
    this.deadline,
    this.value,
  });

  final String title;

  final int minutes;

  final DateTime? deadline;

  /// In whole reais.
  final int? value;

  @override
  List<Object?> get props => [title, minutes, deadline, value];
}

/// A routine, with its checklist.
final class RoutinePreview extends PreviewItem {
  /// {@macro preview_item}
  const RoutinePreview({
    required this.title,
    required this.startMinute,
    required this.minutes,
    required this.days,
    this.checklist = const [],
  });

  final String title;

  /// Minutes past midnight, in the person's zone.
  final int startMinute;

  final int minutes;

  final RoutineDays days;

  final List<String> checklist;

  @override
  List<Object?> get props => [title, startMinute, minutes, days, checklist];
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
    this.artifact,
  });

  factory PeekItem.fromJson(Map<String, dynamic> json) => PeekItem(
    kind: PeekKind.values.firstWhere(
      (it) => it.name == json['kind'],
      orElse: () => PeekKind.task,
    ),
    title: json['title'] as String? ?? '',
    start: DateTime.parse(json['start'] as String).toLocal(),
    end: DateTime.parse(json['end'] as String).toLocal(),
    artifact: (json['artifact'] ?? json['project']) as String?,
  );

  final PeekKind kind;

  /// Empty for a free stretch.
  final String title;

  final DateTime start;

  final DateTime end;

  /// The artifact's name, for a task of one.
  final String? artifact;

  @override
  List<Object?> get props => [kind, title, start, end, artifact];
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
    this.artifact,
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
      artifact: (json['artifact'] ?? json['project']) as String?,
      notes: json['notes'] as String?,
    );
  }

  final String id;

  final String title;

  final int minutes;

  /// Its hour. Null in Para depois.
  final DateTime? at;

  /// Whether it is a fixed block.
  final bool fixed;

  final bool done;

  final String? artifact;

  final String? notes;

  @override
  List<Object?> get props => [
    id,
    title,
    minutes,
    at,
    fixed,
    done,
    artifact,
    notes,
  ];
}

/// An artifact at a glance: the Projetos row, and what comes next in it.
final class ArtifactBlock extends AnswerBlock {
  /// {@macro answer_block}
  const ArtifactBlock(this.artifact);

  final PeekArtifact artifact;

  @override
  List<Object?> get props => [artifact];
}

/// {@template peek_artifact}
/// What [ArtifactBlock] draws of an artifact.
/// {@endtemplate}
class PeekArtifact extends Equatable {
  /// {@macro peek_artifact}
  const PeekArtifact({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.done,
    required this.total,
    this.deadline,
    this.next = const [],
  });

  factory PeekArtifact.fromJson(Map<String, dynamic> json) {
    final deadline = json['deadline'] as String?;
    return PeekArtifact(
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
          case 'Preview':
            blocks.add(
              PreviewBlock(
                items: (bound(it['items'])! as List<dynamic>)
                    .map(
                      (it) => PreviewItem.fromJson(it as Map<String, dynamic>),
                    )
                    .nonNulls
                    .toList(),
                applies: it['applies'] as String?,
              ),
            );
          // Conversations kept from before deliveries were projects still
          // name the peek and its data the old way.
          case 'ArtifactPeek' || 'ProjectPeek':
            blocks.add(
              ArtifactBlock(
                PeekArtifact.fromJson(
                  bound(it['artifact'] ?? it['project'])!
                      as Map<String, dynamic>,
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
