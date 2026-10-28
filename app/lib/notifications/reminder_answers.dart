import 'dart:developer';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/widgets.dart';
import 'package:lunna/auth_token_provider.dart';
import 'package:lunna/config.dart';
import 'package:notifications/notifications.dart';

/// Answers a reminder's button chosen without opening the app: Confirmar or
/// +10 min, from the lock screen or the banner.
///
/// Runs in an engine of its own (the plugins come from
/// `FlutterLocalNotificationsPlugin.setPluginRegistrantCallback` in the
/// AppDelegate), with nothing of the app set up, as the background refresh
/// does. Posts the write the button stands for, saying it came from a
/// notification, then syncs, which takes the re-asks of that edge off the
/// queue. A failure is only logged: the reminder's re-ask, ten minutes
/// later, asks again.
@pragma('vm:entry-point')
Future<void> answerReminderInBackground(NotificationResponse response) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    final authRepository = BetterAuthRepository(apiBaseUrl: kApiBaseUrl);
    if (await authRepository.token() == null) return;

    final apiClient = ApiClient(
      baseUrl: kApiBaseUrl,
      tokenProvider: AuthTokenProvider(authRepository),
      via: 'notification',
    );
    await NotificationScheduler(
      repository: NotificationsRepository(apiClient: apiClient),
      // Initialising the queue in this engine keeps the same handler.
      onBackgroundAction: answerReminderInBackground,
    ).answer(tapOf(response.payload, response.actionId));
  } on Object catch (error, stackTrace) {
    log(
      'reminder answer failed',
      name: 'notifications',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
