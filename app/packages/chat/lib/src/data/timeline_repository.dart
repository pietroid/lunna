import 'package:api_client/api_client.dart';
import 'package:chat/src/data/chat_failure.dart';
import 'package:chat/src/models/models.dart';

/// {@template timeline_repository}
/// The day: what is on it, and everything that changes it.
///
/// Every call here is about a block of time, which is an event on the
/// calendar. Conversations belong to the chat repository, and the one place
/// the two meet is [startThread], where talking about a block gives it a
/// thread.
/// {@endtemplate}
class TimelineRepository {
  /// {@macro timeline_repository}
  const TimelineRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// Every card the timeline draws, earliest first.
  Future<List<TimelineEvent>> fetchEvents() async {
    final response = await apiClient.get<List<dynamic>>('/events');

    return (response.data ?? <dynamic>[])
        .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Writes something down and puts it straight on the timeline.
  ///
  /// No agent runs and no conversation starts. The sheet already asked
  /// everything that has to be known to give something an hour, so the answer
  /// is the timeline with the new card already in it.
  Future<List<TimelineEvent>> createEvent({
    required String title,
    required int durationMinutes,
    required bool fixed,
    DateTime? startTime,
    DateTime? notBefore,
  }) async {
    try {
      final response = await apiClient.post<List<dynamic>>(
        '/events',
        data: {
          'title': title,
          'durationMinutes': durationMinutes,
          'fixed': fixed,
          if (startTime != null)
            'startTime': startTime.toUtc().toIso8601String(),
          if (notBefore != null)
            'notBefore': notBefore.toUtc().toIso8601String(),
        },
      );

      return (response.data ?? <dynamic>[])
          .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// Moves a card to [index] in the day's single list.
  ///
  /// One number, because there is one list. Everything a drop does to the
  /// hours of everything around it is worked out on the server, so the answer
  /// is the whole timeline rather than a confirmation.
  ///
  /// It is not always the new timeline. A move that displaces something that
  /// is already running comes back with a guard instead, and nothing has
  /// changed on the server until that guard is answered.
  ///
  /// A drop into a free stretch also says where that stretch starts, as
  /// [after], so the block is not laid out any earlier than the gap it was
  /// dropped into, and [minutes] when the user agreed to cut it to fit.
  Future<TimelineOutcome> moveEvent(
    String id,
    int index, {
    DateTime? after,
    int? minutes,
  }) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/events/$id/move',
        data: {
          'index': index,
          if (after != null) 'after': after.toUtc().toIso8601String(),
          'minutes': ?minutes,
        },
      );

      return TimelineOutcome.fromJson(response.data ?? <String, dynamic>{});
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// Says the user began a block that was waiting for them.
  ///
  /// A block whose hour has not come yet goes to the top of the day instead,
  /// which can raise the guard, so this answers the way a move does.
  Future<TimelineOutcome> startEvent(String id) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/events/$id/start',
      );

      return TimelineOutcome.fromJson(response.data ?? <String, dynamic>{});
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// Not yet: the block waits [minutes] more before asking again.
  Future<List<TimelineEvent>> snoozeEvent(String id, {int minutes = 15}) =>
      _day(
        () => apiClient.post<List<dynamic>>(
          '/events/$id/snooze',
          data: {'minutes': minutes},
        ),
      );

  /// Marks a block done.
  ///
  /// A running block keeps the hour it really took and the next thing starts
  /// five minutes later. Returns the whole list, because the hour it gives
  /// back is an hour the rest of the day moves up into.
  Future<List<TimelineEvent>> finishEvent(String id) =>
      _day(() => apiClient.post<List<dynamic>>('/events/$id/done'));

  /// Takes a block off the calendar entirely.
  Future<List<TimelineEvent>> deleteEvent(String id) =>
      _day(() => apiClient.delete<List<dynamic>>('/events/$id'));

  /// Pauses the running block. Its end then moves with the clock.
  Future<List<TimelineEvent>> pauseEvent(String id) =>
      _day(() => apiClient.post<List<dynamic>>('/events/$id/pause'));

  /// Runs a paused block again.
  Future<List<TimelineEvent>> resumeEvent(String id) =>
      _day(() => apiClient.post<List<dynamic>>('/events/$id/resume'));

  /// Gives a block [minutes] more, pushing whatever comes after it.
  Future<List<TimelineEvent>> extendEvent(String id, int minutes) => _day(
    () => apiClient.post<List<dynamic>>(
      '/events/$id/extend',
      data: {'minutes': minutes},
    ),
  );

  /// Renames a block, re-estimates it, or pins it to [startTime].
  Future<List<TimelineEvent>> editEvent(
    String id, {
    String? title,
    int? workMinutes,
    DateTime? startTime,
  }) => _day(
    () => apiClient.patch<List<dynamic>>(
      '/events/$id',
      data: {
        'title': ?title,
        'workMinutes': ?workMinutes,
        if (startTime != null) 'startTime': startTime.toUtc().toIso8601String(),
      },
    ),
  );

  /// Runs a request that answers with the whole day, and reads the day.
  Future<List<TimelineEvent>> _day(
    Future<Response<List<dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();

      return (response.data ?? <dynamic>[])
          .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// The conversation about a block, started if there is not one yet.
  ///
  /// A block has no thread by default. Tapping into one is the moment that
  /// changes, and the server writes the pairing onto the event.
  Future<Thread> startThread(String id) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/events/$id/thread',
      );

      return Thread.fromJson(response.data ?? <String, dynamic>{});
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// Answers a guard with the button the user tapped.
  ///
  /// The action object goes back exactly as it arrived: what a guard's answer
  /// means, and what it does to the rest of the day, is the server's to know.
  /// The app's whole part in it is drawing the buttons and saying which one
  /// was pressed.
  Future<TimelineOutcome> applyTiming(Map<String, dynamic> action) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/events/timing',
        data: {'action': action},
      );

      return TimelineOutcome.fromJson(response.data ?? <String, dynamic>{});
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// Waits for the calendar to catch up with what the app already shows.
  ///
  /// Called after a change, and never on the path the finger is on: the drag
  /// has already landed by the time this goes out. It comes back with nothing
  /// to say almost every time, and with a popup to draw when the booking did
  /// not make it across.
  Future<SyncOutcome> awaitSync() async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/events/sync',
      );

      return SyncOutcome.fromJson(response.data ?? <String, dynamic>{});
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// Pushes whatever did not reach the calendar again.
  Future<SyncOutcome> retrySync() async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/events/sync',
      );

      return SyncOutcome.fromJson(response.data ?? <String, dynamic>{});
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }
}
