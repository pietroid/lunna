import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The background refresh that re-syncs the reminder queue. Must match
  /// `BGTaskSchedulerPermittedIdentifiers` in Info.plist and the name the
  /// Dart side registers.
  static let notificationsRefreshTask = "focus.notifications.refresh"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Reminders are shown even while the app is open, and a tap reaches the
    // plugin. Both need the app to be the notification centre's delegate.
    UNUserNotificationCenter.current().delegate = self

    // A background refresh runs in an engine of its own, which needs the
    // plugins registered on it the same way the app's engine has.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: AppDelegate.notificationsRefreshTask,
      earliestBeginInSeconds: NSNumber(value: 6 * 60 * 60)
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
