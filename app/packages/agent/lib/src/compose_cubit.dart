import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

/// What a request to the composer is, once read.
enum ComposeKind {
  /// Something to do: flexible, in the queue or at an hour of its own.
  task,

  /// A block whose hour is the point of it.
  event,

  /// An amount of money to bill by a day.
  goal,

  /// More than one thing to write down: a change to the day, which the
  /// agent proposes as a plan.
  plan;

  static ComposeKind _of(Object? wire) => switch (wire) {
    'task' => task,
    'event' => event,
    'goal' => goal,
    _ => plan,
  };
}

/// One of a task's own tasks, as the composer read it.
class ComposeSubtask extends Equatable {
  /// A subtask called [title], [minutes] long when that was said.
  const ComposeSubtask(this.title, {this.minutes});

  final String title;
  final int? minutes;

  @override
  List<Object?> get props => [title, minutes];
}

/// {@template compose_draft}
/// What the composer understood, drawn in the small box over it before
/// anything is written down.
/// {@endtemplate}
class ComposeDraft extends Equatable {
  /// {@macro compose_draft}
  const ComposeDraft({
    required this.kind,
    required this.title,
    this.start,
    this.minutes,
    this.parent,
    this.parentId,
    this.subtasks = const [],
    this.changes = const [],
    this.value,
    this.due,
    this.conversationId,
    this.planId,
  });

  /// The server's draft (`POST /agent/compose`).
  factory ComposeDraft.fromJson(Map<String, dynamic> json) {
    final parent = json['parent'] as Map<String, dynamic>?;
    final start = json['start'] as String?;
    final due = json['due'] as String?;
    return ComposeDraft(
      kind: ComposeKind._of(json['kind']),
      title: json['title'] as String? ?? '',
      start: start == null ? null : DateTime.parse(start).toLocal(),
      minutes: json['minutes'] as int?,
      parent: parent?['title'] as String?,
      parentId: parent?['id'] as String?,
      subtasks: [
        for (final it in json['subtasks'] as List<dynamic>? ?? const [])
          if (it is Map<String, dynamic>)
            ComposeSubtask(
              it['title'] as String? ?? '',
              minutes: it['minutes'] as int?,
            ),
      ],
      changes: [
        for (final it in json['changes'] as List<dynamic>? ?? const [])
          if (it is String) it,
      ],
      value: json['value'] as int?,
      due: due == null ? null : DateTime.parse(due),
      conversationId: json['conversationId'] as String?,
      planId: json['planId'] as String?,
    );
  }

  final ComposeKind kind;

  /// The task's or the event's name; for a plan, what it does.
  final String title;

  /// The hour, when it has one (always, for an event).
  final DateTime? start;

  /// How long it takes.
  final int? minutes;

  /// The task this one goes under, by name, when it goes under one.
  final String? parent;

  /// That task's id (a delivery's).
  final String? parentId;

  /// Its own tasks, in order: every task may have them.
  final List<ComposeSubtask> subtasks;

  /// A plan's changes, one line each, as the plan card says them.
  final List<String> changes;

  /// A goal's amount, in whole reais.
  final int? value;

  /// A goal's last day.
  final DateTime? due;

  /// A plan's conversation, which the agent's turn was written into.
  final String? conversationId;

  /// A plan's id, for Aplicar; null when the agent proposed nothing.
  final String? planId;

  @override
  List<Object?> get props => [
    kind,
    title,
    start,
    minutes,
    parent,
    parentId,
    subtasks,
    changes,
    value,
    due,
    conversationId,
    planId,
  ];
}

/// Where the composer stands.
enum ComposeStatus {
  /// Typing, or nothing yet.
  editing,

  /// Sent: the request is being read.
  reading,

  /// Read: the summary is over the sheet, waiting for Adicionar.
  ready,

  /// The read failed: the field keeps the words, to send again.
  failed,
}

/// {@template compose_state}
/// The composer's field and what was understood of it.
/// {@endtemplate}
class ComposeState extends Equatable {
  /// {@macro compose_state}
  const ComposeState({
    this.status = ComposeStatus.editing,
    this.text = '',
    this.draft,
  });

  final ComposeStatus status;

  /// What was typed or said.
  final String text;

  /// What it was read as, once [ComposeStatus.ready].
  final ComposeDraft? draft;

  @override
  List<Object?> get props => [status, text, draft];
}

/// {@template compose_cubit}
/// The composer: one field, typed or spoken, read into a [ComposeDraft].
///
/// `read` asks the server what the text is; a single task or event comes
/// back from one short read on the agent's model, and only a request that
/// changes several things takes the agent's whole turn.
/// {@endtemplate}
class ComposeCubit extends Cubit<ComposeState> {
  /// {@macro compose_cubit}
  ComposeCubit({
    required this._read,
    ComposeState initial = const ComposeState(),
  }) : super(initial);

  final Future<ComposeDraft> Function(String text) _read;

  /// The field changed: whatever was read of it no longer holds.
  void edit(String text) => emit(ComposeState(text: text));

  /// Reads what is in the field.
  Future<void> send() async {
    final text = state.text.trim();
    if (text.isEmpty) return;
    emit(ComposeState(status: ComposeStatus.reading, text: text));
    ComposeDraft draft;
    try {
      draft = await _read(text);
    } on Object {
      if (isClosed || state.text.trim() != text) return;
      emit(ComposeState(status: ComposeStatus.failed, text: text));
      return;
    }
    if (isClosed || state.text.trim() != text) return;
    emit(ComposeState(status: ComposeStatus.ready, text: text, draft: draft));
  }
}
