# Agent Notes

## Project

Lunna is a personal day planner with two parts:

1. **Flutter app** in `app/`: iOS, Android and web.
2. **NestJS backend** in `server/`: REST API, Better Auth, Postgres.

It started as a copy of Focus with the AI agent, the conversations, the
untimed "things" list and Google Calendar taken out. What is left is the
timeline and its calendar dynamics, the routines, the reminders, and the
design system.

### Language

Everything the user reads is in **Brazilian Portuguese**. On the app, every
such string lives in `app/packages/l10n/lib/arb/app_pt.arb` and is read
through `context.l10n` (or `lookupAppLocalizations` where there is no
context). A hardcoded user-facing string in Dart is a bug. The server still
writes its own refusals and reminder copy in Portuguese, and the app shows
them as written.

Code, comments, commits and this file stay in English.

## Stack

- **App:** Flutter + BLoC + go_router + l10n (ARB, `pt`).
- **Backend:** NestJS 11 + TypeScript + Better Auth + Drizzle ORM.
- **Database:** Postgres on Neon: a `dev` branch locally, `main` in
  production. `npm run db:local` runs an in-memory Postgres (PGlite) for
  working offline.
- **Deploy:** two ARM64 images on GHCR, pulled by a Raspberry Pi over SSH
  through a Cloudflare tunnel. See [SETUP.md](./SETUP.md).

## Layout

```
app/
  lib/                  shell, home (Tempo), routines page, landing, demo
  packages/
    api_client/         Dio + bearer token interceptor
    app_ui/             the design system: theme, tokens, widgets, AppFab
    auth/               Better Auth client: Google sign-in, token store
    l10n/               every user-facing string (pt-BR)
    notifications/      local reminder queue + background refresh
    timeline/           the day: bloc, repositories, timeline list, event page
server/
  src/
    auth/               Better Auth instance + SessionGuard
    calendar/           CalendarService (cache) over CalendarStore (Postgres)
    db/                 Drizzle schema + pool + boot-time migrations
    events/             the timeline routes, the read model, the layout rules
    tasks/              TaskStore (Postgres) over the task table
    notifications/      the reminder plan, derived from the calendar
    routines/           routine CRUD and day expansion
    time/               work hours, zones, the scheduler
  drizzle/              generated SQL migrations (committed)
deploy/                 docker-compose.yml, nginx.conf, web.Dockerfile
_product/record/        product notes (time-system.md)
```

## Auth

Better Auth runs inside the Nest server, mounted at `/api/auth/*` in
`main.ts` ahead of Nest's body parser (it reads the raw request itself).
Everything else under `/api` is Nest, protected by `SessionGuard`, which asks
Better Auth for the session behind the request and puts an `AuthUser` on it.

Google is the only way in, by two roads:

- **Web:** the OAuth redirect. `POST /api/auth/sign-in/social` answers with
  Google's URL, the browser leaves, comes back to `/`, and from then on sends
  the session cookie. The web app is served from the same origin as the API,
  so the cookie needs no CORS.
- **iOS/Android:** the native `google_sign_in` SDK produces an ID token
  (minted for the web client, via `serverClientId`), the app posts it to the
  same route, and the server verifies it against `GOOGLE_CLIENT_IDS` and
  answers with a session token. The app keeps it in the Keychain/Keystore
  (`TokenStore`) and sends it as `Authorization: Bearer` (Better Auth's
  `bearer` plugin).

`ALLOWED_EMAILS` gates sign-up: an address not on it never gets a user row.
The user table carries `timeZone`, which is the zone that person's day is
measured in.

Better Auth is ESM-only and the server compiles to CommonJS. That works
because Node ≥ 22.12 can `require()` ES modules; keep the images on Node 24.
Code under test must not import `better-auth` at runtime (Jest's CommonJS
sandbox cannot load it): `session.guard.ts` imports only its type.

## The calendar

