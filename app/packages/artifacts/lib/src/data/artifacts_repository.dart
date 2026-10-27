import 'package:api_client/api_client.dart';
import 'package:artifacts/src/models/models.dart';

/// {@template artifacts_failure}
/// A request the server refused, with the sentence it refused in, when it
/// gave one. The server writes those in Portuguese, for the user.
/// {@endtemplate}
class ArtifactsFailure implements Exception {
  /// {@macro artifacts_failure}
  const ArtifactsFailure([this.message]);

  /// Builds a failure from whatever the client threw.
  factory ArtifactsFailure.from(Object error) {
    if (error is ArtifactsFailure) return error;
    if (error is! DioException) return const ArtifactsFailure();

    final data = error.response?.data;
    final message = data is Map<String, dynamic> ? data['message'] : null;
    return ArtifactsFailure(
      message is String && message.isNotEmpty ? message : null,
    );
  }

  /// What the server said, when it said anything.
  final String? message;
}

/// {@template artifacts_repository}
/// Where the deliveries, the catalogue and the goals are read from and
/// written to.
///
/// Every write answers with all of it, as the server now has it, so the
/// screen never works out what a change did.
/// {@endtemplate}
class ArtifactsRepository {
  /// {@macro artifacts_repository}
  const ArtifactsRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// Everything Entregas draws.
  Future<ArtifactsData> load() =>
      _data(() => apiClient.get<Map<String, dynamic>>('/artifacts'));

  /// Puts a delivery in the queue, at its top or its end, or, [started],
  /// begins it at once (it needs a [deadline]).
  Future<ArtifactsData> create({
    required String title,
    String? typeId,
    int? minutes,
    int? value,
    int? blockMinutes,
    DateTime? deadline,
    bool top = false,
    bool started = false,
  }) => _data(
    () => apiClient.post<Map<String, dynamic>>(
      '/artifacts',
      data: {
        'title': title,
        'typeId': ?typeId,
        'minutes': ?minutes,
        'value': ?value,
        // Null says "whole", even for a kind that has blocks.
        if (typeId != null || blockMinutes != null)
          'blockMinutes': blockMinutes,
        'deadline': ?_day(deadline),
        'at': top ? 'top' : 'end',
        if (started) 'started': true,
      },
    ),
  );

  /// Changes a delivery's name, deadline, notes or doneness, or begins it
  /// ([started], which needs a deadline). A [deadline] function that
  /// answers null takes the deadline away.
  Future<ArtifactsData> update(
    String id, {
    String? title,
    DateTime? Function()? deadline,
    String? notes,
    bool? done,
    bool? started,
  }) => _data(
    () => apiClient.patch<Map<String, dynamic>>(
      '/artifacts/$id',
      data: {
        'title': ?title,
        'notes': ?notes,
        'done': ?done,
        'started': ?started,
        if (deadline != null) 'deadline': _day(deadline()),
      },
    ),
  );

  /// Moves a delivery to [index] in the queue; with [stop], dropped among
  /// those not begun, it is no longer begun.
  Future<ArtifactsData> move(String id, int index, {bool stop = false}) =>
      _data(
        () => apiClient.post<Map<String, dynamic>>(
          '/artifacts/$id/move',
          data: {'index': index, if (stop) 'started': false},
        ),
      );

  /// Removes a delivery, and what waited in the backlog for it. Its tasks
  /// on the day, and the ones done, stay.
  Future<ArtifactsData> delete(String id) =>
      _data(() => apiClient.delete<Map<String, dynamic>>('/artifacts/$id'));

  /// Writes a kind down in the catalogue, on the shelf [categoryId] or on
  /// the one named [category] (made when she has none of that name).
  Future<ArtifactsData> addType({
    required String name,
    required int minutes,
    int? price,
    int? blockMinutes,
    String? categoryId,
    String? category,
  }) => _data(
    () => apiClient.post<Map<String, dynamic>>(
      '/catalog/types',
      data: {
        'name': name,
        'minutes': minutes,
        'price': ?price,
        'blockMinutes': ?blockMinutes,
        'categoryId': ?categoryId,
        'category': ?category,
      },
    ),
  );

  /// Writes a goal down, from this stretch or from the next.
  Future<ArtifactsData> addGoal({
    required GoalKind kind,
    required int target,
    required GoalPeriod period,
    String? typeId,
    bool next = false,
  }) => _data(
    () => apiClient.post<Map<String, dynamic>>(
      '/goals',
      data: {
        'kind': kind.name,
        'target': target,
        'period': period.name,
        'typeId': ?typeId,
        'start': next ? 'next' : 'now',
      },
    ),
  );

  /// Removes a goal.
  Future<ArtifactsData> deleteGoal(String id) =>
      _data(() => apiClient.delete<Map<String, dynamic>>('/goals/$id'));

  /// `YYYY-MM-DD`, the day [day] is on this device.
  static String? _day(DateTime? day) {
    if (day == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${day.year}-${two(day.month)}-${two(day.day)}';
  }

  Future<ArtifactsData> _data(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      return ArtifactsData.fromJson(response.data ?? const {});
    } on Object catch (error) {
      throw ArtifactsFailure.from(error);
    }
  }
}
