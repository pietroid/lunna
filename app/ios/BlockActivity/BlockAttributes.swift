#if os(iOS)
  import ActivityKit
#endif
import Foundation

// What the app and the extension share about the activity: its content,
// the buttons, and the rule for which block runs. Compiled into both
// targets (Runner and BlockActivity).

/// What the activity carries: about 200 bytes of the 4 KB allowed.
struct BlockState: Codable, Hashable {
  /// The card's id on the server, which the buttons answer about.
  var id: String
  /// `task` or `event`: which routes the buttons post to.
  var kind: String
  var title: String
  /// The delivery the task belongs to, if any.
  var delivery: String?
  /// When it began.
  var start: Date
  /// The end it counts down to, and up from once it has gone by.
  var end: Date
  /// Its length without its pauses, in seconds: what the line measures.
  var work: TimeInterval
  /// Seconds left when it was paused; nil while it runs.
  var pausedLeft: TimeInterval?

  var paused: Bool { pausedLeft != nil }

  /// Past its end with nobody saying so: overtime, counted up from [end].
  func over(at now: Date) -> Bool { !paused && now >= end }
}

extension BlockState {
  /// The block as the app sends it (`blockOf` in
  /// `lib/notifications/live_activity.dart`): instants in milliseconds,
  /// lengths in seconds.
  init?(wire: [String: Any]) {
    guard
      let id = wire["id"] as? String,
      let kind = wire["kind"] as? String,
      let title = wire["title"] as? String,
      let start = (wire["start"] as? NSNumber)?.doubleValue,
      let end = (wire["end"] as? NSNumber)?.doubleValue
    else { return nil }
    self.init(
      id: id, kind: kind, title: title,
      delivery: wire["delivery"] as? String,
      start: Date(timeIntervalSince1970: start / 1000),
      end: Date(timeIntervalSince1970: end / 1000),
      work: (wire["work"] as? NSNumber)?.doubleValue ?? end / 1000 - start / 1000,
      pausedLeft: (wire["pausedLeft"] as? NSNumber)?.doubleValue)
  }

  /// The block running in a timeline the server answered with
  /// (`{ tasks, cards, … }`), or nil when nothing runs. The same rule as
  /// the app's `blockOf`: Agora's begun task or fixed block, paused or late
  /// included, never a task waiting to be begun.
  static func running(in timeline: [String: Any]) -> BlockState? {
    let cards = timeline["cards"] as? [[String: Any]] ?? []
    guard
      let card = cards.first(where: { card in
        card["section"] as? String == "agora"
          && card["managed"] as? Bool ?? true
          && !(card["awaitingStart"] as? Bool ?? false)
          && (card["kind"] as? String != "task" || card["started"] as? Bool == true)
      }),
      let start = date(card["startTime"]),
      let endTime = date(card["endTime"])
    else { return nil }

    let pausedAt = date(card["pausedAt"])
    let remaining = (card["remainingSeconds"] as? NSNumber)?.doubleValue ?? 0
    let end =
      pausedAt.map { $0.addingTimeInterval(remaining) }
      ?? date(card["overtimeFrom"]) ?? endTime
    let workMinutes = (card["workMinutes"] as? NSNumber)?.doubleValue
    let artifact = card["artifact"] as? [String: Any]

    return BlockState(
      id: card["id"] as? String ?? "",
      kind: card["kind"] as? String ?? "event",
      title: card["title"] as? String ?? "",
      delivery: artifact?["title"] as? String,
      start: start,
      end: end,
      work: workMinutes.map { $0 * 60 } ?? end.timeIntervalSince(start),
      pausedLeft: pausedAt == nil ? nil : remaining)
  }

  private static func date(_ value: Any?) -> Date? {
    guard let text = value as? String else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: text) { return date }
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: text)
  }
}

/// The answers, each a route the app's card already posts.
enum BlockControl: String, Codable, CaseIterable {
  case pause, resume, less, more, done

  /// The route under `/tasks/:id` or `/events/:id`, and its body.
  var route: (path: String, body: [String: Any]?) {
    switch self {
    case .pause: return ("pause", nil)
    case .resume: return ("resume", nil)
    case .less: return ("extend", ["minutes": -10])
    case .more: return ("extend", ["minutes": 10])
    case .done: return ("done", nil)
    }
  }
}

/// The activity. Nothing is fixed for its whole life: one activity is one
/// block, and a different block ends it and starts another.
#if os(iOS)
  struct BlockAttributes: ActivityAttributes {
    typealias ContentState = BlockState
  }
#endif

/// The link a tap on the activity opens the app with:
/// `lunna-activity://card/<id>`, which the app turns into the card's page.
enum BlockLink {
  static let scheme = "lunna-activity"

  static func url(_ state: BlockState) -> URL? {
    var parts = URLComponents()
    parts.scheme = scheme
    parts.host = "card"
    parts.path = "/" + state.id
    return parts.url
  }

  /// The card's id in [url], when it is one of these.
  static func card(in url: URL) -> String? {
    guard url.scheme == scheme, url.host == "card" else { return nil }
    let id = String(url.path.dropFirst())
    return id.isEmpty ? nil : id
  }
}
