import 'package:api_client/api_client.dart';
import 'package:chat/src/data/chat_failure.dart';
import 'package:chat/src/models/models.dart';

/// {@template chat_repository}
/// Conversations, on the backend.
///
/// Nothing here has an hour. When something happens belongs to the timeline
/// repository, and a thread learns about a block of time only because the
/// block says which thread it belongs to.
/// {@endtemplate}
class ChatRepository {
  /// {@macro chat_repository}
  const ChatRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// Every open thread, most recently replied to first.
  ///
  /// What Coisas draws, and all of what it draws: every conversation the user
  /// has open, whether or not an hour was ever set aside for any of them.
  Future<List<ThreadItem>> fetchItems() async {
    final response = await apiClient.get<List<dynamic>>('/threads');

    return (response.data ?? <dynamic>[])
        .map((t) => ThreadItem.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Everything the user has closed, most recently touched first.
  Future<List<ThreadItem>> fetchSolved() async {
    final response = await apiClient.get<List<dynamic>>('/threads/solved');

    return (response.data ?? <dynamic>[])
        .map((t) => ThreadItem.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Marks a thread solved, or opens a closed one again.
  ///
  /// Returns the open list, because closing a conversation changes which
  /// conversations Coisas has in it and not only the one that was touched. It
  /// says nothing about the calendar: an hour is given back by finishing the
  /// block, which is a different act on a different screen.
  Future<List<ThreadItem>> setSolved(
    String slug, {
    required bool solved,
  }) async {
    try {
      final response = await apiClient.post<List<dynamic>>(
        '/threads/$slug/solved',
        data: {'solved': solved},
      );

      return (response.data ?? <dynamic>[])
          .map((t) => ThreadItem.fromJson(t as Map<String, dynamic>))
          .toList();
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// One thread, with every message it holds.
  Future<Thread> fetchThread(String slug) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/threads/$slug',
    );

    return Thread.fromJson(response.data ?? <String, dynamic>{});
  }

  /// Starts a thread from [message] and returns it with the agent's answer.
  Future<Thread> createThread(String message) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/threads',
      data: {'message': message},
    );

    return Thread.fromJson(response.data ?? <String, dynamic>{});
  }

  /// Appends [message] to a thread and returns it with the agent's answer.
  Future<Thread> sendMessage(String slug, String message) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/threads/$slug/messages',
      data: {'message': message},
    );

    return Thread.fromJson(response.data ?? <String, dynamic>{});
  }

  /// Runs an action a rendered component fired.
  ///
  /// The action object is posted exactly as it arrived. The app deliberately
  /// does not read it first: what an action means, which ones need a pending
  /// call, and which ones touch the thread itself are all the server's to know,
  /// and duplicating that judgement here is how the two drift apart.
  Future<Thread> runAction({
    required String slug,
    required Map<String, dynamic> action,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/threads/$slug/actions',
      data: {'action': action},
    );

    final body = response.data ?? <String, dynamic>{};
    final thread = body['thread'] as Map<String, dynamic>?;

    if (thread == null) {
      throw StateError('The action removed the thread');
    }

    return Thread.fromJson(thread);
  }
}
