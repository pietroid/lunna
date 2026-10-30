import 'package:agent/src/agent_repository.dart';
import 'package:agent/src/models.dart';
import 'package:bloc/bloc.dart';

/// {@template suggestion_cubit}
/// The one thing the agent offers on the Feed without being asked.
///
/// The server keeps it and decides when the next one comes (`nextAt`), so
/// loading asks every time and costs no model: a held suggestion is read
/// back as it was written. The ✕ tells the server, which puts it away
/// until the next one (the welcome, for a day) on every device.
/// {@endtemplate}
class SuggestionCubit extends Cubit<AgentSuggestion?> {
  /// {@macro suggestion_cubit}
  SuggestionCubit({required this._repository}) : super(null);

  final AgentRepository _repository;

  /// Asks for the suggestion the server holds.
  Future<void> load() async {
    try {
      emit(await _repository.suggestion());
    } on AgentFailure {
      // An offer nobody asked for is not worth an error.
      emit(null);
    }
  }

  /// The ✕.
  Future<void> dismiss() async {
    final held = state;
    emit(null);
    if (held == null) return;
    try {
      await _repository.dismissSuggestion(held.id);
    } on AgentFailure {
      // Not put away, then: it comes back on the next load.
    }
  }

  /// Answered (taken, or talked about): it goes until the next one.
  void clear() => emit(null);
}
