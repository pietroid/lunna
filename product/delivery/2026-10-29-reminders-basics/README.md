# Reminders, back to the basics

Status: **design, waiting for approval** (issue
[#65](https://github.com/pietroid/lunna/issues/65)). Mockup track: the
reminder opens a sheet in the app, the late card changes and the copy
changes, all of it something the person sees.

## 1. The prompt

Issue #65, *Fix notifications interaction*:

> Notification interaction is less exciting than I thought. Let's stick to the basics again and treat properly the following scenarios:
>
> 1. A task that was delayed: we should show "atraso no término - x minutos" and remove the bar, and have a more evident button "finish it"
> 2. Cancel previous notifications: very often I see lunna have dozens of notifications. Usually notifications are timeline, so we can actually cancel the previous ones when sending one
> 3. Remove live activity for now: we should not be showing live activity, becase it is mostly confusing
>
> Because iOS is very limited in showing actions, we will do the following instead:
>
> 1. When user taps, it will open a popup in the app with the same actions we had (confirm, +10min, falar com lunna), the actions i mentioned are exampes but you should use the ones that we have for each case.
> 2. Improve texts because title and subtitle are a little confusing. For example: my slow morning..... subtitle: se ainda não, ganhe mais 10 minutos. What? It should be always like "tite of the task" - terminando agora, certo?

Worked unattended by the queue; the decisions it took alone are listed
under *Decided unattended*, and the person approves on the issue.

## 2. The design

![The board](img/mockup-board.png)

Drawn by the real app (`app/lib/reminders_preview.dart` on the demo's day,
Lunna). Each screen alone: [1](img/mockup-1.png) ·
[2](img/mockup-2.png) · [3](img/mockup-3.png) · [4](img/mockup-4.png) ·
[5](img/mockup-5.png). Pins in [board.json](img/board.json).

### The flow

1. **Agora, late.** A begun block past its end with no answer loses its
   progress bar (it would be full and say nothing). In its place, in the
   danger ink: **"Atraso no término · 12 minutos"**, and under it the one
   accent button of the card, **Terminei** (✓), with **+10 min** outlined
   beside it. Pause and −10 are left out while it is late: a late block is
   not being measured any more, only closed. Replaces the "atrasado N min"
   tag.
2. **A tap on a reminder opens a sheet** over Tempo, the same question the
   reminder asked, read again from the day (so "12 minutos" is what it is
   now, not what it was when the reminder fired): the hours, the title, the
   question, and three answers. A task's end: **Terminei** ·
   **Mais 10 min** · **Falar com a Lunna**.
3. **A task's start**: **Começar** (▶) · **Esperar 10 min** · Falar com a
   Lunna.
4. **A fixed block's start** (it starts anyway): **Confirmar** (▶) ·
   **Adiar 10 min** · Falar com a Lunna. A fixed block's end is the task's
   end (Terminei · Mais 10 min).
5. **The Lock Screen keeps one reminder**, titled with the card and asking
   one plain thing. Every new reminder takes the place of the one before.

### The answers, per case

They are the routes the reminders' buttons post today
(`NotificationAnswer.of`), unchanged; only where they are drawn moves.

| Case | Accent | Outlined | Quiet |
|---|---|---|---|
| task, start | Começar → `/tasks/:id/start` | Esperar 10 min → `/tasks/:id/snooze` | Falar com a Lunna |
| task, end | Terminei → `/tasks/:id/done` | Mais 10 min → `/tasks/:id/extend` | Falar com a Lunna |
| fixed block, start | Confirmar → `/events/:id/start` | Adiar 10 min → `/events/:id/delay` | Falar com a Lunna |
| fixed block, end | Terminei → `/events/:id/done` | Mais 10 min → `/events/:id/extend` | Falar com a Lunna |

Falar com a Lunna opens the agent's sheet about the card, as the button
does today. Dismissing the sheet answers nothing.

### The copy

The title is **always the card's title**; the body asks one thing.

| Kind | Today | New |
|---|---|---|
| `askStart`, task | Café · "Está na hora. Começamos?" | Café · **"Começando agora, certo?"** |
| `askStart`, fixed block | "Café começou" · "Até 08:30" | Café · **"Começando agora, certo?"** |
| `askEnd`, first ask | "Café terminou?" · "Se ainda não, ganhe mais 10 minutos." | Café · **"Terminando agora, certo?"** |
| `askEnd`, re-asks (+10, +20) | same as the first | Café · **"Atraso no término · 10 minutos"** (20) |
| `headsUp` | "Almoço em 15 minutos" · "Das 12:00 às 13:00" | Almoço · **"Começa em 15 minutos, às 12:00"** |
| `morning`, `evening` | unchanged | unchanged |

### References

Drawn from known patterns, not browsed: **Structured**'s "Did you finish?"
sheet when a task's time is up (the answer in the accent, more time
beside it), **Apple Reminders / Clock** keeping one live alert per thing
rather than a pile, and **Things**' quiet notifications that open the item
they are about.

### Decisions (the pins)

| Pin | Decision | Why |
|---|---|---|
| 1A | Late: the line "Atraso no término · N minutos" in `dangerInk` with the warning mark, where the bar was | the issue's words; the bar at 100 % says nothing |
| 1B | **Terminei** is the card's only accent button, full width; **+10 min** outlined beside it | "a more evident button"; ending is the likely answer to a late block |
| 1C | Pause, −10 and the "atrasado" tag go while late | one way to read the state, two answers |
| 2A | The sheet's head: hours (ink3), the title, the question | the title is what the reminder was about; the hours say which one |
| 2B | Accent ✓ **Terminei**, outlined **Mais 10 min**, tertiary **Falar com a Lunna** with the crescent | the same three answers the reminder's buttons had, ranked |
| 3A | A task's start: ▶ **Começar** · **Esperar 10 min** | the card's own words (`controlStart`, `controlWait10`) |
| 4A | A fixed block's start: ▶ **Confirmar** · **Adiar 10 min** | +10 on a fixed start moves it (`delay`), so it says *adiar* |
| 5A | Title = the card's title; body = one question | the issue's example: "Café — terminando agora, certo?" |
| 5B | One reminder of the app on the Lock Screen at a time | the issue's 2: the day is a timeline, the old ones are stale |

No new icon: ✓ (`AppIcons.check`), ▶ (`AppIcons.play`), ⚠
(`AppIcons.warning`), the crescent (`AppIcons.agent`).

### Decided unattended

- **The reminders lose their buttons on iOS.** The issue says the sheet
  comes *instead* of iOS's actions, so the `ask` category, its three
  buttons and the background engine that answered them
  (`answerReminderInBackground`, the plugin registrant in
  `AppDelegate.swift`) go. A tap is the only way to answer, and it is the
  same on Android, which closes #56 by the simpler road. `X-Lunna-Via:
  notification` stays, sent by the sheet's answers.
- **The sheet replaces the tap's card page and Android's start sheet**
  (`_startSheet`). A reminder about an edge already answered (the task
  begun, the block closed) opens Tempo without a sheet; a `headsUp`, a
  morning or an evening opens Tempo too.
- **"Cancel the previous ones" is done whenever the app runs**, since iOS
  runs no code when a local notification is delivered in the background:
  on launch, on resume, on every sync and in the background refresh, every
  delivered reminder older than the newest is removed
  (`getActiveNotifications` + `cancel(id)`); a sync after an answer
  removes them all. On Android each ask also carries `timeoutAfter` until
  the next one is due. To make the pile itself smaller, the re-asks go
  from two to **one** (`ASKS_PER_EDGE` 3 → 2: at the hour and +10), and
  every reminder of one card shares a `threadIdentifier`, so what is left
  stacks as one. See the open question about push.
- **The Live Activity is switched off, not deleted.** The app stops
  starting it and ends any one running at launch; the `BlockActivity`
  extension and `live_activity.dart` stay in the tree, unused, behind one
  constant (`kLiveActivity = false`), so turning it back on is one line.
  `product/spec/live-activity.md` says so.
- **Wording**: "Atraso no término · 12 minutos" with the app's middle dot
  rather than the issue's hyphen; the late button says **Terminei**, the
  word the Live Activity already used, rather than "Concluir".

### Open questions

- **Real replacement needs push.** A reminder can only take the place of
  the one before *at the moment it arrives* if it is a remote push with
  `apns-collapse-id` (or a local one reusing an id, which iOS allows only
  one of in the queue at a time). That means APNs keys and a server that
  sends on time, which today runs no timer at all (Neon's compute). This
  delivery clears on every app run instead; push is a separate RFC if the
  pile is still there.

## Build brief

Phase 3 starts here and Phase 4 removes this section.

**Files the design wrote or changed (uncommitted until the queue commits
them):**

- `app/lib/reminders_preview.dart`: the preview entry point, five scenes
  (`?s=1..5`). Delete after Phase 4's prints.
- `app/lib/notifications/view/reminder_sheet.dart`: `ReminderAsk`,
  `ReminderSheet` (+ `ReminderSheet.show`), real.
- `app/packages/timeline/lib/src/widgets/now_surface.dart`: `NowLate`,
  real; `event_tile.dart` draws it in place of the tag and `NowProgress`
  while `card.isLate`.
- `app/lib/demo/data/demo_repositories.dart`, `app/lib/demo/view/demo_app.dart`:
  a `late` option on the demo's day (the running task that many minutes
  past its end).
- `app/packages/l10n/lib/arb/app_pt.arb` (+ `gen/`): `reminderStarting`,
  `reminderEnding`, `reminderHours`, `lateEnd`, `reminderFinished`,
  `reminderDelay10`.

**Server** (`server/src/notifications/`):

- `notification-copy.ts`: titles are the card's title; bodies as in *The
  copy* (start, end, the late re-ask with its minutes, the heads-up).
- `notifications.service.ts`: `ASKS_PER_EDGE` 2; the re-ask of an end
  carries the late body; every item gets a `thread` (the card's id) for
  `threadIdentifier`. Update `notifications.service.spec.ts`.

**App:**

- `RemindersListener`: a tap (`NotificationTap` with an ask) looks the card
  up in the loaded day (waiting for it if it is loading), builds a
  `ReminderAsk` from it (hours, `overtimeMinutes`) and opens
  `ReminderSheet`; confirm and later post `NotificationAnswer.of` through
  `NotificationScheduler.answer` (via `notification`) and reload the day;
  talk opens the agent's sheet. Edge already answered → no sheet. Remove
  `_startSheet`, `_StartAnswer`, `_buttonsAnswer` and the open-on-launch
  question that only Android needed (the sheet covers it).
- `LocalNotificationQueue`: no Darwin category and no actions;
  `threadIdentifier`; `clearDelivered({keepNewest})` over
  `getActiveNotifications`, called from `sync`, launch, resume and the
  background refresh; Android `timeoutAfter`.
- Delete `reminder_answers.dart`'s background handler and the registrant
  callback in `AppDelegate.swift`.
- Live Activity off (`kLiveActivity = false`): `RemindersListener` stops
  syncing it, and ends any running one at launch.
- `EventTile`: the late branch (done); its tests: no progress bar and a
  Terminei button while `overtimeMinutes > 0`.
- Tests: `ReminderSheet` (the four cases' labels and the answer each
  returns, the late line), `RemindersListener` (tap → sheet → the route),
  the queue (no category, clearing), under both brands.

**Docs:** `product/spec/notifications.md` (the sheet, the copy, clearing,
two asks), `live-activity.md` (switched off), the Reminders section of
`AGENTS.md`.

**Design session cost:** measured by the queue and written in the PR.
