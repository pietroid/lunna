import 'package:api_client/api_client.dart';
import 'package:chat/src/data/chat_failure.dart';
import 'package:chat/src/models/models.dart';

/// {@template routines_repository}
/// The routines menu: blocks that repeat, as recurring events on the
/// calendar.
///
/// Every call answers with every routine, because the menu draws the whole
/// day and a routine moved at noon changes what the afternoon looks like.
/// {@endtemplate}
class RoutinesRepository {
  /// {@macro routines_repository}
  const RoutinesRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// Every routine, earliest first.
  Future<List<Routine>> fetchRoutines() =>
      _list(() => apiClient.get<List<dynamic>>('/routines'));

  /// Writes a routine down.
  Future<List<Routine>> addRoutine({
    required String title,
    required String time,
    required int durationMinutes,
    required RoutineDays days,
  }) => _list(
    () => apiClient.post<List<dynamic>>(
      '/routines',
      data: {
        'title': title,
        'time': time,
        'durationMinutes': durationMinutes,
        'days': days.wire,
      },
    ),
  );

  /// Changes a routine, and so every day it happens on.
  Future<List<Routine>> editRoutine(
    String id, {
    String? title,
    String? time,
    int? durationMinutes,
    RoutineDays? days,
  }) => _list(
    () => apiClient.patch<List<dynamic>>(
      '/routines/$id',
      data: {
        'title': ?title,
        'time': ?time,
        'durationMinutes': ?durationMinutes,
        'days': ?days?.wire,
      },
    ),
  );

  /// Takes a routine off every day it was on.
  Future<List<Routine>> deleteRoutine(String id) =>
      _list(() => apiClient.delete<List<dynamic>>('/routines/$id'));

  Future<List<Routine>> _list(
    Future<Response<List<dynamic>>> Function() request,
  ) async {
    try {
      return ((await request()).data ?? <dynamic>[])
          .map((e) => Routine.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }
}
