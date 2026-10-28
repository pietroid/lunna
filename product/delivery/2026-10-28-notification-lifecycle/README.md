# A reminder should take the answer, not open the app

2026-10-28 · delivery · **plan, revised after review, awaiting approval** · track: plan · issue #53

## 1. The prompt

From [issue #53](https://github.com/pietroid/lunna/issues/53):

> **Implement: A reminder should take the answer, not open the app**
>
> Build what the RFC [product/research/2026-10-28-notification-lifecycle/README.md](https://github.com/pietroid/lunna/blob/main/product/research/2026-10-28-notification-lifecycle/README.md) recommends, approved in #50 and merged in #51.
>
> - Read it as the research (see "From an RFC" in the /create skill): what it recommends, in its priority order, and its Rollout are the spec.
> - A `> **Decision**` note in it is binding; every other decision takes the option marked *(recommended)*.
> - The plan (or the board, if it changes what the person sees) says which rollout phases this PR ships, Phase 0 first.

The research is the RFC
[product/research/2026-10-28-notification-lifecycle](../../research/2026-10-28-notification-lifecycle/README.md).
Its binding decision: **every recommended option**. Unanswered overtime
ends at the next fixed block or the working day's end, and is written down
as done there. Every fixed block, meetings included, gets the three end
asks. The other options it recommends: all routines fixed, a 10-minute
step everywhere, re-asks queued for the next 24 h only, no push from the
server, `almostFinishing` dropped, and the Live Activity started by the
app, an intent or iOS 26 scheduling.

The plan was reviewed on the issue, and the person replied:

> Btw I have seen the title but actually if the user taps the notification it should go to the app anyway. You can implement everything for iOS. Leave android for later, you can create an issue just for that?

So a tap on a reminder (not on one of its buttons) opens the app, on
that card, whatever the title says; this PR builds the phone side for
iOS only; and Android's is
[issue #56](https://github.com/pietroid/lunna/issues/56).

## 2. The plan

**Track: plan.** The first phases change rules on the server and put
buttons on notifications the OS draws. The app's only new piece is a
small tag on a card. The one real layout, the Live Activity on the Lock
Screen, is Phase 3 in its own PR, and it gets a board there. It is drawn
in SwiftUI, so this Flutter preview could not draw it anyway.

### What this PR ships

The RFC has no Rollout section, so the phases below follow the order of
its change slides.

| Phase | What | Ships here |
|---|---|---|
| 0 | Measure: where each answer came from (`via`) and how many endings closed in silence, recorded before anything changes | yes |
| 1 | Server: one lifecycle (all routines fixed, overtime instead of "done", start and end asks for fixed blocks, +10 from the later of hour and tap, the new plan) | yes |
| 2 | Phone, **iOS only**: three buttons on every block reminder, answered in the background; a tap still opens the app; the overtime tag on the card and 10 min in the app's ± (both platforms, they are Flutter) | yes |
| 2A | Android: the same buttons, the start sheet removed, then the ongoing notification with a countdown | no: [#56](https://github.com/pietroid/lunna/issues/56) |
| 3 | iOS Live Activity (widget extension, App Intents) | no: next PR, mockup track |

### Approach

- **Phase 0, measure** (`common/logging.interceptor.ts`,
  `analytics/events.ts`): an `X-Lunna-Via: notification | app` header,
  set by the app's `ApiClient` from where the call came, becomes a `via`
  property on the write event already sent. `catchUp` captures
  `block_closed_silently` (`{ kind: task | event, overMinutes }`) every
  time it writes an ending nobody answered. Two weeks of it before the
  build ships give the baseline: today every silent ending is a `task.over`.
- **Phase 1, server.**
  - *Routines* (`routines/`, `calendar/`, `events/timeline.service.ts`):
    `fixed` defaults to true. A migration sets every routine fixed and
    deletes the flexible routine days that have not begun, so the next
    read writes them as events. `routineDays` and `isMissed` go, and their
    branch in `catchUp` with them.
  - *Schema* (`db/schema.ts`, one Drizzle migration): `event.confirmed_at`
    (the start was answered, or the block started anyway) and
    `event.closed_at` (the end was answered, or settled by the cap). Every
    existing row whose end has passed gets `closed_at = end_time`, so the
    deploy cannot make past blocks run on.
  - *Overtime* (`catchUp`, `event-layout.service.ts:926`): a begun block
    whose end passes with no `closed_at` is no longer done. Its end is
    dragged to now, as a paused block's is, and the queue after it
    slides. The end is capped at the start of the next fixed block or at
    the end of the working day. At the cap the block is closed and its
    task done at that hour. The card carries `overtimeMinutes`.
  - *A fixed block's start*: in silence it starts anyway. It closes the
    overtime of the block before it at its own start, so two blocks never
    run at once.
  - *Routes* (`events.controller.ts`, `request.ts`): `POST
    /events/:id/start` (confirm), `POST /events/:id/delay { minutes }`
    (the +10 of a fixed block's start). `snooze`, `extend` and `delay`
    count from **the later of the planned hour and now, plus 10**. `POST
    /events/:id/done` and `/tasks/:id/done` set `closed_at`. Each new
    route gets its row in `analytics/events.ts` and a spec.
  - *The plan* (`notifications/`): the kinds become `askStart`,
    `askEnd`, `headsUp`, `morning`, `evening`. Each unanswered edge gets
    the ask at the hour and re-asks at +10 and +20; the re-asks are only
    planned within 24 h. The 15-minute `headsUp` is planned only when
    something runs right up to a fixed block. `almostFinishing` goes, and
    so does the flexible "only the next task" rule's single ask: the next
    task gets the three start asks. Each item carries `edge`
    (`start | end`) so the phone knows which writes its buttons make. The
    copy stays on the server, in Portuguese: "Café começou", "Café
    terminou?", "Almoço em 15 minutos".
- **Phase 2, phone (iOS).**
  - *Actions* (`packages/notifications`, `notification_queue.dart`): one
    category, `ask`, in `DarwinInitializationSettings` only, with three actions:
    **Confirmar**, **+10 min** (background) and **Falar com a {appName}**
    (opens the app). The labels come from `app_pt.arb` and name the brand
    through `appName(AppBrand.id)`. A top-level
    `@pragma('vm:entry-point')` handler,
    `onDidReceiveBackgroundNotificationResponse`, reads the token as
    `background_refresh.dart` does, posts the answer for its `kind` ×
    `edge`, and then runs `NotificationScheduler.sync()`, which cancels the
    re-asks.
  - *iOS* (`AppDelegate.swift`): `FlutterLocalNotificationsPlugin.setPluginRegistrantCallback`,
    as workmanager's already is, so the background engine has its plugins.
  - *A tap opens the app.* Tapping the notification itself, not a
    button, always brings the app forward on that card's page
    (`eventId`), on a start ask, an end ask or a heads-up alike. The
    buttons are a shortcut; the tap is never taken away.
  - *Falar com a Lunna*: it opens the app with `AskDock`'s sheet already
    about that card (the `about` the notes' microphone passes today).
  - *The start sheet* (`reminders_listener.dart`) goes on iOS, where the
    buttons answer instead. On Android it stays, the only way to answer
    a start until #56; an end ask there opens the card.
  - *Android, until #56*: the server's new plan and copy reach it
    unchanged (they are platform-free); its notifications carry no
    buttons, and a tap opens the app as above.
  - *The card* (`packages/timeline`, `event_tile.dart`): an `AppTag`
    "atrasado N min" in `AppColors` danger while `overtimeMinutes > 0`.
    The ± on Agora go from 15 to 10.

### References

- [flutter_local_notifications 22.3.1](https://pub.dev/packages/flutter_local_notifications)
  (the version in `packages/notifications`), README "Notification
  actions": an action without `showsUserInterface` or `.foreground` wakes
  "a separate Flutter Engine" that calls
  `onDidReceiveBackgroundNotificationResponse`. On iOS the plugin
  registrant callback must be set in the AppDelegate. Categories go in
  `DarwinInitializationSettings.notificationCategories`.
- The same package's source: `AndroidNotificationDetails.chronometerCountDown`
  exists, so the Android countdown in Phase 3 needs no native code. There
  is no promoted-ongoing (Live Update) flag, so the RFC's Android 16
  promotion has to wait or be done natively. This answers one of the RFC's
  three unverified claims.
- [Iqbal & Bailey, CHI 2007](https://www.interruptions.net/literature/Iqbal_Bailey-CHI07.pdf):
  a coarse breakpoint comes ~7 min after a bad moment. This supports the
  10-minute re-ask.
- [Apple, Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities):
  the limits Phase 3 is designed against (16.1 for the activity, 17 for
  buttons, 4 KB of state).

### Decisions

| # | Decision | Chosen | Why |
|---|---|---|---|
| 1 | Phases in this PR | 0, 1, 2; the Live Activity next | a Swift extension and a board of its own; the buttons alone already cut a start from 4 steps to 2 |
| 2 | Unanswered overtime ends | at the next fixed block or the working day's end, done there | the RFC's binding decision |
| 3 | End asks | every fixed block, meetings included | binding |
| 4 | Routines | all fixed, flexible path deleted | RFC, recommended |
| 5 | Step | 10 min, in the app's ± too | RFC, recommended |
| 6 | Re-asks queued | next 24 h | RFC, recommended: 4.2 days of reach |
| 7 | Push | none | RFC, recommended: no keys, no sender, Neon sleeps |
| 8 | Marking an answered end | `event.closed_at`, new column | the end of a fixed block has no task row to hold a `done_at` |
| 9 | Past blocks at deploy | `closed_at = end_time` in the migration | otherwise every past block would wake up as overtime |
| 10 | Measuring | a `via` header and a `block_closed_silently` event, nothing a person wrote | analytics' rule; costs nothing without `POSTHOG_KEY` |
| 11 | The start sheet | removed on iOS; kept on Android until #56 | the buttons say what the sheet said; Android has no buttons yet |
| 12 | A tap on the notification | always opens the app, on the card | the person's review: buttons answer, the tap still goes to the app |
| 13 | Platforms | iOS only for the phone side; Android in [#56](https://github.com/pietroid/lunna/issues/56) | the person's review |

### How it will be proved

- `npm test` in `server/`: a spec per RFC example, on the frozen clock of
  `events.controller.spec.ts`. Breakfast +10 at 08:04 runs 08:14–08:44.
  Lunch +10 on the heads-up runs 12:10–13:10, and in silence it starts at
  12:00 and closes Relatório there. Relatório unanswered at 14:45 is
  "atrasado" at 14:46 and done at 15:20 with 80 minutes. The test at
  `events.controller.spec.ts:1163` is turned around: overtime, not done.
- `notifications.service.spec.ts`: three asks per edge, re-asks only
  within 24 h, no `almostFinishing`. The RFC's `code/plan-count.ts` re-run
  on the build should print the same 85 slots and 4.2 days.
- `flutter test` under both brands: the background handler maps each
  `kind` × `edge` × action to the right route (fake `ApiClient`), a tap
  (no action id) opens the card's page, the category is registered on
  Darwin only, and the tag is drawn at `overtimeMinutes > 0`.
- On an iPhone, written up in section 3: a button answered from the lock
  screen with the app killed reaches the server, the re-asks vanish after
  the sync, and a tap on the notification opens the app on the card.
  Without a device on this run, it is named there as not run.
- `.tool/preview`: Tempo with a card in overtime, both brands.

## Build brief

- **Files to touch.** Server: `notifications/` (service, copy, DTO,
  spec), `events/event-layout.service.ts` (`catchUp`, `_extend`,
  `snoozeTask`, `doneEvent`, new `startEvent`/`delayEvent`),
  `events/events.controller.ts`, `events/request.ts`,
  `events/timeline.service.ts` and `calendar/` (flexible routine days
  out, `overtimeMinutes` on the card), `routines/routines.service.ts`,
  `db/schema.ts` + `drizzle/`, `common/logging.interceptor.ts`,
  `analytics/events.ts`. App: `packages/notifications` (Darwin
  category, actions, `edge`), `lib/notifications/` (background handler;
  listener: a tap opens the card, the sheet only on Android), `packages/api_client` (the `via` header),
  `packages/timeline` (tag, ± 10, the card's `overtimeMinutes`),
  `packages/l10n` (button labels, tag), `ios/Runner/AppDelegate.swift`.
- **Docs.** In `AGENTS.md`: "Reminders" rewritten; "Routines" loses the
  flexible kind; "A task does not start because its hour came" gains
  overtime. In `product/spec/`, a new `notifications.md`.
- **Not in context, to read first.** `events.controller.spec.ts` (the
  harness, and the test at :1163), `reminders_listener.dart`,
  `notification_scheduler.dart` (the 60-slot cap), the RFC's
  `code/plan-count.ts`.
- **Not in this PR.** Android's buttons and countdown
  ([#56](https://github.com/pietroid/lunna/issues/56)); the Live Activity
  (Phase 3). Don't register the category on Android.
- **Open questions.** None block the build. One to check on a device:
  whether iOS keeps the 64 soonest or the 64 last scheduled
  (`notification_scheduler.dart:64`). The scheduler already sends the
  soonest first, so either way the next day is covered.

## Decided unattended

- Track: plan, not mockup. The phases that ship draw nothing of their own
  except one tag, and the Live Activity cannot be drawn by the Flutter
  preview.
- The RFC has no Rollout section. Its change slides, in order, became
  Phases 1–3, and Phase 0 measures first.
- The Live Activity and the Android ongoing notification were deferred to
  a later PR (Phase 3), with a board of their own.
- `event.closed_at` is my name for the answered end. The RFC names only
  `confirmed_at`.
- The past is closed at deploy (`closed_at = end_time`). The RFC does not
  say how to start.
- The start sheet goes, since the buttons say the same thing.
- After the review: Android keeps today's start sheet until #56, so it
  loses no way to answer while it has no buttons. An end ask on Android
  opens the card.
- Issue #56 was opened without the `create` label, so the queue does not
  start it before the person decides when.
- No cost table: the queue measures the run and writes the figures in
  the PR.
