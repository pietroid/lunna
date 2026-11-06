# Agent Notes

## Project

Lunna is a personal day planner with two parts:

1. **Flutter app** in `app/`: iOS, Android and web.
2. **NestJS backend** in `server/`: REST API, Better Auth, Postgres.

It started as a copy of an earlier app with the AI agent, the
conversations, the untimed "things" list and Google Calendar taken out.
What is left is the timeline and its calendar dynamics, the routines, the
reminders, and the design system, plus a smaller agent of its own (see
"The agent").

### The look

One app, light: white, warm rose neutrals, a red accent, the crescent mark
(`lunna.pietroteruya.dev`, `com.pietroid.lunna`). Every colour is an
`AppColors` token in `app_ui`; screens never hard-code one. Native flavors
are `lunnaDev` and `lunnaProduction`; icons and splash come from
`app/brands/` ([app/brands/README.md](./app/brands/README.md)), and the web
build is stamped by `app/tool/brand_web.sh lunna`. Google is the only way
in: phones post ID tokens to the `google` provider, which accepts every
client listed in `GOOGLE_CLIENT_IDS`.

### Language

Everything the user reads is in **Brazilian Portuguese**. On the app, every
such string lives in `app/packages/l10n/lib/arb/app_pt.arb` and is read
through `context.l10n` (or `lookupAppLocalizations` where there is no
context). A hardcoded user-facing string in Dart is a bug. The iOS Live
Activity's copy, which Swift draws, is in
`app/ios/BlockActivity/Localizable.xcstrings`. The server still
writes its own refusals and reminder copy in Portuguese, and the app shows
them as written.

Code, comments, commits, issues and this file stay in English.
`app_en.arb` holds every string in English too, **only for previews and
prints**: `.tool/preview` builds with `PREVIEW_LANG=en` and a preview entry
point sets `locale: previewLocale`. The app itself always runs in pt-BR.

## Stack

- **App:** Flutter + BLoC + go_router + l10n (ARB, `pt`).
- **Backend:** NestJS 11 + TypeScript + Better Auth + Drizzle ORM.
- **Database:** Postgres on Neon: a `dev` branch locally, `main` in
  production. `npm run db:local` runs an in-memory Postgres (PGlite) for
  working offline.
- **Deploy:** two ARM64 images on GHCR (`lunna-backend`, `lunna-web`),
  pulled by a Raspberry Pi over SSH through a Cloudflare tunnel. See
  [SETUP.md](./SETUP.md).

## Layout

