# Focus: Local Notifications — Proposal

How Focus reminds someone of a block without an Apple Developer account.

Status: phases 1 to 3 built on 22/09/2026. Phase 4 not started.
Written 21/09/2026.

## Built, and where it differs from the proposal

- **Kinds.** `starting`, `almostFinishing`, `morning`, `evening`. There is
  no `upcoming` and no `overdue`. `almostFinishing` ships on, with no flag,
  and is skipped for any block under 20 minutes and for a paused block,
  whose end moves every minute.
- **Morning and evening.** 07:00 (`WORK_DAY_START_HOUR`) and 21:00 every
  day, weekends included. Ten messages each in
  `server/src/notifications/notification-copy.ts`, picked by a hash of the
  date so a re-sync never swaps the text of one already queued.
- **Blocks** are the events Focus booked (`managed`). Finishing or deleting
  a block removes the event, so its reminders drop out of the next plan.
- **Ids** also carry a short hash of the title and body, so a renamed block
  gets a new id and the old title does not stay on the queue.
- **Horizon.** Block reminders only reach as far as the calendar read does,
  which is the rest of today and tomorrow (`LOOK_AHEAD_HOURS` in
  `calendar-reader.service.ts`). The daily ones go the full 7 days.
- **Time zone** is always the calendar's, from the server. The app does not
  read the device zone and `flutter_timezone` is not used.
- **Time-sensitive does not work on a free team.** Xcode refuses the
  entitlement: "Personal development teams do not support the Time
  Sensitive Notifications capability." The app still asks for the
  time-sensitive level on `starting`, and iOS delivers it at the normal
  level. Adding `com.apple.developer.usernotifications.time-sensitive` to a
  `Runner.entitlements` turns it on once the account is paid.
- **Permission** is asked through a one-line sheet the first time a new
  block appears on an already loaded day, from the creation sheet or a
  conversation. "Agora não" is remembered like a system no. There is no
  toggle to turn reminders on later yet.
- **Background refresh** uses `workmanager`, pinned to 0.9.2+1 with
  overrides, because the newer iOS package needs the iOS 26 SDK and this
  machine is on Xcode 16.2. The iOS deployment target is now 14.0.
- **Tap** opens `/chat/<threadSlug>` when the block has a conversation and
  just opens the app otherwise.

## 0. Why local and not push

Remote push on iOS goes through APNs, and the Push Notifications capability
is gated behind the paid Apple Developer Program. A free personal signing
team can install the app but cannot hold that entitlement. `firebase_core`
is already in `app/pubspec.yaml` and does not help here: FCM on iOS is a
wrapper around APNs and needs the same paid key.

Three free or near-free ways out, ranked by how much they can be trusted:

1. **Local notifications.** Scheduled by iOS itself. Fire at the exact
   second, with no network, with the real Focus icon and name, and can use
   the time-sensitive interruption level to cut through a Focus mode. The
   only limit is that the time has to be known in advance.
2. **A third-party relay** (Pushover, $4.99 once, or Bark, free). Real APNs
   through someone else's app. Arrives in seconds and the server can fire it
   at any moment. The banner reads Pushover or Bark, not Focus.
3. **Web push to the home-screen PWA.** Free, standard VAPID, and it does
   carry the Focus icon from `app/web/manifest.json`. Also the least
   reliable: iOS revokes subscriptions from unused web apps, delivery is
   soft-timed, there is no custom sound, and nothing gets through Do Not
   Disturb.

Focus blocks have a start time that is known well before they start. That is
exactly the shape option 1 is good at, so this document specifies option 1.
Option 2 stays available as a later addition for the cases the server needs
to raise right now, and is out of scope here.

## 1. Shape

The server owns the schedule. The app owns the delivery.

The server already knows every block and already does the arithmetic in
`server/src/time/work-hours.ts` and `server/src/time/scheduling.ts`. It
computes *when to fire and what to say* and hands the app a flat list. The
app's only job is to mirror that list into the iOS notification queue and
keep the mirror honest.

Nothing about a notification is decided on the phone. Copy included, for two
reasons. Everything the user reads is in Brazilian Portuguese and the server
is where that already happens, per `AGENTS.md`. And the wording of a reminder
is the kind of thing that will be changed a dozen times, which should not
each cost an app release.

## 2. What the user actually gets

Three kinds, all in pt-BR:

