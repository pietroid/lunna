import 'package:api_client/api_client.dart';
import 'package:timeline/src/data/timeline_failure.dart';
import 'package:timeline/src/models/models.dart';

/// {@template timeline_repository}
/// The day: the tasks, the events, and everything that changes them.
///
/// Every call answers with the whole [Timeline], the list and the calendar
/// both, the calendar drawn as many days ahead as each call's `days` says.
/// A task moved in the queue moves every task after it on the calendar, so
/// nothing short of the whole day is a true answer.
/// {@endtemplate}
class TimelineRepository {
  /// {@macro timeline_repository}
  const TimelineRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// The day, drawn [days] days ahead counting today.
  Future<Timeline> fetch({int days = defaultDays}) =>
      _day(() => apiClient.get<Map<String, dynamic>>('/timeline?days=$days'));

  /// Writes a task down at the end of the backlog, where it waits without
  /// an hour until it is dragged into the queue.
  Future<Timeline> createTask({
    required String title,
    required int minutes,
    int days = defaultDays,
  }) => _day(
    () => apiClient.post<Map<String, dynamic>>(
      '/tasks?days=$days',
      data: {'title': title, 'minutes': minutes},
    ),
  );

  /// Writes a fixed block down at [startTime].
  Future<Timeline> createEvent({
    required String title,
    required int durationMinutes,
    required DateTime startTime,
    int days = defaultDays,
  }) => _day(
    () => apiClient.post<Map<String, dynamic>>(
      '/events?days=$days',
      data: {
        'title': title,
        'durationMinutes': durationMinutes,
        'startTime': startTime.toUtc().toIso8601String(),
      },
    ),
  );

  /// Moves a task to [index] in the list of tasks.
  ///
  /// One number, because the queue is one list; what is running counts, at
  /// the top. Everything a drop does to the hours of everything after it is
  /// worked out on the server.
  ///
  /// [start] says it was dropped at the very top of the day, which is doing
  /// it now. While something else is running that comes back with a guard
  /// instead, and nothing has changed on the server until it is answered.
  ///
  /// A drop into a free stretch also says where that stretch starts, as
  /// [after], so the task is not laid out any earlier than the gap it was
  /// dropped into, and [minutes] when the user agreed to cut it to fit.
  ///
  /// [backlog] says it was dropped into the backlog instead, and then
  /// [index] counts the backlog. Nothing there has an hour, so a drop there
  /// never starts anything and never asks.
  Future<Timeline> moveTask(
    String id,
    int index, {
    bool backlog = false,
    bool start = false,
    DateTime? after,
    int? minutes,
    int days = defaultDays,
  }) => _day(
    () => apiClient.post<Map<String, dynamic>>(
      '/tasks/$id/move?days=$days',
      data: {
        'index': index,
        if (backlog) 'backlog': true,
        if (start) 'start': true,
        if (after != null) 'after': after.toUtc().toIso8601String(),
        'minutes': ?minutes,
      },
    ),
  );

  /// Says the user began a task.
  ///
  /// One further down the day goes to the top instead, which can raise the
  /// guard.
  Future<Timeline> startTask(String id, {int days = defaultDays}) => _day(
    () => apiClient.post<Map<String, dynamic>>(
      '/tasks/$id/start?days=$days',
    ),
  );

  /// Not yet: the task waits [minutes] more before asking again.
  Future<Timeline> snoozeTask(
    String id, {
    int minutes = 15,
    int days = defaultDays,
  }) => _day(
    () => apiClient.post<Map<String, dynamic>>(
      '/tasks/$id/snooze?days=$days',
      data: {'minutes': minutes},
    ),
  );

  /// Answers a guard.
  ///
  /// What the answer does to the rest of the day is the server's to work
  /// out; the app only says which one was picked.
  Future<Timeline> applyTiming(
    Map<String, dynamic> action, {
    int days = defaultDays,
  }) => _day(
    () => apiClient.post<Map<String, dynamic>>(
      '/tasks/timing?days=$days',
      data: {'action': action},
    ),
  );

  /// Marks a card done.
  ///
  /// A running one keeps the hour it really took and the next thing starts
  /// five minutes later.
  Future<Timeline> finish(
    CardKind kind,
    String id, {
    int days = defaultDays,
  }) => _day(
    () => apiClient.post<Map<String, dynamic>>(
      '/${kind.path}/$id/done?days=$days',
    ),
  );

  /// Takes a card off entirely, keeping nothing of it.
  Future<Timeline> delete(
    CardKind kind,
    String id, {
    int days = defaultDays,
  }) => _day(
    () => apiClient.delete<Map<String, dynamic>>(
      '/${kind.path}/$id?days=$days',
    ),
  );

  /// Pauses the running card. Its end then moves with the clock.
  Future<Timeline> pause(
    CardKind kind,
    String id, {
    int days = defaultDays,
  }) => _day(
    () => apiClient.post<Map<String, dynamic>>(
      '/${kind.path}/$id/pause?days=$days',
    ),
  );

  /// Runs a paused card again.
  Future<Timeline> resume(
    CardKind kind,
    String id, {
    int days = defaultDays,
  }) => _day(
    () => apiClient.post<Map<String, dynamic>>(
      '/${kind.path}/$id/resume?days=$days',
    ),
  );

  /// Gives a card [minutes] more, pushing whatever comes after it.
  Future<Timeline> extend(
    CardKind kind,
    String id,
    int minutes, {
    int days = defaultDays,
  }) => _day(
    () => apiClient.post<Map<String, dynamic>>(
      '/${kind.path}/$id/extend?days=$days',
      data: {'minutes': minutes},
    ),
  );

  /// Renames a card, rewrites its notes, re-estimates it, or, for an event,
  /// gives it a new [startTime].
  Future<Timeline> edit(
    CardKind kind,
    String id, {
    String? title,
    String? notes,
    int? workMinutes,
    DateTime? startTime,
    int days = defaultDays,
  }) => _day(
    () => apiClient.patch<Map<String, dynamic>>(
      '/${kind.path}/$id?days=$days',
      data: {
        'title': ?title,
        'notes': ?notes,
        'workMinutes': ?workMinutes,
        if (startTime != null) 'startTime': startTime.toUtc().toIso8601String(),
      },
    ),
  );

  /// How many days are drawn when nobody says.
  static const defaultDays = 2;

  /// Runs a request that answers with the whole day, and reads the day.
  Future<Timeline> _day(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();

      return Timeline.fromJson(response.data ?? <String, dynamic>{});
    } on Object catch (error) {
      throw TimelineFailure.from(error);
    }
  }
}
