import 'package:api_client/api_client.dart';
import 'package:chat/src/data/chat_failure.dart';
import 'package:chat/src/models/models.dart';

/// {@template things_repository}
/// Coisas: what has no hour yet, in the order the user means to do it.
///
/// Every call answers with the whole list, so the app never has to work out
/// what a change did to the order.
/// {@endtemplate}
class ThingsRepository {
  /// {@macro things_repository}
  const ThingsRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// Every thing, top first.
  Future<List<Thing>> fetchThings() =>
      _list(() => apiClient.get<List<dynamic>>('/things'));

  /// Writes a thing down at the bottom of the list.
  Future<List<Thing>> addThing({
    required String title,
    required int durationMinutes,
  }) => _list(
    () => apiClient.post<List<dynamic>>(
      '/things',
      data: {'title': title, 'durationMinutes': durationMinutes},
    ),
  );

  /// Renames a thing or changes how long it will take.
  Future<List<Thing>> editThing(
    String id, {
    String? title,
    int? durationMinutes,
  }) => _list(
    () => apiClient.patch<List<dynamic>>(
      '/things/$id',
      data: {'title': ?title, 'durationMinutes': ?durationMinutes},
    ),
  );

  /// Puts a thing at [index], counted with it lifted out.
  Future<List<Thing>> moveThing(String id, int index) => _list(
    () => apiClient.post<List<dynamic>>(
      '/things/$id/move',
      data: {'index': index},
    ),
  );

  /// Takes a thing off the list as done.
  Future<List<Thing>> finishThing(String id) =>
      _list(() => apiClient.post<List<dynamic>>('/things/$id/done'));

  /// Takes a thing off the list for good.
  Future<List<Thing>> deleteThing(String id) =>
      _list(() => apiClient.delete<List<dynamic>>('/things/$id'));

  /// Moves a thing onto the timeline, into the first gap that fits it.
  ///
  /// Answers with both lists: the things without it, and the day with it.
  Future<({List<Thing> things, List<TimelineEvent> cards})> scheduleThing(
    String id,
  ) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/things/$id/schedule',
      );
      final body = response.data ?? <String, dynamic>{};

      return (
        things: _things(body['things'] as List<dynamic>?),
        cards: (body['cards'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  Future<List<Thing>> _list(
    Future<Response<List<dynamic>>> Function() request,
  ) async {
    try {
      return _things((await request()).data);
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  static List<Thing> _things(List<dynamic>? raw) {
    return (raw ?? <dynamic>[])
        .map((e) => Thing.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