| Kind | When it fires | Example |
| --- | --- | --- |
| `starting` | at the block's start time | **Revisão de código** / Começa agora, até 15:00 |
| `almostFinishing` | 10 minutes before a block ends, for blocks of 20 minutes or more | **Revisão de código** / Finaliza em 10 minutos |
| `morning` | 07:00 every day | **Bom dia** / one of ten messages |
| `evening` | 21:00 every day | **Boa noite** / one of ten messages |

`starting` is the one that should be time-sensitive, because it is the one
whose whole purpose is to arrive while the phone is in a Focus mode.

Calendar-only cards (`CardKind.calendar` in
`app/packages/chat/lib/src/models/thread.dart`) get no notification from
Focus. Google Calendar already notifies for those, and two alerts for one
event is worse than one.

There are fixed ones which have everyday and should be everyday, at 7am and at 9pm, with random messages. They are near the end of the day and just when the day starts, so they set off the tone for both day and sleep. Cheerful, simplistic ones are good.

## 3. Server side

New module, `server/src/notifications/`, holding one service and one
controller. It reads from the existing events and threads services and adds
no storage of its own: the schedule is derived, never persisted.

```
GET /notifications/schedule?horizonDays=7
```

```json
{
  "generatedAt": "2026-09-21T12:04:00Z",
  "timeZone": "America/Sao_Paulo",
  "items": [
    {
      "id": "starting:<eventId>:1758474000:3f9a21c0",
      "kind": "starting",
      "fireAt": "2026-09-21T14:00:00-03:00",
      "title": "Revisão de código",
      "body": "Começa agora, até 15:00",
      "timeSensitive": true,
      "threadSlug": "revisao-de-codigo"
    }
  ]
}
```

Notes on the payload:

- `id` is stable and deterministic: kind, card kind, slug, and the fire
  instant as an epoch. The same block at the same time always produces the
  same id, and a moved block produces a different one. This is what makes
  reconciliation on the phone a set comparison instead of a guess.
- `fireAt` carries an offset rather than plain UTC, so the phone never has to
  re-derive which wall clock the server meant.
- `timeZone` is the user's, in IANA form, so the app can build a
  `TZDateTime` that survives a trip abroad.
- `title` and `body` are final strings. The app never concatenates.
- `threadSlug` is what the tap deep-links to. Absent for calendar cards,
  which for now means absent entirely.

Horizon defaults to 7 days and is capped server side. Items already in the
past at generation time are dropped by the server, not the client.

The block-boundary arithmetic must come from the existing time helpers. A
second copy of "the day ends at ten" is the exact mistake
`work-hours.ts` was written to prevent, and its own header says so.

## 4. App side

New package, `app/packages/notifications/`, matching the layout the other
packages use. It does not go in `app/lib/`.

```
app/packages/notifications/
  lib/
    notifications.dart
    src/
      data/notifications_repository.dart     # GET the schedule via ApiClient
      models/notification_plan.dart          # NotificationPlan, NotificationKind
      service/notification_scheduler.dart    # the mirror, and the only thing
                                             # that touches the plugin
```

Dependencies: `flutter_local_notifications`, `timezone`, `flutter_timezone`.

`NotificationScheduler` exposes one real method, `sync()`, and everything
else is private. `sync()` fetches the plan, reads
`pendingNotificationRequests()`, and moves the queue to match:

1. Map every planned item to a deterministic 32-bit int id, hashed from the
   stable string id, so the plugin's integer ids and the server's string ids
   stay in step across launches.
2. Cancel every pending id not in the plan.
3. Schedule every planned id not already pending.
4. Leave the intersection alone.

The diff matters rather than cancelling everything and rescheduling. A
cancel-all leaves a window with an empty queue, and if the fetch that was
supposed to refill it fails, the user silently gets no reminders until the
next launch. The diff has no such window and only fails to add, never to
remove.

`sync()` is called from four places and is safe to call redundantly:

- app launch, after auth resolves
- app resume from background
- after any write that moves, creates, solves or deletes a block
- a `BGAppRefreshTask`, opportunistically (see §8)

## 5. Permission

Not on first launch. The permission prompt is asked the first time the user
does something that implies wanting a reminder, which is creating or
scheduling their first block, and it is preceded by one line of Portuguese
explaining what it buys. A prompt fired at launch, before the app has shown
what it is for, is the reliable way to get a permanent no.

If permission is denied, `sync()` becomes a no-op and the app says nothing
more about it. If it is denied and the user later schedules a block, the app
may point once at Settings, with no repetition.

`requestPermissions` asks for alert, badge and sound. Critical alerts are not
requested: that entitlement is also paid.

## 6. Time zones

