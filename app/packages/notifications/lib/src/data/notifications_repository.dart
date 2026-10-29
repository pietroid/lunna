import 'package:api_client/api_client.dart';
import 'package:notifications/src/models/notification_answer.dart';
import 'package:notifications/src/models/notification_plan.dart';

/// {@template notifications_repository}
/// Asks the server which reminders the device should be holding, and
/// writes what a reminder was answered with.
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

  /// Makes the write an answer to a reminder stands for, saying it came
  /// from one (`X-Lunna-Via: notification`).
  Future<void> answer(NotificationAnswer answer) async {
    await apiClient.post<Object?>(
      answer.path,
      data: answer.data,
      via: 'notification',
    );
  }
}
