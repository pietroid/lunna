# The running block on the Lock Screen (iOS Live Activity)

While a block runs, iOS 17 and later show it on the Lock Screen and in the
Dynamic Island: its name, its delivery (or the hour it began), the time
left counting down, a progress line, and four buttons, ⏯ −10 +10 and
**Terminei**. Delivered in
[2026-10-28-live-activity](../delivery/2026-10-28-live-activity/README.md),
Phase 3 of the
[notification-lifecycle RFC](../research/2026-10-28-notification-lifecycle/README.md).

## The contract

- **Only while a block runs**: Agora's begun task or its fixed block,
  paused or late included. Never the next block waiting to be begun, and
  nothing on a signed-out phone. One activity at a time: another block
  ends it and starts its own.
- **It changes only on state** (begun, paused, resumed, given time,
  finished), never once a minute. The timers are the system's
  (`Text(timerInterval:)`), and the activity's `staleDate` is the block's
  end, so when the end passes with nobody answering iOS redraws it as
  **Atrasado**, counting up from the end, without the app or a push.
- **Its buttons are the card's buttons.** Each is a `LiveActivityIntent`
  the app performs in its own process, posting the route the card already
  posts, with the session token from the Keychain and
  `X-Lunna-Via: live_activity`; it then redraws (or ends) the activity
  from the day the server answers with. A refusal or no network leaves it
  as it was. No new route, no push server.

| Button | Route (`/tasks/:id` or `/events/:id`) |
|---|---|
| ⏸ / ▶ | `…/pause` / `…/resume` |
| −10 / +10 | `…/extend { minutes: ±10 }` (−10 is not shown once late) |
| ✓ Terminei | `…/done`; the activity ends |

- **A tap elsewhere opens the app on the card** (`lunna-activity://card/<id>`
  → `/evento/<id>`).
- **Starting needs the app in front** (an ActivityKit rule): the app
  starts it when it loads a day with a block running. A reminder's button
  answered in the background can update or end it, not start it.

## The server

Nothing new but two fields: the card carries `overtimeFrom`, the planned
end a late block ran past (from its first second, before
`overtimeMinutes` appears), which is what the activity counts up from;
and `via` accepts `live_activity` (`analytics/events.ts`).

## In the app

- `lib/notifications/live_activity.dart`: `LiveActivity`, the
  `lunna/live_activity` channel, and `blockOf(cards)`, the rule above
  (instants in milliseconds, lengths in seconds; `end` is the end it
  counts to, `work` its length without pauses, `pausedLeft` while paused).
  It sends only when the block changed.
- `RemindersListener` syncs it on every day loaded, opens the card a tap
  came from (`opened`, `launchCard`), and reads the day again when a
  button changed it (`changes`). Sign-out ends it (`App`).
  `answerReminderInBackground` syncs it after a reminder's answer.
- `ios/Runner/LiveActivityPlugin.swift`: the channel, on every engine
  (`AppDelegate.registerOwnPlugins`), and the tap's link through Flutter's
  scene life cycle (`addSceneDelegate`).
- `ios/BlockActivity/` (the Widget Extension target, iOS 17):
  `BlockAttributes.swift` (`BlockState`, `BlockControl`, `BlockLink`,
  `BlockState.running(in:)`, the same rule as `blockOf`) and
  `BlockActivities.swift` (start/update/end, the intent, the Keychain
  read) are in both targets; `BlockActivityViews.swift` (the views and
  `BlockPalette`, both brands' `AppColors` values), `BlockMark.swift`
  (the brand, from `LunnaBrand` = `$(BRAND_ID)` in its Info.plist) and
  `BlockActivityWidget.swift` (the `ActivityConfiguration`) are the
  extension's. Onest is bundled (`Fonts/`, OFL); the copy is pt-BR in
  `Localizable.xcstrings`, since Swift cannot read `app_pt.arb`.
- Type follows `AppTypography`: Onest 300/400/500 only, through the
  `onest(size, weight)` modifier.

## Measuring

Writes from the activity's buttons arrive with `via: live_activity`, beside
`notification` and `app`, so their use can be read against the reminders'.