**Postgres is the only record of when anything happens.** An event row is the
truth about a block of time. There is no outside calendar to mirror and
nothing to reconcile.

- `calendar/calendar.store.ts` defines `CalendarStore`, with
  `PgCalendarStore` (Drizzle) in production and `MemoryCalendarStore` in the
  end-to-end timeline tests. Both expand routines the same way.
- `calendar/calendar.service.ts` is a per-person cache in front of it. The
  timeline asks for the day dozens of times per request, so the window
  (two hours back, 36 ahead) is read at most every 30 seconds per person.
  **Writes go to the store first, then into the cache**, so the cache never
  holds what the database does not. One server process owns it, which is
  the deployment.
- `managed` is always true today. It stays in the schema for the day events
  arrive from an outside calendar (Google, later): those are drawn but never
  moved, renamed or removed.

### Routines

A routine is one row in `routine` with a rule (`daily`, `weekdays`,
`weekend`), a first occurrence whose wall-clock hour, in the person's zone,
is every day's, and `fixed`. **Reading a window writes down each day of each
routine that falls in it**, with `INSERT … ON CONFLICT DO NOTHING` on
(`routine_id`, `occurrence`):

- A **flexible** routine (the default) writes each day as a `task` anchored
  at the routine's hour (`not_before`). `TimelineService.day` does it, from
  `CalendarService.routineDays`, which hands out only days whose hour is
  still ahead. The day slides when something runs into it and waits to be
  begun, like any anchored task. One nobody began by the end of its working
  day is written off as `cancelled` (`isMissed`, by `catchUp`).
- A **fixed** routine writes each day as an `event` row, in
  `CalendarStore.window`. Nothing moves it.

From then on that day is its own row and the other days are untouched.
Taking a day off marks it `cancelled` rather than deleting it, so the next
read does not bring it back.

Changing a routine deletes its days that have not begun yet, both kinds;
the next read writes them again at the new hour and name. Removing a
routine deletes the days ahead and keeps the ones that happened.

### Notes

Every task and every block has free-text `notes`. The event page edits them
in place and saves them through `PATCH /api/tasks/:id` or
`PATCH /api/events/:id` a moment after typing stops, on blur, and when the
page closes.

## Tasks and events

Two kinds of card:

- A **task** (`task` table) is something to do, and **flexible**. It has a
  title, notes, a length (`minutes`) and a `position` in the queue
  (fractional, so a drag writes one row). Its hour is worked out on every
  read (`TimelineService.day`), so the list and the calendar can never
  disagree. It either takes its turn in the queue, or keeps an hour of its
  own (`not_before`, the **anchor**): written down at an hour, dropped into
  empty room at one, given one on the event page, snoozed, or a day of a
  flexible routine. A task gets an `event` row (`event.task_id`) only when
  it is begun; that row is its real hour, and pause, extend and finish work
  on it. Ticking a task off sets `done_at`. A begun task whose hour runs out
  is written down as done by `catchUp`. A task with `backlog` set waits in
  the **backlog** ("Depois eu priorizo") instead: it keeps its order and its
  length, has no hour, and the layout never sees it. `POST /tasks` writes
  into the backlog unless it says `backlog: false`, and then at the end of
  the queue, at a place (`index`, counted as a move counts) or at an hour
  (`notBefore`; an hour already past is now).
- An **event** is **fixed**: a block whose hour is the point of it, a day of
  a fixed routine, a meeting. It never waits, is never queued and nothing
  pushes it. Lista never shows one.

`GET /api/timeline?days=N` answers with every view at once:
`{ tasks, backlog, cards, workDay }`, `workDay` being the hours the
calendar's free stretches are cut from. `tasks` is every task with an hour,
the running one first and then the rest by their hours (`inOrder`), however
far ahead the queue reaches. `backlog` is
the backlog in its order, with no hours (`section: 'backlog'`). `cards` is
everything the calendar draws from now to the end of day N. Every write
under `/api/tasks` and `/api/events` takes the same `?days=` and answers
with the same shape.

