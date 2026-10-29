# Reminders

A reminder asks about one edge of a block, its start or its end, titled
with the block and asking one plain thing. A tap opens the app on a sheet
that asks it again, with the answers the card's own buttons give. Nothing
on the day ends in silence: a block nobody closed runs on, late, until the
next fixed block or the end of the working day. Researched in
[the RFC](../research/2026-10-28-notification-lifecycle/README.md),
delivered in
[2026-10-28-notification-lifecycle](../delivery/2026-10-28-notification-lifecycle/README.md),
and brought back to the basics (no buttons on the reminder, one at a time,
the Live Activity off) in
[2026-10-29-reminders-basics](../delivery/2026-10-29-reminders-basics/README.md).

## The contract

- **Every block has two edges.** A start is answered by
  `event.confirmed_at` (a fixed block) or by beginning the task; an end by
  `event.closed_at`, which done, the reminder sheet's Terminei and
  `catchUp`'s cap all set.
- **A fixed block starts at its hour, answered or not.** Confirming it
  changes nothing on the day; it only stops the asks. +10 on an unanswered
  start moves the block (`delay`).
- **An unanswered end is overtime, not done.** `catchUp` drags the end of
  a begun block past it along with the clock (a minute ahead), keeps
  `overtime_from` (the end it was planned to have), and the queue after it
  slides. The card carries `overtimeMinutes`. At the **cap**, the start of
  the next fixed block or the working day's end, whichever comes first, the
  block is closed there and its task written down as done at that hour. A
  begun task gives way to any fixed block that starts after it began; a
  fixed block only to one that starts after its own end (two booked to
  overlap do so on purpose).
- **One step, 10 minutes** (`STEP_MINUTES` on the server, `stepMinutes`
  in the app), counted **from the later of the planned hour and now**: the
  task snooze, the fixed block's delay, extend, and the ± on Agora. Extend
  on a late block counts from now and ends its overtime.
- **Routines are all fixed.** The flexible kind is gone: migration 0014
  set every routine fixed and deleted the flexible days nobody began, so
  the next read writes them as events.
- **The past is settled at deploy.** Migration 0014 sets `confirmed_at`
  and `closed_at` on every block whose start or end has passed, so nothing
  wakes up late.

## The plan

`GET /api/notifications/schedule` is still derived from the day on every ask
and never stored. Each item carries `kind`, `eventId` (the card a tap
opens: the task's id for a task), and on an ask `card` (`task` |
`event`) and `edge` (`start` | `end`).

| Kind | When | Title · body |
|---|---|---|
| `askStart` | a fixed block's start not confirmed; the next task's hour (when it came due) | Café · "Começando agora, certo?" |
| `askEnd` | the end of every begun block not closed (not while paused; from `overtime_from` when late) | Café · "Terminando agora, certo?"; asked again, Café · "Atraso no término · 10 minutos" |
| `headsUp` | 15 min before a fixed block that something runs right up to | Almoço · "Começa em 15 minutos, às 12:00" |
| `morning`, `evening` | every day, unchanged | — |

The title is always the card's title (`notification-copy.ts`). Each ask
comes twice, at its hour and +10 (`ASKS_PER_EDGE`), and the re-asks are
planned only within the next 24 hours (`REASK_HOURS`): the phone queues
the 60 soonest (iOS holds 64). An answered edge has no asks in the next
plan, so a sync after an answer takes its re-ask off. `almostFinishing` is
gone.

## Routes

| Route | What |
|---|---|
| `POST /events/:id/start` | confirms a fixed block's start |
| `POST /events/:id/delay { minutes? }` | an unanswered start moves to 10 (or `minutes`) after the later of its hour and now; refused once confirmed |
| `POST /tasks/:id/snooze { minutes? }` | from the later of its hour and now |
| `POST /tasks|events/:id/extend { minutes }` | from the later of the end and now; ends overtime |
| `POST /tasks|events/:id/done` | sets `closed_at` |

The sheet's answers post exactly what the card's button would:

| | start | end |
|---|---|---|
| task, the answer | Começar → `/tasks/:id/start` | Terminei → `/tasks/:id/done` |
| task, ten minutes | Esperar 10 min → `/tasks/:id/snooze` | Mais 10 min → `/tasks/:id/extend` |
| event, the answer | Confirmar → `/events/:id/start` | Terminei → `/events/:id/done` |
| event, ten minutes | Adiar 10 min → `/events/:id/delay` | Mais 10 min → `/events/:id/extend` |

Falar com a Lunna opens the agent's sheet, about the task when the card
is one. Dismissing the sheet answers nothing.

## In the app

- **A reminder has no buttons.** iOS draws them only when it is held
  down, so `LocalNotificationQueue` registers no category and the plugin
  has no background handler. A tap opens the app, on both platforms.
- `RemindersListener`: a tap (or the reminder that launched the app) reads
  the day again, and `ReminderAsk.of` decides whether the edge is still
  open: a task's start while it `awaitingStart`; a fixed block's start
  while it runs (delayed, it has not); an end from its hour on, while not
  given more time (late, or ending within the minute). Open, it draws
  `ReminderSheet` (`lib/notifications/view/reminder_sheet.dart`): the
  hours, the title, the question or "Atraso no término · N minutos", the
  ten minutes outlined on the left and the answer in the accent on the
  right, Falar com a Lunna under them. Its answer goes through
  `NotificationScheduler.answer`, which posts `NotificationAnswer.of` with
  `X-Lunna-Via: notification`, clears every reminder shown, and syncs.
  Answered already, or a heads-up or a greeting: the app opens on Tempo.
- **One reminder on the Lock Screen at a time.** iOS runs nothing when a
  local notification is delivered, so the old ones are cleared whenever
  the app runs: every `sync` (launch, coming back, any change to the day,
  the background refresh) takes the shown reminders out of the
  notification centre (`getActiveNotifications`, `cancel`) but the one
  that fired last, read from the `fireAt` its payload carries. On iOS the
  reminders of one card share a `threadIdentifier` (its id), so what is
  left stacks as one; on Android each goes when the next one is due
  (`timeoutAfter`). A reminder that takes the place of the one before *as
  it arrives* needs a push with `apns-collapse-id`: not built.
- `EventTile`, late (`overtimeMinutes > 0`) on Agora: no progress bar;
  `NowLate` says "Atraso no término · N minutos" in `dangerInk` with the
  warning mark, and under it +10 min outlined on the left and **Terminei**
  (✓, `onAccent`) filling the row on the right. Pause and −10 are left
  out. The ± step is `stepMinutes`.
- The running block's Live Activity is switched off
  ([live-activity.md](./live-activity.md)).

## Measuring

`X-Lunna-Via: notification | live_activity | app` on every request becomes `via` on the
write event `LoggingInterceptor` sends. `catchUp` captures
`block_closed_silently { kind, overMinutes }` for each block it closes at
the cap. Nothing a person wrote is sent.
