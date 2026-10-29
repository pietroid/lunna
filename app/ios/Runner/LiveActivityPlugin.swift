import Flutter
import UIKit

/// The app's side of the running block's Live Activity: the
/// `lunna/live_activity` channel (`LiveActivity` in
/// `lib/notifications/live_activity.dart`) and the link a tap on the
/// activity opens the app with.
///
/// Registered on every engine: the app's, and the ones a reminder's button
/// or a background refresh runs in, which may update or end the activity
/// but not start it.
class LiveActivityPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  /// Every engine's channel, so a button's change reaches whichever runs.
  private static var channels: [FlutterMethodChannel] = []
  /// The card a tap launched the app on, until the app asks for it.
  private static var launchCard: String?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "lunna/live_activity", binaryMessenger: registrar.messenger())
    let instance = LiveActivityPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addSceneDelegate(instance)
    channels.append(channel)

    if #available(iOS 17.0, *) {
      BlockActivities.onChanged = {
        for channel in channels { channel.invokeMethod("changed", arguments: nil) }
      }
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "sync":
      let args = call.arguments as? [String: Any] ?? [:]
      if let base = args["apiBaseUrl"] as? String {
        UserDefaults.standard.set(base, forKey: "lunna.liveActivity.apiBaseUrl")
      }
      guard #available(iOS 17.0, *) else { return result(nil) }
      let state = (args["block"] as? [String: Any]).flatMap(BlockState.init(wire:))
      Task { @MainActor in
        await BlockActivities.sync(state)
        result(nil)
      }
    case "launchCard":
      result(LiveActivityPlugin.launchCard)
      LiveActivityPlugin.launchCard = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // A tap on the activity: on a cold launch the link comes with the scene,
  // and the app asks for it once it is up; otherwise it is opened now.

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard
      let card = connectionOptions?.urlContexts.lazy
        .compactMap({ BlockLink.card(in: $0.url) }).first
    else { return false }
    LiveActivityPlugin.launchCard = card
    return true
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    guard let card = URLContexts.lazy.compactMap({ BlockLink.card(in: $0.url) }).first
    else { return false }
    for channel in LiveActivityPlugin.channels {
      channel.invokeMethod("open", arguments: card)
    }
    return true
  }
}
