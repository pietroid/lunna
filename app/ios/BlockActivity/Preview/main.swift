// Shoots the Live Activity views as 390x844 phone prints.
// swiftc BlockActivityViews.swift render.swift -o render && ./render <out>
import AppKit
import CoreText
import SwiftUI

let here = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let out = URL(fileURLWithPath: CommandLine.arguments[1])
CTFontManagerRegisterFontsForURL(here.appendingPathComponent("Onest.ttf") as CFURL, .process, nil)

// Timer texts count from the real clock, so every date is set around it,
// and the zone is shifted so that "now" reads as the scene's hour.
func at(_ h: Int, _ m: Int, _ s: Int = 0) -> Date {
  let now = Date()
  let utc = Int(now.timeIntervalSince1970) % 86400
  let want = h * 3600 + m * 60 + s
  var off = want - utc
  if off > 14 * 3600 { off -= 86400 }
  if off < -12 * 3600 { off += 86400 }
  NSTimeZone.default = TimeZone(secondsFromGMT: off)!
  return now
}

extension BlockPalette {
  var markImage: Image {
    let file = here.appendingPathComponent("\(mark).png")
    return Image(nsImage: NSImage(contentsOf: file) ?? NSImage())
  }
}

let wallpaper = LinearGradient(
  colors: [Color(hex: 0x3B3F6B), Color(hex: 0x7A5A86), Color(hex: 0xD98C8C)],
  startPoint: .top, endPoint: .bottom)

let face = { (_: BlockControl, f: ControlFace) in f }

struct StatusBar: View {
  let time: String
  var body: some View {
    HStack {
      Text(time).font(.system(size: 16, weight: .semibold))
      Spacer()
      Image(systemName: "cellularbars")
      Image(systemName: "wifi")
      Image(systemName: "battery.75percent")
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 32).padding(.top, 16)
  }
}

struct LockScreen<Card: View>: View {
  let hour: String
  @ViewBuilder let card: Card
  var body: some View {
    ZStack(alignment: .top) {
      wallpaper
      VStack(spacing: 0) {
        StatusBar(time: "").opacity(0)
        Image(systemName: "lock.fill").font(.system(size: 18)).foregroundStyle(.white)
          .padding(.top, 24)
        Text("quarta-feira, 28 de outubro")
          .font(.system(size: 20, weight: .medium)).foregroundStyle(.white.opacity(0.9))
          .padding(.top, 8)
        Text(hour).font(.system(size: 96, weight: .bold, design: .rounded))
          .foregroundStyle(.white.opacity(0.92))
        Spacer()
        card
          .background(RoundedRectangle(cornerRadius: 24).fill(.white))
          .padding(.horizontal, 14)
        HStack {
          Circle().fill(.black.opacity(0.25)).frame(width: 50, height: 50)
            .overlay(Image(systemName: "flashlight.off.fill").foregroundStyle(.white))
          Spacer()
          Circle().fill(.black.opacity(0.25)).frame(width: 50, height: 50)
            .overlay(Image(systemName: "camera.fill").foregroundStyle(.white))
        }
        .padding(.horizontal, 46).padding(.top, 40)
        Capsule().fill(.white).frame(width: 134, height: 5).padding(.vertical, 10)
      }
    }
    .frame(width: 390, height: 844)
  }
}

struct HomeScreen<Island: View>: View {
  let hour: String
  @ViewBuilder let island: Island
  var body: some View {
    ZStack(alignment: .top) {
      wallpaper
      VStack(spacing: 28) {
        ForEach(0..<5) { _ in
          HStack(spacing: 26) {
            ForEach(0..<4) { _ in
              RoundedRectangle(cornerRadius: 15).fill(.white.opacity(0.28))
                .frame(width: 62, height: 62)
            }
          }
        }
      }
      .padding(.top, 260)
      StatusBar(time: hour)
      island
    }
    .frame(width: 390, height: 844)
  }
}

@MainActor func shoot<V: View>(_ n: Int, _ view: V) {
  let r = ImageRenderer(content: view.environment(\.locale, Locale(identifier: "pt_BR")))
  r.scale = 2
  guard let img = r.nsImage, let tiff = img.tiffRepresentation,
        let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
  else { fatalError("scene \(n)") }
  try! png.write(to: out.appendingPathComponent("\(n).png"))
}

let p = BlockPalette.lunna
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// 1: running, 14:18 of 14:00–14:45.
var now = at(14, 18, 18)
let running = BlockState(
  id: "t1", kind: "task", title: "Relatório trimestral",
  delivery: "Fechamento Q3 · Acme",
  start: now.addingTimeInterval(-(18 * 60 + 19)), end: now.addingTimeInterval(26 * 60 + 41))
MainActor.assumeIsolated { shoot(1, LockScreen(hour: "14:18") {
  BlockLockScreen(state: running, now: now, palette: p, wrap: face)
}) }

// 2: paused at 14:18, seen at 14:25.
now = at(14, 25)
var paused = running
paused.pausedLeft = 26 * 60 + 41
paused.end = now.addingTimeInterval(26 * 60 + 41)
MainActor.assumeIsolated { shoot(2, LockScreen(hour: "14:25") {
  BlockLockScreen(state: paused, now: now, palette: p, wrap: face)
}) }

// 3: overtime, ended 14:45, seen at 14:51.
now = at(14, 51, 12)
var over = running
over.start = now.addingTimeInterval(-(51 * 60 + 12))
over.end = now.addingTimeInterval(-(6 * 60 + 12))
MainActor.assumeIsolated { shoot(3, LockScreen(hour: "14:51") {
  BlockLockScreen(state: over, now: now, palette: p, wrap: face)
}) }

// 4: compact island on the home screen.
now = at(14, 18, 18)
MainActor.assumeIsolated { shoot(4, HomeScreen(hour: "14:18") {
  HStack(spacing: 0) {
    BlockIslandCompact(state: running, now: now, palette: p)
  }
  .padding(.horizontal, 14)
  .frame(width: 200, height: 37)
  .background(Capsule().fill(.black))
  .overlay(Capsule().fill(Color(hex: 0x111111)).frame(width: 96, height: 37).opacity(0))
  .padding(.top, 11)
}) }

// 5: expanded island (a long press).
MainActor.assumeIsolated { shoot(5, HomeScreen(hour: "14:18") {
  BlockIslandExpanded(state: running, now: now, palette: p, wrap: face)
    .padding(.horizontal, 22).padding(.top, 50).padding(.bottom, 18)
    .frame(width: 374)
    .background(RoundedRectangle(cornerRadius: 46).fill(.black))
    .padding(.top, 8)
}) }
print("ok")
