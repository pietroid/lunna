import ActivityKit
import AppIntents
import Foundation
import Security

// Starts, updates and ends the activity, and answers its buttons. Compiled
// into both targets so `Button(intent:)` can name the intent, but it only
// ever runs in the app's process: a `LiveActivityIntent` in the app target
// is performed there, where the session token and the API's address are.

@available(iOS 17.0, *)
enum BlockActivities {
  /// Where the API is, kept by the app on each sync for the buttons.
  static let apiBaseUrlKey = "lunna.liveActivity.apiBaseUrl"
  /// The session token, as `TokenStore` keeps it (flutter_secure_storage:
  /// a generic password under this account).
  static let tokenAccount = "lunna.session_token"

  /// Called when a button changed the day, so the app reads it again.
  nonisolated(unsafe) static var onChanged: (() -> Void)?

  /// Shows [state], or ends every activity when it is nil. One activity at
  /// a time: a different block ends the one showing and starts its own.
  /// Starting needs the app in front; updating and ending do not.
  @MainActor
  static func sync(_ state: BlockState?) async {
    let showing = Activity<BlockAttributes>.activities
    guard let state else {
      for activity in showing { await activity.end(nil, dismissalPolicy: .immediate) }
      return
    }

    let content = ActivityContent(
      state: state,
      // When it passes iOS redraws the activity, and the view reads it late.
      staleDate: state.paused ? nil : state.end)
    if let current = showing.first(where: { $0.content.state.id == state.id }) {
      if current.content.state != state { await current.update(content) }
      for other in showing where other.id != current.id {
        await other.end(nil, dismissalPolicy: .immediate)
      }
      return
    }

    for activity in showing { await activity.end(nil, dismissalPolicy: .immediate) }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    do {
      _ = try Activity.request(attributes: BlockAttributes(), content: content)
    } catch {
      NSLog("live activity not started: \(error)")
    }
  }

  /// Posts what [control] stands for about the block [id] and redraws the
  /// activity from the day the server answers with. A refusal, or no
  /// network, leaves it as it was.
  @MainActor
  static func answer(_ control: BlockControl, id: String, kind: String) async {
    guard
      let base = UserDefaults.standard.string(forKey: apiBaseUrlKey),
      let token = token(),
      let url = URL(
        string: "\(base)/\(kind == "task" ? "tasks" : "events")/\(id)/\(control.route.path)?days=1")
    else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("live_activity", forHTTPHeaderField: "X-Lunna-Via")
    if let body = control.route.body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    }

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard
        let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status),
        let day = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      else { return }
      await sync(BlockState.running(in: day))
      onChanged?()
    } catch {
      NSLog("live activity answer failed: \(error)")
    }
  }

  private static func token() -> String? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrAccount: tokenAccount,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

/// A button on the activity: ⏯, −10, +10 or ✓, about one block.
@available(iOS 17.0, *)
struct BlockIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Responder ao bloco"
  static var isDiscoverable = false

  @Parameter(title: "Bloco") var id: String
  @Parameter(title: "Tipo") var kind: String
  @Parameter(title: "Resposta") var control: String

  init() {}

  init(_ control: BlockControl, state: BlockState) {
    id = state.id
    kind = state.kind
    self.control = control.rawValue
  }

  func perform() async throws -> some IntentResult {
    if let control = BlockControl(rawValue: control) {
      await BlockActivities.answer(control, id: id, kind: kind)
    }
    return .result()
  }
}