Local notifications fire against the wall clock, so the whole path uses
`tz.TZDateTime` built from the server's `timeZone` and `fireAt`, never a raw
`DateTime`. `flutter_timezone` supplies the device zone at startup, which is
also what the app should send up so the server can notice a mismatch.

A block at 14:00 means 14:00 where the user is. Crossing a zone should move
the notification with the clock, which falls out of using `TZDateTime`
correctly and breaks immediately if it is not.

## 7. Edge cases

| Case | Behaviour |
| --- | --- |
| Block moved | New stable id, old one cancelled on next `sync()` |
| Block solved or deleted | Its items drop out of the plan, cancelled on next `sync()` |
| Two devices | Each mirrors the same plan independently. No coordination needed |
| Device offline | Unaffected. The queue is already on the phone |
| App reinstalled | Queue is empty, launch `sync()` refills it |
| Notification tapped | Deep link through `go_router` to the thread by `threadSlug` |
| Fired while app is open | Still shown. The app is not the only place the user is looking |
| Plan item already past | Dropped server side, and defensively skipped client side |
| More than 64 items | See below |

**The 64 limit.** iOS keeps only the 64 soonest pending notifications per
app and silently discards the rest. A full day is roughly 8 blocks, so three
kinds each gives about 24 a day and the ceiling lands somewhere under three
days. The app therefore sorts the plan by `fireAt`, takes the first 60, and
leaves headroom. The horizon being 7 days server side is deliberate: it
costs nothing, and the client trims.

## 8. The known gap, stated plainly

If the app is not opened for longer than the scheduled horizon, the queue
runs dry and reminders stop until the next launch. With roughly two and a
half days of headroom inside the 64-item limit, that means not opening Focus
for a long weekend.

Three things soften it, none of which fix it:

- `BGAppRefreshTask` re-syncs in the background. iOS decides when, typically
  once or twice a day for an app in regular use, and never on a guarantee.
- The horizon trim above keeps the queue as deep as iOS allows.
- Opening the app at all repairs everything instantly.

The real fix is a remote push that re-arms the queue, which is the paid
entitlement, or the Pushover relay from §0. Worth revisiting if the gap ever
actually bites.

## 9. Phases

1. **Path proof.** Permission flow, plugin wired, one hardcoded `upcoming`
   five minutes before each of today's blocks, computed on the phone from the
   cards already loaded, scheduled on launch only. No server work. This
   answers whether the notifications arrive, look right, and carry the Focus
   icon before anything is designed around them.
2. **Server owns it.** The `/notifications/schedule` endpoint, the
   `notifications` package, copy in pt-BR from the server, all three kinds.
   Launch and resume call sites.
3. **Keep it honest.** The reconcile diff, the write-triggered re-sync,
   `BGAppRefreshTask`, deep linking on tap, the 60-item trim.
4. **Optional.** A Live Activity for the block that is currently running,
   which gets a real countdown and progress ring on the Lock Screen for free,
   because `ProgressView(timerInterval:)` is animated by the system with no
   push involved. Needs a Widget Extension target and a hand-written
   MethodChannel, and is fully independent of everything above.

Phase 1 is an afternoon. Stop after it if the result is disappointing.

## 10. Files

New:

```
server/src/notifications/notifications.module.ts
server/src/notifications/notifications.controller.ts
server/src/notifications/notifications.service.ts
server/src/notifications/notifications.service.spec.ts
server/src/notifications/dto/notification-plan.dto.ts
app/packages/notifications/**
```

Changed:

```
server/src/app.module.ts          # register the module
app/pubspec.yaml                  # the new package
app/ios/Runner/Info.plist         # nothing for local notifications on iOS,
                                  # but see below for Android
app/android/app/src/main/AndroidManifest.xml
app/lib/main.dart                 # scheduler init, sync on launch
app/lib/shell/view/shell_page.dart # sync on resume
```

Android is not free of work even though it is not the problem being solved:
`POST_NOTIFICATIONS` is a runtime permission from API 33, and exact-time
scheduling wants `SCHEDULE_EXACT_ALARM` or an inexact fallback. The plugin
covers both, but they need declaring.

## 11. Open questions

1. Is `overdue` wanted at all, or is a reminder after the fact just guilt? Not wanted
2. Should `upcoming` be 5 minutes, or should it follow the block's length,
   for instance 15 minutes before a two-hour block? no upcoming
3. Does a calendar card really never notify, or should Focus notify for the
   ones it created in Google Calendar itself? We will take care of this later.
4. Is the time zone the user's profile setting or whatever the device says
   today? Timezone is always the server one for now.