## The timeline

The app draws the day two ways, switched at the top of Tempo and
remembered on the device (`TimelineModeCubit`):

- **Lista**: the tasks alone, each as tall as it needs, in two stages that
  are always drawn: **Fazer em breve** (every task with an hour, in one run
  with no day headings) and **Depois eu priorizo** (the backlog), each
  headed like a day of the calendar. A drag moves a
  task within either or across the line; the move carries `backlog: true`
  when it lands below it. A running task dropped in the backlog stops. Each
  stage ends in a **+** that writes something down at its end.
- **Calendário**: everything, to scale, day after day. Scrolling near the
  end asks for another week (`TimelineExtended`), up to 120 days. **Agora**
  is always drawn, the break with its line whenever nothing runs, and a
  task let go on it is begun. Every free stretch carries a small **+**
  and its hours, both stuck to the top of the part of it in sight (placed
  while painting, so they never lag the scroll); the hours run from the
  first one in sight, which is where the + writes.

In both, the heading of whatever is at the top stays pinned while it
scrolls, a chip brings Agora back once it is out of sight, and a card held
near the top or bottom edge scrolls the list, which is how a task goes to
another day. The `AppFab` writes wherever Tempo is looking (`TimelineAim`):
the first free hour in sight on the calendar, the end of the stage at the top
of the list.

