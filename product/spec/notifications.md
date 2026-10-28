# Reminders

A reminder asks about one edge of a block, its start or its end, and its
buttons answer it without opening the app. Nothing on the day ends in
silence: a block nobody closed runs on, late, until the next fixed block
or the end of the working day. Researched in
[the RFC](../research/2026-10-28-notification-lifecycle/README.md),
delivered in
[product/delivery/2026-10-28-notification-lifecycle](../delivery/2026-10-28-notification-lifecycle/README.md).

## The contract

- **Every block has two edges.** A start is answered by
  `event.confirmed_at` (a fixed block) or by beginning the task; an end by
  `event.closed_at`, which done, the reminders' Confirmar and `catchUp`'s
  cap all set.
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

| Kind | When | Copy |
|---|---|---|
| `askStart` | a fixed block's start not confirmed; the next task's hour (when it came due) | "Café começou" · "Até 08:30"; a task: its title · "Está na hora. Começamos?" |
| `askEnd` | the end of every begun block not closed (not while paused; from `overtime_from` when late) | "Café terminou?" · "Se ainda não, ganhe mais 10 minutos." |
| `headsUp` | 15 min before a fixed block that something runs right up to | "Almoço em 15 minutos" · "Das 12:00 às 13:00" |
| `morning`, `evening` | every day, unchanged | — |

Each ask comes three times, at its hour and +10 and +20 (`ASKS_PER_EDGE`),
and the re-asks are planned only within the next 24 hours (`REASK_HOURS`):
the phone queues the 60 soonest (iOS holds 64). An answered edge has no asks in the next plan, so a
sync after an answer takes its re-asks off. `almostFinishing` is gone.

## Routes

| Route | What |
|---|---|
| `POST /events/:id/start` | confirms a fixed block's start |
| `POST /events/:id/delay { minutes? }` | an unanswered start moves to 10 (or `minutes`) after the later of its hour and now; refused once confirmed |
| `POST /tasks/:id/snooze { minutes? }` | from the later of its hour and now |
| `POST /tasks|events/:id/extend { minutes }` | from the later of the end and now; ends overtime |
| `POST /tasks|events/:id/done` | sets `closed_at` |

A reminder's button posts exactly what the card's button would:

| | start | end |
|---|---|---|
| task, Confirmar | `/tasks/:id/start` | `/tasks/:id/done` |
| task, +10 min | `/tasks/:id/snooze` | `/tasks/:id/extend` |
| event, Confirmar | `/events/:id/start` | `/events/:id/done` |
| event, +10 min | `/events/:id/delay` | `/events/:id/extend` |

## In the app

- `packages/notifications`: `NotificationAnswer.of` is the table above;
  `NotificationAction` the three button ids (`confirm`, `later`, `talk`).
  `LocalNotificationQueue` registers one Darwin category, `ask`
  (Confirmar, +10 min, Falar com a {appName}, the last one `foreground`),
  and gives it to every item that `asks`. Android registers nothing (#56).
- `lib/notifications/reminder_answers.dart`: `answerReminderInBackground`,
  the `@pragma('vm:entry-point')` handler the plugin runs in its own
  engine. It reads the token off the device, posts the answer with
  `ApiClient(via: 'notification')`, then syncs. `AppDelegate.swift` sets
  `FlutterLocalNotificationsPlugin.setPluginRegistrantCallback` so that
  engine has its plugins.
- `RemindersListener`: a tap on the reminder itself opens the card's page,
  always. Falar com a Lunna opens the agent's sheet, about the task when the
  card is one. The start sheet ("Começar agora" / "Esperar 10 min") is
  Android's only, until #56.
- `EventTile`: "atrasado N min" (`AppTag`, `danger`) on Agora while
  `overtimeMinutes > 0`; the ± step is `stepMinutes`.

## Measuring

`X-Lunna-Via: notification | app` on every request becomes `via` on the
write event `LoggingInterceptor` sends. `catchUp` captures
`block_closed_silently { kind, overMinutes }` for each block it closes at
the cap. Nothing a person wrote is sent.
