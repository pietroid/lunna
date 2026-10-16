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

  /// Answers the last of [history], in the conversation [conversationId]
  /// (a new one when null). Changes nothing on the day.
  ///
  /// [day] is the day Tempo is showing, so "aqui" means something. Answers
  /// with the conversation the turn was written into.
  Future<({String conversationId, AgentReply reply})> turn(
    List<AgentEntry> history, {
    String? conversationId,
    DateTime? day,
  }) => _guard(() async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/agent/turn',
      data: {
        'conversationId': ?conversationId,
        'messages': [
          for (final entry in history)
            switch (entry) {
              UserEntry(:final text, :final voice) => {
                'role': 'user',
                'text': text,
                if (voice != null) 'voice': voice.inMilliseconds / 1000,
              },
              ReplyEntry(:final reply) => {
                'role': 'assistant',
                'text': reply.text,
              },
            },
        ],
        if (day != null) 'day': _isoDay(day),
      },
    );

    final data = response.data ?? {};

    return (
      conversationId: data['conversationId'] as String? ?? '',
      reply: AgentReply.fromJson(data),
    );
  });

  /// Up to [limit] conversations that started before [before], the most
  /// recent first.
  Future<List<PastConversation>> conversations({
    DateTime? before,
    int limit = 10,
  }) => _guard(() async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/agent/conversations',
      queryParameters: {
        'limit': '$limit',
        if (before != null) 'before': before.toUtc().toIso8601String(),
      },
    );

    return (response.data?['conversations'] as List<dynamic>? ?? [])
        .map((it) => PastConversation.fromJson(it as Map<String, dynamic>))
        .toList();
  });

  /// The plan worth offering on Tempo right now, if there is one.
  Future<AgentSuggestion?> suggestion() => _guard(() async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/agent/suggestion',
    );
    final suggestion = response.data?['suggestion'] as Map<String, dynamic>?;

    return suggestion == null ? null : AgentSuggestion.fromJson(suggestion);
  });

  /// Makes every change of [planId]. Answers with the day it leaves.
  Future<Timeline> apply(
    String planId, {
    int days = TimelineRepository.defaultDays,
  }) => _guard(() async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/agent/plans/$planId/apply?days=$days',
    );

    return Timeline.fromJson(response.data ?? {});
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
