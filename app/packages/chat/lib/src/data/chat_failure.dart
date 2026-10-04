import 'package:api_client/api_client.dart';

/// {@template chat_failure}
/// A request the server refused, with the sentence it refused in.
///
/// The server writes these in Portuguese and means them for the user: "A
/// agenda não respondeu" is the whole explanation, and inventing a second
/// wording here would mean two places deciding what went wrong.
/// {@endtemplate}
class ChatFailure implements Exception {
  /// {@macro chat_failure}
  const ChatFailure(this.message);

  /// Builds a failure from whatever the client threw.
  ///
  /// A refusal the server wrote is used as written. Anything else — a socket
  /// that never opened, a body that made no sense — gets the one sentence
  /// that is true of all of them, because at that point the app genuinely
  /// does not know any more than that.
  factory ChatFailure.from(Object error) {
    if (error is ChatFailure) return error;
    if (error is! DioException) return const ChatFailure(_generic);

    final data = error.response?.data;
    final message = data is Map<String, dynamic> ? data['message'] : null;

    return ChatFailure(
      message is String && message.isNotEmpty ? message : _generic,
    );
  }

  static const _generic = 'Não consegui falar com o servidor.';

  /// What to tell the user, already in their language.
  final String message;

  @override
  String toString() => message;
}
