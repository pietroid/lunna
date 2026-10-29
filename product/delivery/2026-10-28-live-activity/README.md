# The running block on the Lock Screen (Live Activity, iOS)

2026-10-28 · delivery · **draft, design** · track: mockup · issue #61

## 1. The prompt

From [issue #61](https://github.com/pietroid/lunna/issues/61):

> **Live activities from old issue**
>
> The issue about improving notification had three phases. I think just phase 1 and 2 were done. Can you check if phase 3, the part about live activities on ios was done?

### The answer: Phase 3 was not done

- The RFC [notification-lifecycle](../../research/2026-10-28-notification-lifecycle/README.md)
  (issue #50, merged in #51) asks for "a Live Activity (iOS)" carrying
  ⏯ −10 +10 ✓ while a block runs.
- Its build, [2026-10-28-notification-lifecycle](../2026-10-28-notification-lifecycle/README.md)
  (issue #53, PR #54), shipped Phases 0, 1 and 2 and lists
  **"3 · iOS Live Activity (widget extension, App Intents) · no: next PR,
  mockup track"**.
- The code agrees: `app/ios/` has only the `Runner` target, no widget
  extension, no `NSSupportsLiveActivities`, and nothing in the repo
  imports ActivityKit or names a Live Activity outside those two
  documents.

So this delivery is that Phase 3. The design follows the RFC: the
activity changes only on state, the buttons are App Intents posting the
routes the card already posts, it starts with the app, an intent or
(iOS 26) a schedule, and there is no push server. The Android ongoing
notification stays with [#56](https://github.com/pietroid/lunna/issues/56).

### The review, on the issue

> iOS 17 is good. Only when it runs. The fonts seem to bold doesn it? cant you have something similar to more natural looking of the flutter app?

So: the activity needs **iOS 17** (every phone that gets it has the
buttons), it shows **only while a block runs** (nothing for the next one
waiting to be begun), and the type now follows the app's scale.

## 2. The design

![The board](img/mockup-board.png)

Each screen alone: [1](img/mockup-1.png) · [2](img/mockup-2.png) ·
[3](img/mockup-3.png) · [4](img/mockup-4.png) · [5](img/mockup-5.png);
pins in [img/board.json](img/board.json).

**Drawn by the real views.** A Live Activity is SwiftUI in a widget
extension, which the Flutter preview cannot draw. So the board is drawn by
the SwiftUI views the extension will ship
([`app/ios/BlockActivity/BlockActivityViews.swift`](../../../app/ios/BlockActivity/BlockActivityViews.swift)),
rendered on the Mac with `ImageRenderer`
([`Preview/shoot.sh`](../../../app/ios/BlockActivity/Preview/shoot.sh)),
in Onest and the brand's `AppColors` values. Only the wallpaper, the
clock, the island's black shape and the home screen icons are the
harness's stand-ins for iOS.

**Lighter type, the app's scale.** The first round set everything in
Onest 600, which the app never uses: `AppTypography` stops at 500 (300
display, 400 headline and body, 500 titles and controls), with tracking
that tightens as the size grows. The views now read that scale: the time
28/400 (the headline), the title 17/500, the line above it 13/400, the
buttons and their symbols 14/500, the island's second line 12/400. Before
(top) and after:

![The banner before and after](img/weights-before-after.png)

**References** (from known patterns, not browsed): Apple's Clock timer
and Uber's ride activity (title, one big counting time, a thin progress
line); Structured and Things' running-task activities (controls on the
banner itself). Mobbin was not browsed.

| Pin | Decision | Chosen |
|---|---|---|
| 1A | What heads the banner | the brand mark and the task's delivery; without one, the hour it began |
| 1B | The time | time left, counted by the system (`Text(timerInterval:)`), in the accent, 28/400 like the app's headline; no update per minute |
| 1C | Progress | a 4 px line, done over `fill`, as the card's |
| 1D | ⏯ | pause / resume (`POST …/pause`, `…/resume`), one button that flips |
| 1E | −10 · +10 | `POST …/extend { minutes: ±10 }`; the server's "later of end and now" rule stands |
| 1F | ✓ | **Terminei**, the only accent button; `POST …/done`, and the activity ends at once. A tap anywhere else opens the app on the card |
| 2A–C | Paused | "Pausado" for the hour, the time left frozen in `ink3`, grey line, ▶ |
| 3A | Overtime without the app | the activity's `staleDate` is the block's end; when it passes iOS redraws it and the view reads "Atrasado" |
| 3B | Overtime time | counts up from the end (`+6:12`) in `warning`, line full |
| 3C | Buttons in overtime | ⏯ +10 Terminei; −10 goes, the end has passed |
| 4A | Mark on the island | the same mark image; on black its check drops out and the crescent remains |
| 4B | Compact | crescent left, time right; minimal is the crescent |
| — | Type | `AppTypography`'s weights only (300/400/500, never 600) and its tracking, through one `onest(size, weight)` modifier |
| — | When it shows | only while a block runs: begun, paused or in overtime; never for the next block waiting |
| 5A–B | Expanded | the same card in the dark brand's colours, Lunna's accent lifted for black (`#F0596C`); four equal buttons, ✓ icon only |

**Icons.** SF Symbols (`pause.fill`, `play.fill`, `checkmark`) on the
buttons, and −10 / +10 as text. Phosphor would need its glyphs exported
into the extension's asset catalogue for three icons iOS draws natively;
the brand mark is the existing `lunna.png` / `focus.png`.

## Build brief

*(Phase 3 starts here; Phase 4 replaces this section.)*

### Files the design wrote (kept for the build)

- `app/ios/BlockActivity/BlockActivityViews.swift`: `BlockState` (the
  activity's content state), `BlockControl`, `BlockPalette` (both brands),
  and the views: `BlockLockScreen`, `BlockIslandExpanded`,
  `BlockIslandCompact`, `BlockTimer`, `BlockProgress`, `ControlFace`.
  The views take a `wrap` closure so the extension wraps each face in
  `Button(intent:)`.
- `app/ios/BlockActivity/BlockMark.swift`: the mark from the asset
  catalogue.
- `app/ios/BlockActivity/Preview/` (`main.swift`, `shoot.sh`): the render
  harness. Phase 4 shoots both brands with it (add Focus scenes), then
  deletes it.

### What the build does

- **iOS, extension.** A Widget Extension target `BlockActivity`
  (deployment target **iOS 17**, the first with buttons in an activity;
  the app starts it behind `#available(iOS 17, *)`) with an
  `ActivityConfiguration(for: BlockAttributes.self)` over the views above:
  `activityBackgroundTint(palette.surface)`, `staleDate = end` on every
  update, dynamic island regions from `BlockIslandExpanded` /
  `BlockIslandCompact`, `widgetURL` to the card. Brand per flavor: an
  Info.plist key (`LunnaBrand`) set by the flavor's xcconfig picks
  `BlockPalette` and the mark asset; Onest bundled through `UIAppFonts`.
  `NSSupportsLiveActivities` on Runner. App Group not needed if the
  intents run in the app's process.
- **iOS, intents.** One `LiveActivityIntent` per control (or one with a
  `BlockControl` parameter) that posts `pause`, `resume`, `extend ±10`
  or `done` for `/api/tasks|events/:id`, with the bearer token the app
  keeps in the Keychain and `X-Lunna-Via: live_activity`, then updates
  or ends the activity from the timeline it gets back. A refusal (e.g. a
  pause the server rejects) leaves the activity as it was.
- **App ↔ native.** A method channel `lunna/live_activity` in
  `AppDelegate` with `sync(BlockState?)`: start, update or end. The app
  calls it from the timeline whenever the running card changes (in
  `packages/notifications`, beside the reminder sync, so both the app and
  the notification buttons' background isolate keep it right). Running
  card = Agora's begun task or event; nothing running ends it.
- **iOS 26.** When the next block is a fixed one, request its activity
  scheduled at its start (`request(…start:)`), as the reminders are
  queued. Behind `#available(iOS 26, *)`; skip if it proves unreliable.
- **Server.** No new route. Add `live_activity` as a `via` value in
  `analytics/events.ts` / `logging.interceptor.ts`, so its answers are
  counted apart from the notification's.
- **Type.** Keep the `onest(size, weight)` modifier and the weights in
  the views (300/400/500 only, `AppTypography`'s tracking); register the
  variable `Onest` in the extension so the weights resolve.
- **Strings.** The extension's copy ("até", "Pausado", "Atrasado",
  "Terminei") goes in its own `Localizable.xcstrings`, pt-BR, since Swift
  cannot read `app_pt.arb`. Name it in `AGENTS.md` under Language.
- **Docs.** `product/spec/notifications.md` gets the activity; the
  Reminders section of `AGENTS.md` a line.
- **Proof.** No simulator test reaches a Live Activity's buttons; verify
  on a device: start a task, lock, ⏸, +10, ✓, and the overtime redraw at
  the end. `.tool/check` for the Dart and server parts; an `xcodebuild`
  of both flavors for the extension.

### Decided unattended

- Track: mockup, with the board drawn by the extension's own SwiftUI
  views on the Mac instead of the Flutter preview, which cannot draw a
  Live Activity.
- Only Lunna is drawn; Focus uses the same views with `BlockPalette.focus`
  and is shot in Phase 4.
- −10 is hidden in overtime (the RFC lists ⏯ −10 +10 ✓ without saying
  what overtime shows).
- ✓ reads "Terminei" on the Lock Screen and is the only accent button.
- The overtime redraw comes from `staleDate`, not from the app or a push.
- SF Symbols on the buttons instead of Phosphor.
- An own method channel rather than a pub package (`live_activities`):
  the intents must call the API natively anyway, so the plugin would add
  a dependency for the one call that is simple.
- Second round: the exact sizes and weights of the lighter type (time
  28/400, title 17/500, header 13/400, buttons 14/500, island 16/500 and
  12/400), read off `AppTypography`; the SF Symbols on the buttons take
  the label's weight (500).

### Decided on review

- iOS 17 is the activity's minimum.
- Only while a block runs; the next block waiting to be begun gets none.
- The type follows the app's (lighter) scale.

### Open questions

None: both were answered on review (above).

### Cost

Measured by the queue: see the pull request.
