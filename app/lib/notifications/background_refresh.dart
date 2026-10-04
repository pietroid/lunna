import 'dart:async';
import 'dart:developer';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lunna/auth_token_provider.dart';
import 'package:lunna/config.dart';
import 'package:notifications/notifications.dart';
import 'package:workmanager/workmanager.dart';

/// The background task that re-syncs the reminder queue.
///
/// Must match `AppDelegate.notificationsRefreshTask` and
/// `BGTaskSchedulerPermittedIdentifiers` in the iOS Info.plist.
const notificationsRefreshTask = 'lunna.notifications.refresh';

/// Asks the system to wake the app now and then to refresh the queue.
///
/// iOS decides when, typically once or twice a day for an app in regular
/// use, and never on a guarantee. It softens the one gap local reminders
/// have, which is a queue that runs dry when the app is not opened for days.
Future<void> registerBackgroundRefresh() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  try {
    await Workmanager().initialize(notificationsRefreshDispatcher);
    await Workmanager().registerPeriodicTask(
      notificationsRefreshTask,
      notificationsRefreshTask,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } on Object catch (error, stackTrace) {
    // A refresh that could not be registered costs nothing the next launch
    // does not repair.
    log(
      'background refresh not registered',
      name: 'notifications',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Runs in an isolate of its own, with nothing of the app's set up.
@pragma('vm:entry-point')
void notificationsRefreshDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // Signed out is nothing to refresh. The token is read straight off
      // the device; the server checks it on the request itself.
      final authRepository = BetterAuthRepository(apiBaseUrl: kApiBaseUrl);
      if (await authRepository.token() == null) return true;

      final apiClient = ApiClient(
        baseUrl: kApiBaseUrl,
        tokenProvider: AuthTokenProvider(authRepository),
      );
      await NotificationScheduler(
        repository: NotificationsRepository(apiClient: apiClient),
      ).sync();
    } on Object catch (error, stackTrace) {
      log(
        'background refresh failed',
        name: 'notifications',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Always a success. A failure asks the system to retry sooner, and the
    // next launch repairs the queue anyway.
    return true;
  });
}
