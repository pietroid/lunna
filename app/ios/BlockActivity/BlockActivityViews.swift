import SwiftUI

// The Live Activity of the block that is running: what the Lock Screen and
// the Dynamic Island draw. Plain SwiftUI, with no ActivityKit in it, so the
// same views draw the extension and the design prints.
//
// It changes only when the block's state does (begun, paused, resumed,
// given time, finished), never once a minute: the timers count by
// themselves, and the end is past when the clock says so (the activity's
// stale date is the block's end).

// `BlockState` and `BlockControl` are in BlockAttributes.swift, shared with
// the app.

/// The brand's colours, the same values as `AppColors` in `app_ui`.
struct BlockPalette {
  var surface: Color
  var ink: Color
  var ink2: Color
  var ink3: Color
  var fill: Color
  var accent: Color
  var onAccent: Color
  var warning: Color
  var mark: String
  var islandAccent: Color
  var islandOnAccent: Color

  static let lunna = BlockPalette(
    surface: Color(hex: 0xFFFFFF), ink: Color(hex: 0x1C1517),
    ink2: Color(hex: 0x6F6468), ink3: Color(hex: 0xA89DA1),
    fill: Color(hex: 0xF7F3F3), accent: Color(hex: 0xE2394F),
    onAccent: Color(hex: 0xFFFFFF), warning: Color(hex: 0xD9603A),
    mark: "LunnaMark",
    islandAccent: Color(hex: 0xF0596C), islandOnAccent: Color(hex: 0xFFFFFF))

  static let focus = BlockPalette(
    surface: Color(hex: 0x0D0D0D), ink: Color(hex: 0xF5F5F5),
    ink2: Color(hex: 0xA1A1A1), ink3: Color(hex: 0x6B6B6B),
    fill: Color(hex: 0x1C1C1C), accent: Color(hex: 0xEEFFBB),
    onAccent: Color(hex: 0x000000), warning: Color(hex: 0xFF9A6B),
    mark: "FocusMark",
    islandAccent: Color(hex: 0xEEFFBB), islandOnAccent: Color(hex: 0x000000))

  /// The Dynamic Island is always black: the dark brand's colours, with
  /// this brand's accent (lifted for black) and mark.
  var island: BlockPalette {
    var p = BlockPalette.focus
    p.accent = islandAccent
    p.onAccent = islandOnAccent
    p.mark = mark
    return p
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

// The app's type scale (`AppTypography`): Onest at 300, 400 and 500 only,
// never heavier, with tracking that tightens as the size grows.
extension View {
  func onest(
    _ size: CGFloat, _ weight: Font.Weight = .regular, tracking: CGFloat = -0.01
  ) -> some View {
    font(.custom("Onest", size: size).weight(weight)).tracking(size * tracking)
  }
}

private let hourFormat: DateFormatter = {
  let f = DateFormatter()
  f.locale = Locale(identifier: "pt_BR")
  f.dateFormat = "HH:mm"
  return f
}()

private func clock(_ seconds: TimeInterval) -> String {
  let s = max(0, Int(seconds))
  return String(format: "%d:%02d", s / 60, s % 60)
}

/// The time on the right: left to the end, frozen while paused, and
/// counted up once it is past.
struct BlockTimer: View {
  let state: BlockState
  let now: Date
  let palette: BlockPalette
  let size: CGFloat

  var body: some View {
    Group {
      if let left = state.pausedLeft {
        Text(clock(left)).foregroundStyle(palette.ink3)
      } else if state.over(at: now) {
        // `.timer` on a date gone by counts up from it.
        (Text("+") + Text(state.end, style: .timer))
          .foregroundStyle(palette.warning)
      } else {
        Text(timerInterval: now...state.end, countsDown: true)
          .foregroundStyle(palette.accent)
      }
    }
    // Big, the headline's 28/400; small, in the island's corner, 500.
    .onest(size, size > 20 ? .regular : .medium, tracking: size > 20 ? -0.02 : -0.01)
    .monospacedDigit()
    .multilineTextAlignment(.trailing)
  }
}

/// The line under the title: done so far, in the accent; frozen when
/// paused; whole, in the warning colour, in overtime.
struct BlockProgress: View {
  let state: BlockState
  let now: Date
  let palette: BlockPalette

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(palette.fill)
        Capsule().fill(color).frame(width: geo.size.width * fraction)
      }
    }
    .frame(height: 4)
  }

  private var color: Color {
    if state.paused { return palette.ink3 }
    return state.over(at: now) ? palette.warning : palette.accent
  }

  private var fraction: CGFloat {
    // Measured against the work alone, so time spent paused is not done.
    let whole = state.work
    guard whole > 0 else { return 1 }
    let left = state.pausedLeft ?? state.end.timeIntervalSince(now)
    return CGFloat(min(1, max(0, 1 - left / whole)))
  }
}

