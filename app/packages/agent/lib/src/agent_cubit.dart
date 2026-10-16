import 'dart:async';

import 'package:agent/src/agent_repository.dart';
import 'package:agent/src/models.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

/// Where the conversations before this one stand.
enum PastStatus {
  /// Not asked for yet, or more may be had.
  idle,

  loading,

  /// Every one there is has been read.
  done,

  failed,
}

/// {@template agent_state}
/// The conversation, whether the agent is answering, and the conversations
/// before it.
/// {@endtemplate}
class AgentState extends Equatable {
  /// {@macro agent_state}
  const AgentState({
    this.conversationId,
    this.startedAt,
    this.entries = const [],
    this.busy = false,
    this.failure,
    this.past = const [],
    this.pastStatus = PastStatus.idle,
  });

  /// The conversation being had, once the server has written it down.
  final String? conversationId;

  /// When it began: its first message.
  final DateTime? startedAt;

  final List<AgentEntry> entries;

  /// Whether a turn is in flight.
  final bool busy;

  /// What went wrong with the last turn, when something did.
  final AgentFailure? failure;

  /// The conversations before this one, the most recent first. Only for the
  /// user to read: none of it is sent with a turn.
  final List<PastConversation> past;

  final PastStatus pastStatus;

  AgentState copyWith({
    String? conversationId,
    DateTime? startedAt,
    List<AgentEntry>? entries,
    bool? busy,
    AgentFailure? failure,
    bool clearFailure = false,
    List<PastConversation>? past,
    PastStatus? pastStatus,
  }) => AgentState(
    conversationId: conversationId ?? this.conversationId,
    startedAt: startedAt ?? this.startedAt,
    entries: entries ?? this.entries,
    busy: busy ?? this.busy,
    failure: clearFailure ? null : failure ?? this.failure,
    past: past ?? this.past,
    pastStatus: pastStatus ?? this.pastStatus,
  );

  @override
  List<Object?> get props => [
    conversationId,
    startedAt,
    entries,
    busy,
    failure,
    past,
    pastStatus,
  ];
}

/// {@template agent_cubit}
/// The conversations with the agent.
///
/// Each time the sheet opens is a new conversation ([open]); the one before
/// goes to the top of [AgentState.past], which the sheet draws above it for
/// the user to read back. A turn sends only the conversation being had.
/// Nothing here writes to the day: a plan is applied by `applyAgentPlan`,
/// which tells this cubit through [markPlan].
/// {@endtemplate}
class AgentCubit extends Cubit<AgentState> {
  /// {@macro agent_cubit}
  AgentCubit({required this._repository, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const AgentState());

  final AgentRepository _repository;

  final DateTime Function() _now;

  /// Whether the past has been asked for yet.
  bool _asked = false;

  /// How many past conversations one page brings: the repository's.
  static const pageSize = 10;

  /// Starts a new conversation, putting the one being had with the past.
  ///
  /// A conversation still being answered is left as it is: the answer is on
  /// its way to it.
  void open() {
    if (!state.busy && state.entries.isNotEmpty) {
      emit(
        AgentState(
          past: [
            PastConversation(
              id: state.conversationId ?? '',
              startedAt: state.startedAt ?? _now(),
              entries: state.entries,
            ),
            ...state.past,
          ],
          pastStatus: state.pastStatus,
        ),
      );
    }
    // The first page is read once; scrolling to the top of it reads more.
    if (!_asked) {
      _asked = true;
      unawaited(loadPast());
    }
  }

  /// Reads the page of conversations before the oldest one held.
  Future<void> loadPast() async {
    if (state.pastStatus == PastStatus.loading ||
        state.pastStatus == PastStatus.done) {
      return;
    }

    emit(state.copyWith(pastStatus: PastStatus.loading));
    try {
      final page = await _repository.conversations(
        before: state.past.isEmpty ? null : state.past.last.startedAt,
      );
      final held = {...state.past.map((it) => it.id), state.conversationId};
      emit(
        state.copyWith(
          past: [
            ...state.past,
            ...page.where((it) => !held.contains(it.id)),
          ],
          pastStatus: page.length < pageSize
              ? PastStatus.done
              : PastStatus.idle,
        ),
      );
    } on AgentFailure {
      emit(state.copyWith(pastStatus: PastStatus.failed));
    }
  }

  /// Says [text], about the [day] on screen; [voice] is how long it took to
  /// say, when it was spoken.
  Future<void> send(String text, {DateTime? day, Duration? voice}) async {
    final said = text.trim();
    if (said.isEmpty || state.busy) return;

    final entries = [...state.entries, UserEntry(said, voice: voice)];
    emit(
      state.copyWith(
        entries: entries,
        startedAt: state.startedAt ?? _now(),
        busy: true,
        clearFailure: true,
      ),
    );

    try {
      final turn = await _repository.turn(
        entries,
        conversationId: state.conversationId,
        day: day,
      );
      emit(
        state.copyWith(
          conversationId: turn.conversationId,
          entries: [...entries, ReplyEntry(turn.reply)],
          busy: false,
        ),
      );
    } on AgentFailure catch (failure) {
      emit(state.copyWith(busy: false, failure: failure));
    }
  }

  /// Where the plan [planId] stands now, wherever it was proposed.
  void markPlan(String planId, PlanStatus status) {
    List<AgentEntry> marked(List<AgentEntry> entries) => [
      for (final entry in entries)
        if (entry is ReplyEntry && entry.reply.plan?.id == planId)
          entry.withStatus(status)
        else
          entry,
    ];

    emit(
      state.copyWith(
        entries: marked(state.entries),
        past: [
          for (final conversation in state.past)
            PastConversation(
              id: conversation.id,
              startedAt: conversation.startedAt,
              entries: marked(conversation.entries),
            ),
        ],
      ),
    );
  }
}
