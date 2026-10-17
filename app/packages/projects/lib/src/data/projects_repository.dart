import 'package:api_client/api_client.dart';
import 'package:projects/src/models/models.dart';

/// {@template projects_failure}
/// A request the server refused, with the sentence it refused in, when it
/// gave one. The server writes those in Portuguese, for the user.
/// {@endtemplate}
class ProjectsFailure implements Exception {
  /// {@macro projects_failure}
  const ProjectsFailure([this.message]);

  /// Builds a failure from whatever the client threw.
  factory ProjectsFailure.from(Object error) {
    if (error is ProjectsFailure) return error;
    if (error is! DioException) return const ProjectsFailure();

    final data = error.response?.data;
    final message = data is Map<String, dynamic> ? data['message'] : null;
    return ProjectsFailure(
      message is String && message.isNotEmpty ? message : null,
    );
  }

  /// What the server said, when it said anything.
  final String? message;
}

/// {@template projects_repository}
/// Where projects are read from and written to.
///
/// Every write answers with every project, as the server now has them, so
/// the screen never works out what a change did.
/// {@endtemplate}
class ProjectsRepository {
  /// {@macro projects_repository}
  const ProjectsRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// Every project.
  Future<List<Project>> list() =>
      _projects(() => apiClient.get<Map<String, dynamic>>('/projects'));

  /// Writes a new project down.
  Future<List<Project>> create({required String title, DateTime? deadline}) =>
      _projects(
        () => apiClient.post<Map<String, dynamic>>(
          '/projects',
          data: {'title': title, 'deadline': ?_day(deadline)},
        ),
      );

  /// Changes a project's name, deadline, notes or doneness. A [deadline]
  /// function that answers null takes the deadline away.
  Future<List<Project>> update(
    String id, {
    String? title,
    DateTime? Function()? deadline,
    String? notes,
    bool? done,
  }) => _projects(
    () => apiClient.patch<Map<String, dynamic>>(
      '/projects/$id',
      data: {
        'title': ?title,
        'notes': ?notes,
        'done': ?done,
        if (deadline != null) 'deadline': _day(deadline()),
      },
    ),
  );

  /// Removes a project, and what waited in the backlog for it. Its tasks
  /// on the day, and the ones done, stay.
  Future<List<Project>> delete(String id) =>
      _projects(() => apiClient.delete<Map<String, dynamic>>('/projects/$id'));

  /// `YYYY-MM-DD`, the day [day] is on this device.
  static String? _day(DateTime? day) {
    if (day == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${day.year}-${two(day.month)}-${two(day.day)}';
  }

  Future<List<Project>> _projects(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      return [
        for (final project
            in response.data?['projects'] as List<dynamic>? ?? const [])
          Project.fromJson(project as Map<String, dynamic>),
      ];
    } on Object catch (error) {
      throw ProjectsFailure.from(error);
    }
  }
}
