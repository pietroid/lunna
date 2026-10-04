import 'package:api_client/api_client.dart';
import 'package:notifications/src/models/notification_plan.dart';

/// {@template notifications_repository}
/// Asks the server which reminders the device should be holding.
/// {@endtemplate}
class NotificationsRepository {
  /// {@macro notifications_repository}
  const NotificationsRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// The plan for the next [horizonDays] days.
  Future<NotificationPlan> fetchPlan({int horizonDays = 7}) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/notifications/schedule',
      queryParameters: {'horizonDays': horizonDays},
    );

    return NotificationPlan.fromJson(response.data ?? const {});
  }
}
