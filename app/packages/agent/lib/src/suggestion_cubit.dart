import 'package:agent/src/agent_repository.dart';
import 'package:agent/src/models.dart';
import 'package:bloc/bloc.dart';
import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// {@template suggestion_cubit}
/// The one thing the agent offers on Tempo without being asked.
///
/// The ✕ puts suggestions away for a day, on this device: an offer turned
/// down and made again an hour later is nagging. One held is kept until its
/// `validUntil`, so loading again asks nothing.
/// {@endtemplate}
class SuggestionCubit extends Cubit<AgentSuggestion?> {
  /// {@macro suggestion_cubit}
  SuggestionCubit({required this._repository}) : super(null);

  final AgentRepository _repository;

  static const _dismissedKey = 'agent.suggestion.dismissedAt';
  static const quiet = Duration(hours: 24);

  /// Asks for a suggestion, unless they were put away or the one held is
  /// still good.
  Future<void> load() async {
    if (state case final held? when held.validUntil.isAfter(clock.now())) {
      return;
    }
    if (await _resting()) {
      emit(null);
      return;
    }

    try {
      emit(await _repository.suggestion());
    } on AgentFailure {
      // An offer nobody asked for is not worth an error.
      emit(null);
    }
  }

  /// The ✕.
  Future<void> dismiss() async {
    emit(null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _dismissedKey,
        clock.now().millisecondsSinceEpoch,
      );
    } on Object {
      // Not remembered, then: it comes back on the next load.
    }
  }

  /// Taken: the suggestion is a plan now, and goes away.
  void clear() => emit(null);

  Future<bool> _resting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(_dismissedKey);
      if (at == null) return false;

      return clock.now().difference(
            DateTime.fromMillisecondsSinceEpoch(at),
          ) <
          quiet;
    } on Object {
      return false;
    }
  }
}
