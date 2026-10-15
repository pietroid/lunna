import 'package:agent/src/agent_repository.dart';
import 'package:agent/src/models.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

/// {@template agent_state}
/// The conversation, and whether the agent is answering.
/// {@endtemplate}
class AgentState extends Equatable {
  /// {@macro agent_state}
  const AgentState({
    this.entries = const [],
    this.busy = false,
    this.failure,
  });

  final List<AgentEntry> entries;

  /// Whether a turn is in flight.
  final bool busy;

  /// What went wrong with the last turn, when something did.
  final AgentFailure? failure;

  AgentState copyWith({
    List<AgentEntry>? entries,
    bool? busy,
    AgentFailure? failure,
    bool clearFailure = false,
  }) => AgentState(
    entries: entries ?? this.entries,
    busy: busy ?? this.busy,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => [entries, busy, failure];
}

/// {@template agent_cubit}
/// One conversation with the agent.
///
/// It lives as long as the shell does, so closing the sheet and opening it
/// again carries on where it was. Nothing here writes to the day: a plan is
/// applied by `applyAgentPlan`, which tells this cubit through [markPlan].
/// {@endtemplate}
class AgentCubit extends Cubit<AgentState> {
  /// {@macro agent_cubit}
  AgentCubit({required this._repository}) : super(const AgentState());

  final AgentRepository _repository;

  /// Says [text], about the [day] on screen; [voice] is how long it took to
  /// say, when it was spoken.
  Future<void> send(String text, {DateTime? day, Duration? voice}) async {
    final said = text.trim();
    if (said.isEmpty || state.busy) return;

    final entries = [...state.entries, UserEntry(said, voice: voice)];
    emit(state.copyWith(entries: entries, busy: true, clearFailure: true));

    try {
      final reply = await _repository.turn(entries, day: day);
      emit(
        state.copyWith(entries: [...entries, ReplyEntry(reply)], busy: false),
      );
    } on AgentFailure catch (failure) {
      emit(state.copyWith(busy: false, failure: failure));
    }
  }

  /// Where the plan [planId] stands now.
  void markPlan(String planId, PlanStatus status) {
    emit(
      state.copyWith(
        entries: [
          for (final entry in state.entries)
            if (entry is ReplyEntry && entry.reply.plan?.id == planId)
              entry.withStatus(status)
            else
              entry,
        ],
      ),
    );
  }

  /// Starts over.
  void reset() => emit(const AgentState());
}
