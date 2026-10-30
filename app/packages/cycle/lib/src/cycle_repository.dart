import 'package:api_client/api_client.dart';
import 'package:cycle/src/models.dart';
import 'package:timeline/timeline.dart';

/// {@template cycle_repository}
/// Where the cycle, the weekend's rules and the dates off are read and
/// written (`/api/rhythm`).
///
/// Every write answers with all of it, as the server now has it. The day
/// changes too, so whoever writes asks the timeline again.
/// {@endtemplate}
class CycleRepository {
  /// {@macro cycle_repository}
  const CycleRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// Everything the cycle's page and Folgas draw.
  Future<Rhythm> load() async => _read(
    await apiClient.get<Map<String, dynamic>>('/rhythm'),
  );

  /// Writes the cycle down whole.
  Future<Rhythm> saveCycle(Cycle cycle) async => _read(
    await apiClient.put<Map<String, dynamic>>(
      '/rhythm/cycle',
      data: {
        'lastStart': _day(cycle.lastStart),
        'length': cycle.length,
        'periodLength': cycle.periodLength,
        'periodKind': cycle.periodKind.name,
        'nextStart': switch (cycle.nextStart) {
          final day? => _day(day),
          null => null,
        },
      },
    ),
  );

  /// A period began on [day]: the cycle starts again from it.
  Future<Rhythm> periodStarted(DateTime day) async => _read(
    await apiClient.post<Map<String, dynamic>>(
      '/rhythm/cycle/start',
      data: {'day': _day(day)},
    ),
  );

  /// Writes the weekend's rules and the light day's budget.
  Future<Rhythm> saveRules(RestRules rules) async => _read(
    await apiClient.patch<Map<String, dynamic>>(
      '/rhythm/rest',
      data: {
        'saturday': rules.saturday.name,
        'sunday': rules.sunday.name,
        'lightMinutes': rules.lightMinutes,
      },
    ),
  );

  /// Writes [day] down as [kind]: a day off named [title], or a day of the
  /// weekend put back to work.
  Future<Rhythm> addDay(
    DateTime day, {
    DayKind kind = DayKind.off,
    String title = '',
  }) async => _read(
    await apiClient.post<Map<String, dynamic>>(
      '/rhythm/days-off',
      data: {'day': _day(day), 'kind': kind.name, 'title': title},
    ),
  );

  /// Takes the date [id] away: the day is what the weekend and the cycle
  /// make it again.
  Future<Rhythm> removeDay(String id) async => _read(
    await apiClient.delete<Map<String, dynamic>>('/rhythm/days-off/$id'),
  );

  static Rhythm _read(Response<Map<String, dynamic>> response) =>
      Rhythm.fromJson(response.data ?? const {});

  static String _day(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