```
app/
  brands/               icons, splash and web assets (+ README)
  env/                  lunna.<env>.json defines (examples committed)
  ios/BlockActivity/    the running block's Live Activity (Widget Extension,
                        iOS 17): SwiftUI views, intents, the shared state
  tool/brand_web.sh     stamps Lunna's name and icons on a web build
  lib/                  shell, plan (Plano, the home: Agora, Pendentes,
                        Para depois; the play sheets, writeTask), tempo
                        (DayPage, the calendar), feed (the demo's
                        greeting), routines page, landing + demo
                        (the signed-out page, the app on fakes),
                        links (the real LinkPreviews)
  packages/
    agent/              the agent: the dock (one +), the composer, sheet,
                        the answer's surface (decoder, peeks, plan card),
                        suggestion, voice
    analytics/          PostHog behind one seam (Analytics, NoAnalytics)
    api_client/         Dio + bearer token interceptor
    app_ui/             the design system: theme, tokens, widgets, assets
    auth/               Better Auth client: Google sign-in, token store
    l10n/               every user-facing string (pt-BR)
    notifications/      local reminder queue, clearing what was shown, background refresh
    artifacts/          Entregas and Objetivos: queue, catalogue, goals, sheets, the delivery's page
    cycle/              Ciclo and Folgas: the cycle, the weekend's rule, the dates off (pages, cubit)
    timeline/           the day: bloc, repositories, timeline list, event page
server/
  src/
    agent/              the agent: OpenRouter client, tools, the board
                        (refs, dates, artifacts), actions/ (the registry:
                        one Action per verb), the answer and its A2UI
                        (answer.ts, speech.ts), gestures and the dry run, plans,
                        the composer's read (compose.ts, POST /agent/compose),
                        the suggestion (SuggestionStore, work-quality.ts,
                        SuggestionTimer),
                        conversations (ConversationStore), plans
                        (PlanStore), evals/
    analytics/          PostHog: the provider, the route → event table
    auth/               Better Auth instance + SessionGuard
    calendar/           CalendarService (cache) over CalendarStore (Postgres)
    db/                 Drizzle schema + pool + boot-time migrations
    events/             the timeline routes, the read model, the layout rules
    links/              link previews: the guarded page fetcher, the image proxy
    tasks/              TaskStore (Postgres) over the task table
    notifications/      the reminder plan (asks per edge), derived from the calendar
    artifacts/          ArtifactStore (+ its module): deliveries, catalogue, goals, the schedule
    rhythm/             RhythmStore (+ its module), the /rhythm routes: cycle, weekend, dates off
    routines/           routine CRUD and day expansion
    time/               work hours, zones, the scheduler, the kind of each day (day-kinds.ts)
  drizzle/              generated SQL migrations (committed)
  tool/coverage.mjs     which routes the agent reaches; every handler hands to a service
deploy/                 docker-compose.yml, nginx.conf, web.Dockerfile
product/
  spec/                 feature specs moved out of this file (agent, artifacts, home, …)
  delivery/             one folder per delivered feature: prompt, design, notes
  improvements/         one folder per /improve run: what changed, evidence, references
  research/             one folder per topic: the RFC (README.md, a deck), img/, data/, code/, reports/;
                        concepts.md, the ideas every RFC taught
.tool/                  internal tools: check (CI on what changed), map (where things are), preview (prints),
                        cost (session tokens), doc (open/annotate Markdown,
                        check an RFC's slides, print them),
                        queue (GitHub issues worked unattended, gate by gate),
                        multica (the second queue on the Mac: setup, check, score),
                        review.html (a PR's README on Pages, commented on by selection)
```

## Auth

