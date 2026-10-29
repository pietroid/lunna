import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The background refresh that re-syncs the reminder queue. Must match
  /// `BGTaskSchedulerPermittedIdentifiers` in Info.plist and the name the
  /// Dart side registers.
  static let notificationsRefreshTask = "lunna.notifications.refresh"

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
      AppDelegate.registerOwnPlugins(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: AppDelegate.notificationsRefreshTask,
      earliestBeginInSeconds: NSNumber(value: 6 * 60 * 60)
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    AppDelegate.registerOwnPlugins(with: engineBridge.pluginRegistry)
  }

  /// The app's own plugins, on every engine it runs: today the running
  /// block's Live Activity.
  static func registerOwnPlugins(with registry: FlutterPluginRegistry) {
    if let registrar = registry.registrar(forPlugin: "LiveActivityPlugin") {
      LiveActivityPlugin.register(with: registrar)
    }
  }
}
