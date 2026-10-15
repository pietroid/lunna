import 'package:agent/src/models.dart';
import 'package:api_client/api_client.dart';
import 'package:timeline/timeline.dart';

/// {@template agent_failure}
/// Something the agent could not do, in the server's own words when it has
/// any: the server writes its refusals in Portuguese and the app shows them
/// as written.
/// {@endtemplate}
class AgentFailure implements Exception {
  /// {@macro agent_failure}
  const AgentFailure([this.message]);

  factory AgentFailure.from(Object error) {
    if (error is AgentFailure) return error;
    if (error is! DioException) return const AgentFailure();

    final data = error.response?.data;
    final message = data is Map<String, dynamic> ? data['message'] : null;

    return AgentFailure(
      message is String && message.isNotEmpty ? message : null,
    );
  }

  final String? message;

  @override
  String toString() => message ?? 'AgentFailure';
}

/// {@template agent_repository}
/// The agent's routes under `/api/agent`.
/// {@endtemplate}
class AgentRepository {
  /// {@macro agent_repository}
  const AgentRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Answers the last of [history]. Changes nothing on the day.
  ///
  /// [day] is the day Tempo is showing, so "aqui" means something.
  Future<AgentReply> turn(
    List<AgentEntry> history, {
    DateTime? day,
  }) => _guard(() async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/agent/turn',
      data: {
        'messages': [
          for (final entry in history)
            switch (entry) {
              UserEntry(:final text) => {'role': 'user', 'text': text},
              ReplyEntry(:final reply) => {
                'role': 'assistant',
                'text': reply.text,
              },
            },
        ],
        if (day != null) 'day': _isoDay(day),
      },
    );

    return AgentReply.fromJson(response.data ?? {});
  });

  /// The plan worth offering on Tempo right now, if there is one.
  Future<AgentSuggestion?> suggestion() => _guard(() async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/agent/suggestion',
    );
    final suggestion = response.data?['suggestion'] as Map<String, dynamic>?;

    return suggestion == null ? null : AgentSuggestion.fromJson(suggestion);
  });

  /// Makes every change of [planId]. Answers with the day, and the cards it
  /// changed.
  Future<({Timeline timeline, Set<String> touched})> apply(
    String planId, {
    int days = TimelineRepository.defaultDays,
  }) => _guard(() async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/agent/plans/$planId/apply?days=$days',
    );
    final data = response.data ?? {};

    return (
      timeline: Timeline.fromJson(data),
      touched: (data['touched'] as List<dynamic>? ?? []).cast<String>().toSet(),
    );
  });

  /// Takes an applied plan back.
  Future<Timeline> undo(
    String planId, {
    int days = TimelineRepository.defaultDays,
  }) => _guard(() async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/agent/plans/$planId/undo?days=$days',
    );

    return Timeline.fromJson(response.data ?? {});
  });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on Object catch (error) {
      throw AgentFailure.from(error);
    }
  }

  static String _isoDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