/// One button's face. The extension wraps it in `Button(intent:)`.
struct ControlFace: View {
  let control: BlockControl
  let palette: BlockPalette
  var compact = false

  var body: some View {
    let primary = control == .done
    HStack(spacing: 6) {
      switch control {
      case .pause: Image(systemName: "pause.fill")
      case .resume: Image(systemName: "play.fill")
      case .less: Text("−10")
      case .more: Text("+10")
      case .done:
        Image(systemName: "checkmark")
        if !compact { Text("Terminei") }
      }
    }
    // The app's control labels, 14/500; the symbols take the same weight.
    .onest(14, .medium)
    .foregroundStyle(primary ? palette.onAccent : palette.ink)
    // On the Lock Screen ✓ takes what the others leave; in the island all
    // four share the width.
    .frame(
      width: compact || primary ? nil : 58,
      height: compact ? 36 : 40)
    .frame(maxWidth: compact || primary ? .infinity : nil)
    .background(primary ? palette.accent : palette.fill, in: Capsule())
  }
}

/// Which buttons a state shows: ⏯ −10 +10 ✓, without −10 in overtime
/// (its end has already gone by).
func controls(for state: BlockState, at now: Date) -> [BlockControl] {
  let toggle: BlockControl = state.paused ? .resume : .pause
  if state.over(at: now) { return [toggle, .more, .done] }
  return [toggle, .less, .more, .done]
}

/// The banner on the Lock Screen.
struct BlockLockScreen<Wrap: View>: View {
  let state: BlockState
  let now: Date
  let palette: BlockPalette
  let wrap: (BlockControl, ControlFace) -> Wrap

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        palette.markImage.resizable().frame(width: 16, height: 16)
        Text(state.delivery ?? hourFormat.string(from: state.start))
          .lineLimit(1)
        Spacer(minLength: 8)
        status
      }
      .onest(13)
      .foregroundStyle(palette.ink2)

      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(state.title)
          .onest(17, .medium)
          .foregroundStyle(palette.ink)
          .lineLimit(1)
        Spacer(minLength: 8)
        BlockTimer(state: state, now: now, palette: palette, size: 28)
          .fixedSize()
      }

      BlockProgress(state: state, now: now, palette: palette)

      HStack(spacing: 8) {
        ForEach(controls(for: state, at: now), id: \.self) { c in
          wrap(c, ControlFace(control: c, palette: palette))
        }
      }
      .padding(.top, 2)
    }
    .padding(16)
  }

  @ViewBuilder private var status: some View {
    if state.paused {
      Text("Pausado")
    } else if state.over(at: now) {
      Text("Atrasado").foregroundStyle(palette.warning)
    } else {
      Text("até \(hourFormat.string(from: state.end))")
    }
  }
}

/// The Dynamic Island, expanded: the same card in the island's colours.
struct BlockIslandExpanded<Wrap: View>: View {
  let state: BlockState
  let now: Date
  let palette: BlockPalette
  let wrap: (BlockControl, ControlFace) -> Wrap

  var body: some View {
    let p = palette.island
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center, spacing: 10) {
        p.markImage.resizable().frame(width: 24, height: 24)
        VStack(alignment: .leading, spacing: 2) {
          Text(state.title).onest(16, .medium).foregroundStyle(p.ink)
            .lineLimit(1)
          Text(state.delivery ?? "até \(hourFormat.string(from: state.end))")
            .onest(12).foregroundStyle(p.ink2).lineLimit(1)
        }
        Spacer(minLength: 8)
        BlockTimer(state: state, now: now, palette: p, size: 26).fixedSize()
      }
      BlockProgress(state: state, now: now, palette: p)
      HStack(spacing: 8) {
        ForEach(controls(for: state, at: now), id: \.self) { c in
          wrap(c, ControlFace(control: c, palette: p, compact: true))
        }
      }
    }
  }
}

/// The Dynamic Island, compact: the mark on the left, the time on the right.
struct BlockIslandCompact: View {
  let state: BlockState
  let now: Date
  let palette: BlockPalette

  var body: some View {
    let p = palette.island
    HStack {
      p.markImage.resizable().frame(width: 20, height: 20)
      Spacer(minLength: 0)
      BlockTimer(state: state, now: now, palette: p, size: 15).fixedSize()
    }
  }
}
