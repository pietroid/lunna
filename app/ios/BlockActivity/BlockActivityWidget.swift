import ActivityKit
import SwiftUI
import WidgetKit

// The extension: the running block's Live Activity, drawn by the views in
// BlockActivityViews.swift in the brand's colours, each button an intent
// the app performs (BlockIntent).

@main
struct BlockActivityBundle: WidgetBundle {
  var body: some Widget {
    BlockActivityWidget()
  }
}

struct BlockActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: BlockAttributes.self) { context in
      // The stale date is the block's end: past it, iOS draws this again
      // and the views read the block as late.
      BlockLockScreen(state: context.state, now: Date(), palette: .current) {
        control, face in button(control, face, context.state)
      }
        .activityBackgroundTint(BlockPalette.current.surface)
        .activitySystemActionForegroundColor(BlockPalette.current.ink)
        .widgetURL(BlockLink.url(context.state))
    } dynamicIsland: { context in
      let now = Date()
      let island = BlockPalette.current.island
      return DynamicIsland {
        DynamicIslandExpandedRegion(.bottom) {
          BlockIslandExpanded(state: context.state, now: now, palette: .current) {
            control, face in button(control, face, context.state)
          }
        }
      } compactLeading: {
        island.markImage.resizable().frame(width: 20, height: 20)
      } compactTrailing: {
        BlockTimer(state: context.state, now: now, palette: island, size: 15)
          .frame(maxWidth: 64)
      } minimal: {
        island.markImage.resizable().frame(width: 20, height: 20)
      }
      .widgetURL(BlockLink.url(context.state))
      .keylineTint(island.accent)
    }
  }

  /// A button's face made a button: its intent posts the answer from the
  /// app's process.
  private func button(
    _ control: BlockControl, _ face: ControlFace, _ state: BlockState
  ) -> some View {
    Button(intent: BlockIntent(control, state: state)) { face }
      .buttonStyle(.plain)
  }
}