There is one list per mode, in clock order, and the headings are cut out
of it by the clock rather than stored anywhere. `sectionOf` in
`events/event-sections.ts` is the whole filing system: `agora` for the hour
being lived through, `dia` for everything after it, under its `day`
(`YYYY-MM-DD` in the person's zone).

**An hour that has run out is not a section.** A block booked 11:20 to 11:25
is finished at 11:26 and is simply not drawn any more; the row stays,
because the hour happened. The app asks for the list again on each minute
boundary. Only finishing something *early* removes the row, since that frees
an hour still ahead.

Between cards the calendar draws the **free stretches** of the working day
(`TimelinePlan.freeSlots`). They are drop targets: a card lands where its
top edge is let go, on the five minutes nearest, sticking to the start of
the room or to the latest start that leaves a pause before the next block
when it is within ten minutes of either (`TimelineScale.landingIn`). A task
let go over one is posted as a move with `after` (that hour, its anchor)
and, when it had to be cut to fit, `minutes`; an event gets that hour
through `PATCH /api/events/:id`. A drop between two cards is a place in the
list of tasks, counting the tasks above it; right under a card that keeps
an hour (an event, or an anchored task) it is that card's end plus the
pause, as `after`, since a place in the queue says nothing about where such
a card is. Tapping empty room, or a +, opens the creation sheet on that
hour: flexible, as everything is, unless switched to Fixo. Between two
blocks, when the room left from that hour is 45 minutes or less, the sheet
opens on all of it (`FreeStretch.placementAt`).

### The time system

Every rule about when things happen is on the server:

- `time/work-hours.ts`: the working day (`WorkDay`, minutes after
  midnight) is each person's own, **07:00 to 22:00** until they change it,
  and blocks are spaced **5 minutes** apart, plus slot finding. The user
  table keeps it as `day_start`/`day_end`; `PATCH /api/users/me` with
  `{ workDay: { start: "07:00", end: "22:00" } }` sets it (the end may be
  `"24:00"`).
- `time/scheduling.ts`: `relayout`, the whole scheduler.
- `time/zone.ts`: wall-clock arithmetic in a named zone, always passed in,
  never the process's.
- `events/timeline.service.ts`: the read model, where the queue falls.
- `events/event-layout.service.ts`: what adding, dragging, starting,
  snoozing, pausing, extending and finishing do to the day.

#### One rule

The day is a queue of **tasks** flowing around everything that has an
hour, packed as close to now as it will go. `relayout` makes two passes:

1. **Anchored tasks**, in the order of their hours. Each takes its hour, or
   the first slot after it when something is in the way, and is then in
   the way of everything after it. An hour the clock has passed is now.
   This is the whole difference between flexible and fixed: whatever is
   really happening before a lunch at noon (a block that overran, a paused
   one, a meeting, a lunch before it that was pushed) pushes it later;
   nothing pushes an event.
2. **The queue**, one pass: each task takes the first slot that fits after
   the cursor, and the queue runs on into the following days for as long as
   it lasts. The anchors are obstacles, so a task nobody has begun fills the
   gap before a lunch or hops over it, and never pushes it.

Every event is an obstacle to both: meetings, fixed blocks, fixed routines,
and **a begun task's hour**, which keeps the hour it started at. Nothing the
layout works out is written down.

**A task does not start because its hour came.** The first one in the
queue, or an anchored one whose hour has come, sits at the current minute
(`awaitingStart`) until the user says so. `POST /tasks/:id/start` writes its
hour onto the calendar from this minute; `POST /tasks/:id/snooze` anchors it
fifteen minutes out. Dropping a task at the very top of the day, or on the
break under Agora (`start: true` on the move), counts as starting it.
Events never wait.

**A paused block owes its work.** Its end is dragged along with the clock
(by `catchUp`, on every read and on the server's minute tick) and the queue
after it follows.

Adding a task (`POST /tasks`) puts it where it was asked for (see above).
Adding a fixed block (`POST /events`) puts it at its hour. Dragging
(`POST /tasks/:id/move`) moves the task to a place in the list of tasks,
which counts the running task and the anchored ones (`queueIndexOf` turns
it into a place in the queue) and lifts any anchor, or, with `after`,
anchors it at that hour; a running task dragged anywhere else stops running
and goes back in the queue. Finishing
(`POST /tasks/:id/done`) keeps a running task as the hour it really took
and starts the rest of the queue five minutes later; one that never started
simply leaves the list.

#### The one guard

Dragging a task to the top of the day while something else is running is
the only move that destroys something, so it is the only one that asks. The
server answers the move with `guard: { kind: 'start_now', … }` and changes
nothing; the app draws `GuardSheet` and posts the answer to
`POST /tasks/timing`:

| Answer | What happens |
|--------|--------------|
| `solve_current` | the running block is finished and gives its hour away |
| `postpone_current` | a running task goes back in the queue, next after this one; a fixed block stays, and the task waits for it |

### The app shell

Three tabs: **Tempo** (the timeline), **Projetos** (a placeholder) and
**Menu**, which opens Rotina and sets when the day starts and ends. The
`AppFab` (a `+`) opens the creation sheet from any tab, on the day Tempo is
showing, and brings Tempo forward. The
greeting at the top of Tempo is the account menu: **Rotina** and **Sair**.

### Reminders

`notifications.service.ts` plans them from the day for the next days. Only
the **next** task (the earliest, anchored or not) gets a reminder, a `confirmStart` at its hour that asks
rather than announces; tapping it opens *Começar agora* / *Esperar 15 min*.
Every other task's hour moves too often to be worth one. Events get a plain
`starting` reminder. An item's `eventId` is the id of the card a tap opens:
the task's for a task. The phone mirrors the
plan into local notifications, so reminders arrive without push or network.

## Commands

```bash
# Server
cd server
npm run db:local        # optional: in-memory Postgres on :5433
npm run start:local     # watches; needs server/.env.local (see .env.example)
npm test                # unit + end-to-end timeline + PGlite store tests
npm run db:generate     # after editing src/db/schema.ts; commit drizzle/

# App
cd app
flutter run --flavor dev --dart-define-from-file env/dev.json
flutter run -d chrome --web-port 5173 --dart-define-from-file env/dev.json
(cd packages/l10n && flutter gen-l10n)   # after editing app_pt.arb; commit gen/
```

Migrations run on server boot (`migrateDatabase` in `main.ts`), so there is
no separate migrate step in deployment.
