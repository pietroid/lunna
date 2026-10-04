import 'dart:async';
import 'dart:developer';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:focus/auth_token_provider.dart';
import 'package:focus/firebase_options_production.dart' as prod;
import 'package:notifications/notifications.dart';
import 'package:workmanager/workmanager.dart';

/// The background task that re-syncs the reminder queue.
///
/// Must match `AppDelegate.notificationsRefreshTask` and
/// `BGTaskSchedulerPermittedIdentifiers` in the iOS Info.plist.
const notificationsRefreshTask = 'focus.notifications.refresh';

const _kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

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
      await Firebase.initializeApp(
        options: prod.DefaultFirebaseOptions.currentPlatform,
      );

      final authRepository = FirebaseAuthRepository();
      // The signed-in user is restored from disk, which takes a moment.
      final user = await authRepository.user.first.timeout(
        const Duration(seconds: 10),
      );
      if (user == null) return true;

      final apiClient = ApiClient(
        baseUrl: _kApiBaseUrl,
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