Better Auth runs inside Nest at `/api/auth/*`; everything else under `/api` is guarded by `SessionGuard`, which puts an `AuthUser` on the request. Google is the only way in (the web's OAuth redirect; phones post an ID token, then send `Authorization: Bearer`). `ALLOWED_EMAILS` gates sign-up, and the user row carries the `timeZone` that person's day is measured in. **Code under test must not import `better-auth` at runtime** (it is ESM-only and Jest's CommonJS can't load it): `session.guard.ts` imports only its type. Keep the images on Node 24. See [product/spec/auth.md](./product/spec/auth.md).

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

A routine is one row in `routine` with a rule (`daily`, `weekdays`, `weekend`) and an hour. **Reading a window writes down each of its days in it** as a fixed `event` row (`INSERT … ON CONFLICT DO NOTHING` on `routine_id`, `occurrence`); from then on that day is its own row, and a day off is marked `cancelled`, not deleted. Changing a routine rewrites only the days not begun. Its checklist is copied to each day (`checklist`, ticked through `PATCH /api/tasks|events/:id`). See [product/spec/routines.md](./product/spec/routines.md).

### Notes

Every task and block has free-text `notes`, saved through `PATCH` a moment after typing stops, on blur and on close. **The notes stay text**: a link on a line of its own is drawn as a card, but pages read and write `LiveTextController.notes`, never `.text`. The microphone beside the notes dictates straight into them. See [product/spec/notes.md](./product/spec/notes.md) and [product/spec/links.md](./product/spec/links.md).

## Tasks and events

Two kinds of card:

- A **task** (`task` table) is something to do, and **flexible**. It has a
  title, notes, a length (`minutes`) and a `position` in the queue
  (fractional, so a drag writes one row). Its hour is worked out on every
  read (`TimelineService.day`), so the list and the calendar can never
  disagree. It either takes its turn in the queue, or keeps an hour of its
  own (`not_before`, the **anchor**): written down at an hour, dropped into
  empty room at one, given one on the event page, or snoozed. A task gets an `event` row (`event.task_id`) only when
  it is begun; that row is its real hour, and pause, extend and finish work
  on it. Ticking a task off sets `done_at`. A begun task whose hour runs out
  with nobody saying so runs on in overtime, and is written down as done by
  `catchUp` at the next fixed block or the end of the working day. A task with `backlog` set waits in
  the **backlog** ("Para depois") instead: it keeps its order and its
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
everything the calendar draws from now to the end of day N. A task of a
delivery carries `artifact: { id, title }` in all three: Lista and the
calendar join its tasks into the delivery's card, and the event page names
it (`AppTag`). Every write
under `/api/tasks` and `/api/events` takes the same `?days=` and answers
with the same shape.

## The timeline

`TimelineList` draws the day as **Lista** (the tasks alone, in stages: Agora, one day, Para depois; a delivery's run is one card) and **Calendário** (everything to scale; a drag nudges under 30 minutes, then swaps or takes a place or an hour; a card's seam resizes it). Since #77 the app shows only Calendário (`DayPage`); Plano is the list. **An hour that has run out is not a section**: a finished block is simply not drawn, and the app asks for the list again on each minute boundary while it is in sight (`MinuteRefresh`). Headings are cut out of one list by the clock (`sectionOf` in `events/event-sections.ts`). The free stretches are drop targets (`TimelinePlan.freeSlots`, `TimelineScale.landingIn`). Read [product/spec/timeline.md](./product/spec/timeline.md) before touching `app/packages/timeline/` or the drag routes.

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

**Nothing begins outside the working day.** Starting a task, or a drop
with `start: true`, before the day opens or after it ends is refused in
Portuguese (`refuseOutsideWorkDay`), and the queue never waits at the
current minute then: its first task is the next day's.

**A task does not start because its hour came.** The first one in the
queue, or an anchored one whose hour has come, sits at the current minute
(`awaitingStart`) until the user says so. `POST /tasks/:id/start` writes its
hour onto the calendar from this minute; `POST /tasks/:id/snooze` anchors it
ten minutes after the later of its hour and now. Dropping a task at the very top of the day, or on the
break under Agora (`start: true` on the move), counts as starting it.
Events never wait: a fixed block starts at its hour, answered or not
(`POST /events/:id/start` only confirms it, `POST /events/:id/delay`
moves an unanswered one ten minutes on).

**An end is answered, not assumed.** A begun block past its end with no
`closed_at` is in overtime: its end follows the clock, capped at the next
fixed block or the working day's end, where `catchUp` closes it. Done,
extend (from the later of its end and now) and the reminders' buttons
answer it.

**A paused block owes its work.** Its end is dragged along with the clock
(by `catchUp`, before every route that reads the day) and the queue after
it follows.

**Nothing on the server runs on a timer that touches Postgres.** Neon bills
the hours its compute is awake and puts it to sleep after 5 quiet minutes,
so whatever changes with the clock (a paused block's end, a block in
overtime, one closed at its cap) is stored as when it happened and
settled on that person's next request: `CatchUpInterceptor`
(`events/catch-up.interceptor.ts`) runs `catchUp` before the handler, bound
with `@UseInterceptors` on every controller that reads the day (timeline,
tasks, events, notifications, agent, artifacts). A new controller that
reads the day takes the same decorator. See
[the RFC](./product/research/2026-10-23-neon-compute/README.md). **The one
exception is a one-shot at an hour someone was told to look**, never
periodic: `SuggestionTimer` fires once per person at their suggestion's
`nextAt` (re-armed at boot), and a read past it writes the turn anyway.

Adding a task (`POST /tasks`) puts it where it was asked for (see above).
Adding a fixed block (`POST /events`) puts it at its hour. Dragging
(`POST /tasks/:id/move`) moves the task to a place in the list of tasks,
which counts the running task and the anchored ones (`queueIndexOf` turns
it into a place in the queue) and lifts any anchor, or, with `after`,
anchors it at that hour; a running task dragged anywhere else stops running
and goes back in the queue owing what it had left (`owedMinutes`), which is
pausing it. Finishing
(`POST /tasks/:id/done`) keeps a running task as the hour it really took
and starts the rest of the queue five minutes later; one that never started
simply leaves the list.

So a card behaves one of three ways, never stored as such and never drawn
differently except that events have their own colour (`fixedFill`):
**fixed** (an event: nothing moves it), **liquid** (a queued task: wherever
the queue packs it) and **flexible** (an anchored task: it keeps its hour,
waits to be begun, and is pushed later by whatever runs into it). A
flexible task **snapped** to what finishes early comes along: finishing a
block, or ticking off a task before it began (`doneTask`, `doneEvent`),
re-anchors every anchored task in the run right after it (each block
starting within ten minutes of the one before, `snappedAfter`) as much
earlier as the run now starts. The run stops at the first real gap and at
any event, so an isolated anchor keeps its hour. Nudging a task
(`shiftTask`) or pulling the seam under a block (`resizeTask`,
`resizeEvent`) carries the whole run, queued tasks included, and anchors
each at its new hour.

#### The one guard

Dragging a task to the top of the day while something else is running is
the only move that destroys something, so it is the only one that asks. The
server answers the move with `guard: { kind: 'start_now', … }` and changes
nothing; the app draws `GuardSheet` and posts the answer to
`POST /tasks/timing`. Play asks first (#89, `PauseQuestion`) and posts
the answer on the move itself (`move { start: true, decision }`), so the
guard is left to the roads that do not ask. The app offers only
`pause_current` (yes) or nothing (no):

| Answer | What happens |
|--------|--------------|
| `solve_current` | the running block is finished and gives its hour away |
| `pause_current` | a running task that ran 5 min or more is **split** (#89): what ran is a subtask done, what it owed a new subtask at the top of its delivery's Para depois (a loose task becomes one with subtasks, begun, so in **Pendentes**); under 5 min it stops whole, owing what it had left, in **Pendentes** (`task.pending_at` set); a fixed block stays, and the task waits for it |
| `later_current` | the same, into **Para depois** (top of the backlog, not pending) |
| `postpone_current` | older apps: a running task goes back in the queue, next after this one |

A loose task is **pending** when `pending_at` is set: a drop into
Pendentes (`move { backlog: true, pending: true }`) or a whole `pause_current`
sets it; any other move clears it. The card carries `pending: true`.

### The app shell

**One kind of task**: every task is one `TaskCard` (play on its left, pause while it runs); a delivery is a task with tasks of its own. Three tabs: **Plano** (`HomePage`: the agent's offer, Agora, Em seguida, Pendentes, Para depois), **Objetivos** and **Menu**; *Ver calendário* pushes `DayPage`. Play on a waiting task goes by strict rules (`timeline`'s `play.dart`): when, the pause while a task runs, how much; a piece splits the task into two subtasks on the server. Cards swipe (right done, left delete, each asked first) and Para depois is reordered by drag. **The + opens the composer** (`openComposer`, `POST /agent/compose`): nothing is written until Adicionar. **One round button on every screen, in the same place** (`AskDock` at `AskDock.location`); a new page floats an `AskDock` and leaves `kNotesDockClearance` under its last row. Feitas (`/feitas`) is every task ticked off. Read [product/spec/home.md](./product/spec/home.md) before touching `app/lib/plan/` or the shell.

### Entregas (artifacts)

A **delivery** (*entrega*; `Artifact` in code) is something owed by a day, with an optional kind from the person's catalogue, a total time and a value; there is no Entregas tab, it is drawn as a task on Plano. Its tasks are ordinary tasks (`task.artifact_id`). **Money counts when it is delivered** (`done_at`). Read [product/spec/artifacts.md](./product/spec/artifacts.md) before touching `server/src/artifacts/` or `app/packages/artifacts/`.

### Objetivos (goals)

A goal is **an amount of money to bill by a day** (R$ 10.000 by 30 Nov),
on a tab of its own. **Goals follow each other**: a new one starts the day
after the last one's deadline, or today, so no day counts twice. **No
delivery names a goal**: a goal counts the `value` of what was delivered
from its first day to its last, and the open deliveries due by then
(`queued`) are where it is heading. Its bar is a delivery's: green what is
in, red what its days ask by now, 15 % slack. Every delivery has an
editable **Valor**. Routes and rules in
[product/spec/goals.md](./product/spec/goals.md): read it before touching
goals on either side.

### Ciclo e folgas (the rhythm)

**Every date is work, light or off**, worked out on the server
(`time/day-kinds.ts`): a date written down in Folgas wins (a holiday, or
a weekend day put back to work); otherwise the strictest of the weekend
(**off by default**) and the cycle's period (**light by default**). The
queue puts nothing on a day off and, on a light day, only loose tasks up
to its budget (3 h): **a delivery's task hops to the next working day**.
Anchored tasks, events and routines keep their hours. A delivery's and a
goal's time, and the month's free minutes, **count working days only**
(`capacityShare`, `timeGone`). The timeline carries each such day as
`days`; Ciclo (`/ciclo`) and Folgas (`/folgas`) are under Menu's Ritmo,
over `/api/rhythm`. The cycle is health data: never sent to PostHog. See
[product/spec/cycle.md](./product/spec/cycle.md): read it before touching
`time/day-kinds.ts`, `server/src/rhythm/` or `app/packages/cycle/`.

### Reminders

**Every reminder asks about one edge** of a block, its start or its end (`askStart`, `askEnd`), at its hour and once more 10 minutes later. **A reminder has no buttons**: a tap opens the app on `ReminderSheet`. One reminder on the Lock Screen at a time. **Nothing ends in silence**: a begun block past its end with no answer is in overtime (see "An end is answered" above). Every "not yet" and "more time" is 10 minutes from the later of the planned hour and now (`STEP_MINUTES`). The Live Activity is off (`kLiveActivity = false`). See [product/spec/notifications.md](./product/spec/notifications.md).

### The agent

It reads the day and proposes changes to it: **reads run, writes are only ever proposed**; the person applies a plan whole, the server makes it through `EventLayoutService` and can undo it. **Every change it proposes is a gesture the person could have made by hand.** The model answers with one `answer` tool; the server fills every fact and sends one A2UI surface, and nothing the person reads carries a ref. **Each verb is one `Action` in `agent/actions/`.** Agent changes are measured with `npm run eval:agent` (real model, costs money, never in CI). Read [product/spec/agent.md](./product/spec/agent.md) before touching `server/src/agent/` or `app/packages/agent/`.

### The landing page

Signed out, the app is `LandingPage` (`app/lib/landing/`): the agent, Tempo
and Entregas as three chapters beside a phone running the real app on
fakes (`app/lib/demo/`), or on a narrow screen each chapter's piece of it.
**The demo never reaches a server**, and while it is up **the app's clock
reads 10:00** (`DemoClock`, wrapped around the app in `main.dart`), so
code there reads `clock.now()`, never `DateTime.now()`. See
[product/spec/landing.md](./product/spec/landing.md).

## Analytics

PostHog (US cloud, one project) hears of each write that
succeeded, by route, from `LoggingInterceptor`; of every 5xx and crash; of
the screens; and records replays with every text and image masked.
**Nothing a person wrote is ever sent**, and **without `POSTHOG_KEY`
nothing is sent at all**. A new write route gets its row in
`server/src/analytics/events.ts`. In the app only `packages/analytics`
calls the plugin; tests use `NoAnalytics`. See
[product/spec/analytics.md](./product/spec/analytics.md).

## Two queues

Work reaches the repo by two queues, on trial side by side
([RFC](./product/research/2026-10-21-multica-on-the-mac/README.md)):
GitHub issues worked by `.tool/queue`, and Multica issues worked by its
agent `lunna-mac` on the Mac, which opens PRs labelled `multica`. **An
issue lives in one of them, never both.** A Multica run follows
[.tool/multica-agent.md](./.tool/multica-agent.md); `.tool/multica` sets
it up, checks it and scores both
([scorecard](./product/research/2026-10-21-multica-on-the-mac/data/scorecard.md)).

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
flutter run --flavor lunnaDev --dart-define-from-file env/lunna.dev.json
flutter run -d chrome --web-port 5173 --dart-define-from-file env/lunna.dev.json
flutter test
(cd packages/l10n && flutter gen-l10n)   # after editing app_pt.arb (and app_en.arb); commit gen/
```

Migrations run on server boot (`migrateDatabase` in `main.ts`), so there is
no separate migrate step in deployment.
