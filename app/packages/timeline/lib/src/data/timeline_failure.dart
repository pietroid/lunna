import 'package:api_client/api_client.dart';

/// {@template timeline_failure}
/// A request the server refused, with the sentence it refused in.
///
/// The server writes its refusals in Portuguese and means them for the user,
/// so [message] is shown as written. When there is no such sentence — a
/// socket that never opened, a body that made no sense — [message] is null
/// and the screen says, in its own localized words, that the server could
/// not be reached.
/// {@endtemplate}
class TimelineFailure implements Exception {
  /// {@macro timeline_failure}
  const TimelineFailure([this.message]);

  /// Builds a failure from whatever the client threw.
  factory TimelineFailure.from(Object error) {
    if (error is TimelineFailure) return error;
    if (error is! DioException) return const TimelineFailure();

    final data = error.response?.data;
    final message = data is Map<String, dynamic> ? data['message'] : null;

    return TimelineFailure(
      message is String && message.isNotEmpty ? message : null,
    );
  }

  /// What the server said, already in the user's language, when it said
  /// anything.
  final String? message;

  @override
  String toString() => message ?? 'TimelineFailure';
}
