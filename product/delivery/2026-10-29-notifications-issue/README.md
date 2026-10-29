# Reminders without their buttons, and no Live Activity on iOS

Issue [#63](https://github.com/pietroid/lunna/issues/63). **Plan track**: a
bug in native wiring, with no screen to design. Draft: sections 1 and 2 and
the Build brief. The build adds sections 3–5.

## 1. The prompt

> **Notifications issue**
>
> It seems notifications are not coming with the right information, like
> the "+10 min" "confirmar" and "talk to lunna". Also live notifications are
> not appearing in iOS, maybe it happens because they are local
> notifications?

The design was reviewed on the issue, and the person replied:

> So is it not possible to have butttons on the notification already? I
> mean, just adding a local notificaiton and showing the buttons without
> user tapping it?

## 2. The plan

### The answer to the review: buttons without opening the reminder

**On iOS, not on a notification.** No app can put a reminder's buttons on
the banner or on the Lock Screen row: iOS draws a notification's actions
only in its expanded view (hold it, or pull the banner down), local or
pushed alike, and nothing in `UNNotificationCategory` changes that. What
a local reminder can do is be sure to carry its category, so that the
buttons are always there once it is expanded (H2 below).

**The surface on iOS that shows buttons without a touch is the Live
Activity**, and Lunna already has one: while a block runs it shows ⏯ −10
+10 Terminei on the Lock Screen, so the *end* of a running block is
already answered without expanding anything, once the activity appears
(H3, H4). The *start* of a block not yet begun has no such surface today:
the activity is drawn only while a block runs. Showing the **next** block
as a Live Activity with **Começar** and **+10 min** would give the start
reminder visible buttons too. That changes what is on the Lock Screen (a
waiting state for the activity, its copy, when it appears and goes) and
needs a mockup, so it is proposed as the next issue rather than folded
into this fix (decision 7).

**On Android, yes**: a notification's buttons are drawn on the
notification itself in the shade and on the heads-up banner. Lunna's
Android reminders have none yet (#56).

### What the code shows today

Neither feature has run on a phone. Both delivery READMEs list that as not
tested ([notification-lifecycle, "Not run"](../2026-10-28-notification-lifecycle/README.md),
[live-activity, "Not tested"](../2026-10-28-live-activity/README.md)). The
wiring looks right on paper. The `ask` category is registered in
`LocalNotificationQueue.initialize`, the extension is embedded with matching
bundle ids in all twelve configurations, and `NSSupportsLiveActivities` is
set. So the bug is in what the code does at run time. Reading the code
turns up four likely causes:

| # | Symptom | Likely cause | Where |
|---|---|---|---|
| H1 | No buttons | **iOS shows a reminder's actions only when it is expanded** (long press, or pulled down on the banner). A banner on its own has no buttons, and no API puts them there (see the answer above). | iOS behaviour |
| H2 | No buttons on some reminders | **Reminders queued by an older build keep no category.** `reconcile` leaves alone every reminder whose id is already queued. The id is the kind, the card, the instant and the text, so it does not change when only the category or the way it is drawn does. Those reminders fire without buttons until they are used up (re-asks reach 24 h ahead). | `notification_scheduler.dart` `reconcile` |
| H3 | No Live Activity after answering a reminder | **A Live Activity is not a notification, and only an app in front may start one** (`Activity.request`). Confirmar on a start reminder begins the block from the background engine, which may update or end an activity but never start one. The person's guess is half right: the reminders being local is not the problem, but starting from the background is. | `BlockActivities.sync`, `answerReminderInBackground` |
| H4 | No Live Activity even with the app open | **A failed start is never tried again.** Swift logs the error (`NSLog`) and answers `nil` either way. Dart then records the block as sent (`_sent`), and every later load of the same block sends nothing (`mapEquals`). So if the first sync comes before the scene is active (a cold launch), or while Live Activities are off, nothing retries until the block itself changes. | `live_activity.dart` `sync`, `BlockActivities.swift` |

### Approach

1. **Measure first, on the simulator** (iPhone 17, iOS 26.5, booted on this
   Mac). A debug entry point, `app/lib/notifications_issue_preview.dart`,
   runs the real `LocalNotificationQueue` and `LiveActivity` against fakes.
   It queues an `ask` reminder 10 s out and a plain one, then calls `sync`
   with a running card three ways: at launch, after `resumed`, and with
   Live Activities turned off. `xcrun simctl io … screenshot` takes the Lock
   Screen (the banner, the expanded reminder, the activity), and
   `log stream --predicate 'eventMessage CONTAINS "live activity"'` catches
   the Swift error. This shows which of H1–H4 are real before any fix lands.
   The entry point is deleted at the end.
2. **Re-queue whatever an older build queued (H2).**
   `NotificationScheduler.queueVersion` (an int in the code) is stored on
   the device under `notifications.queueVersion`. When the stored value
   differs, `_syncOnce` cancels everything pending and schedules the whole
   plan, then stores the new value. It is bumped whenever the way a reminder
   is drawn changes (category, interruption level, payload). This build
   bumps it to 1.
3. **Retry a failed Live Activity (H4).** The Swift `sync` answers with
   what it did (`shown`, `updated`, `ended`, `disabled`, `failed:<error>`).
   Dart records `_sent` only after `shown`, `updated` or `ended`.
   `RemindersListener` syncs again on `AppLifecycleState.resumed`, so
   opening the app with a block running always starts its activity.
   `failed` and `disabled` are sent to PostHog as
   `live_activity_not_started { reason }`, which carries no text the person
   wrote.
4. **H3 is explained, not solved, in this delivery** (see decision 3). After
   a reminder's Confirmar, the activity appears the next time the app is
   opened (step 3 makes sure it does). The spec says so in
   `live-activity.md`.
5. **H1 goes into the spec and the issue's answer.** The buttons are there
   once the reminder is expanded; buttons with no touch are the Live
   Activity's (the answer above). No copy changes. The simulator run of
   step 1 shoots the reminder twice, as a banner and expanded, so the
   person sees the difference in `img/`.
6. **On the person's phone**: a signed `lunnaDev` build with the checklist
   in "How it will be proved". Without it, the build only proves what the
   simulator can show.

### References

- [Apple, `Activity.request(attributes:content:pushType:)`](https://developer.apple.com/documentation/activitykit/activity/request(attributes:content:pushtype:)): an app starts a Live Activity only while it is in front (H3).
- [Apple, `Activity.pushToStartToken`](https://developer.apple.com/documentation/activitykit/activity/pushtostarttoken): starting one from a server push needs iOS 17.2+ and an APNs token (decision 3). [Apple forums #835188](https://developer.apple.com/forums/thread/835188) reports the token as nil on iOS 26.5.
- [Apple, Declaring your actionable notification types](https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types): actions show only for a notification carrying a registered category id, and only in the notification's expanded interface (H1, H2, the answer above).
- [Apple, Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities): a Live Activity's buttons (App Intents, iOS 17) are drawn on the Lock Screen with no touch first, which is why it is the surface for decision 7.
- [Android, Notifications overview](https://developer.android.com/develop/ui/views/notifications): up to three action buttons on the notification itself (the Android half of the answer, #56).
- `flutter_local_notifications` 22.3.1, `FlutterLocalNotificationsPlugin.m` (read in the pub cache): categories are set in `initialize` before permissions, and an action without `foreground` always goes to the background engine.

### Decisions

| # | Decision | Chosen | Why |
|---|---|---|---|
| 1 | Fix before measuring, or measure first | **Measure on the simulator first**, then fix only what it confirms (H2 and H4 are fixed either way, since the code shows them) | Two deliveries shipped on reading alone; this one should not |
| 2 | How old reminders get their buttons | **A queue version that re-queues everything once** | Ids stay stable, so a sync after an answer still only removes what it should; adding the category to the id would churn every id for nothing |
| 3 | Starting the activity from the lock screen (Confirmar with the app closed) | **Not in this delivery**: a follow-up RFC on ActivityKit push-to-start | It needs an APNs `.p8` key (a new secret and the person's Apple account), a table of push-to-start tokens, and a sender on the server, and on iOS 26.5 it is reported broken. That is a research question, not a fix |
| 4 | Making Confirmar a `foreground` action so the app can start the activity | **No** | It would open the app, which is what #54 removed |
| 5 | Reminder copy telling people to hold for the buttons | **No** | That is how iOS works everywhere. It goes in the spec and on the issue |
| 6 | Android | **Unchanged**: no buttons until #56 | Out of scope; asked below in case the person meant Android. Android is where buttons on the notification itself are possible |
| 7 | Buttons on the Lock Screen without expanding (the review's question) | **Not possible on an iOS notification; proposed as a follow-up issue: the next block as a Live Activity** with Começar and +10 min | The only iOS surface with buttons on sight is the Live Activity. A waiting state is new UI (mockup track), and it inherits H3: it can only be started while the app is in front, so it would be put up when the app is last opened before the block's hour (an activity lives 8 h). It goes after this fix, which makes the activity reliable first |

### How it will be proved

- `flutter test` on `packages/notifications`: a stored version older than
  `queueVersion` cancels every pending id and schedules the whole plan once;
  the same version leaves the queue alone. On the app, `LiveActivity`
  re-sends the same block after a `failed` answer and not after `shown`
  (fake channel).
- On the simulator: Lock Screen shots of the expanded reminder with its
  three buttons, and the activity after a cold launch with a block running.
  Both go in `img/`, together with the log lines for H4 before and after
  the fix.
- `.tool/check` (both brands) and `flutter build ios --simulator --debug`
  for `lunnaDev` and `focusDev`.
- On a device (the person's), not run by the build: an expanded reminder
  shows Confirmar, +10 min and Falar com a Lunna; Confirmar with the app
  killed begins the task; opening the app then shows the activity; ⏸ +10
  and Terminei work from the Lock Screen.

### Decided unattended

- Plan track, not a mockup: nothing on screen changes.
- Decision 3 (push-to-start goes to a follow-up RFC), decision 1 (measure
  first) and the queue-version approach of decision 2.
- After the review: the plan stays a plan (the answer is iOS's rule, not
  a screen), and decision 7: the next block as a Live Activity is a
  follow-up issue with its own mockup, not part of this fix.

### Open questions

- Was the phone an iPhone? Android draws no buttons by design (#56).
- "Not the right information": only the missing buttons, or is the title
  or text wrong too? If so, which reminder (start of a task, end of a
  block, the 15-minute heads-up)?
- Should push-to-start (the activity appearing right after Confirmar, with
  the app closed) be researched next? It needs an APNs key from the Apple
  account.
- Should the next block be shown as a Live Activity with Começar and
  +10 min (decision 7), so the start reminder has buttons on the Lock
  Screen without expanding? If yes, it is opened as its own `/create`
  issue (mockup track) after this one.

## Build brief

- **Read**: this README, `product/spec/notifications.md`,
  `product/spec/live-activity.md`,
  `app/packages/notifications/lib/src/service/{notification_queue,notification_scheduler}.dart`,
  `app/lib/notifications/{live_activity,reminder_answers}.dart`,
  `app/lib/notifications/view/reminders_listener.dart`,
  `app/ios/Runner/{AppDelegate,LiveActivityPlugin}.swift`,
  `app/ios/BlockActivity/BlockActivities.swift`.
- **App**: step 1's entry point and simulator run (record what it shows in
  section 3); `queueVersion` in `NotificationScheduler`; `sync`'s answer in
  Swift and Dart, the retry on `resumed`, and
  `live_activity_not_started` through `packages/analytics`. In step 1's
  run, shoot the reminder as a banner and expanded (`img/`), to show the
  person where the buttons are.
- **Server**: nothing.
- **Specs**: H1 and H3 in `live-activity.md` and `notifications.md`; the
  queue version in `notifications.md`.
- **Answer on the issue** (with the build): iOS draws a notification's
  buttons only expanded; a Live Activity is where buttons show with no
  touch; Android shows them on the notification (#56).
- **After the build**: open the push-to-start RFC as an issue, and the
  next-block Live Activity (decision 7) as a `/create` issue, if the
  person says yes to the questions above.
- **Cost**: the queue measures the run and writes the figures in the PR.
