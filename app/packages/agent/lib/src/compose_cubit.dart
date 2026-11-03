import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

/// What a request to the composer is, once read.
enum ComposeKind {
  /// Something to do: flexible, in the queue or at an hour of its own.
  task,

  /// A block whose hour is the point of it.
  event,

  /// More than one thing to write down: a change to the day, which the
  /// agent proposes as a plan.
  plan,
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
    this.subtasks = const [],
    this.changes = const [],
  });

  final ComposeKind kind;

  /// The task's or the event's name; for a plan, what it does.
  final String title;

  /// The hour, when it has one (always, for an event).
  final DateTime? start;

  /// How long it takes.
  final int? minutes;

  /// The task this one goes under, by name, when it goes under one.
  final String? parent;

  /// Its own tasks, in order: every task may have them.
  final List<String> subtasks;

  /// A plan's changes, one line each, as the plan card says them.
  final List<String> changes;

  @override
  List<Object?> get props => [
    kind,
    title,
    start,
    minutes,
    parent,
    subtasks,
    changes,
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
/// back in about a second, and only a request that changes several things
/// takes the agent's whole turn.
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
    final draft = await _read(text);
    if (isClosed || state.text.trim() != text) return;
    emit(ComposeState(status: ComposeStatus.ready, text: text, draft: draft));
  }
}
