# Agent Notes

## Project

Lunna is a personal day planner with two parts:

1. **Flutter app** in `app/`: iOS, Android and web.
2. **NestJS backend** in `server/`: REST API, Better Auth, Postgres.

Each build is one of two brands, Focus or Lunna (see below).

It started as a copy of Focus with the AI agent, the conversations, the
untimed "things" list and Google Calendar taken out. What is left is the
timeline and its calendar dynamics, the routines, the reminders, and the
design system, plus a smaller agent of its own (see "The agent").

### Two brands

The same code builds two apps with the same features: **Focus** (dark,
lime, `focus.pietroteruya.dev`, `com.pietroid.focus`) and **Lunna** (light,
red, the crescent mark, `lunna.pietroteruya.dev`, `com.pietroid.lunna`).
They share one backend and one database.

- The `BRAND` define (`focus`|`lunna`, in `app/env/<brand>.<env>.json`)
  is read once by `AppBrand` in `app_ui`. Every `AppColors` token is a
  constant chosen by it, so screens never branch on the brand: give them a
  token, and if a brand needs a value the other does not, add a token
  (`freeEdge`, `shadow`). Typography, spacing and radii are shared.
- A build without `BRAND` is Focus, so tests run against Focus by default;
  CI runs them under both (`flutter test --dart-define=BRAND=lunna`).
- Strings that name the app select on `AppBrand.id`
  (`context.l10n.appName(AppBrand.id)`); Portuguese says "o Focus" but
  "a Lunna".
- Native: flavors `focusDev`, `focusProduction`, `lunnaDev`,
  `lunnaProduction`. Icons and splash come from `app/brands/`
  ([app/brands/README.md](./app/brands/README.md)). The web build is
  branded after the fact by `app/tool/brand_web.sh`.
- The server knows no brand in its data: one user table, one database, so
  the same Google account is the same person in both apps (and people can
  share things later). `BETTER_AUTH_URL` lists both origins and Better Auth
  answers each request on its own host.
- Each brand is its own Google Cloud project, so Google's consent screen
  names it. Lunna's web redirect is the `google` provider; Focus's is
  `google-focus` (generic OAuth, `FOCUS_GOOGLE_CLIENT_ID`), picked by the
  app's `GOOGLE_WEB_PROVIDER` define. Phones of both brands post ID tokens
  to `google`, which accepts every client listed in `GOOGLE_CLIENT_IDS`.
  Account linking joins a verified email to the user it already has.

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
- **Deploy:** three ARM64 images on GHCR (`lunna-backend`, `lunna-web`,
  `focus-web`), pulled by a Raspberry Pi over SSH through a Cloudflare
  tunnel. See [SETUP.md](./SETUP.md) and [MIGRATION.md](./MIGRATION.md).

## Layout

```
app/
  brands/               per-brand icons, splash and web assets (+ README)
  env/                  <brand>.<env>.json defines (examples committed)
  tool/brand_web.sh     stamps a brand on a web build
  lib/                  shell, home (Tempo), routines page, landing + demo
                        (the signed-out page, the app on fakes),
                        links (the real LinkPreviews)
  packages/
    agent/              the agent: ask bar, sheet, the answer's surface
                        (decoder, peeks, plan card), suggestion, voice
    analytics/          PostHog behind one seam (Analytics, NoAnalytics)
    api_client/         Dio + bearer token interceptor
    app_ui/             the design system: AppBrand, theme, tokens, widgets
    auth/               Better Auth client: Google sign-in, token store
    l10n/               every user-facing string (pt-BR)
    notifications/      local reminder queue + background refresh
    artifacts/          Entregas: goals, queue, catalogue, sheets, the delivery's page
    timeline/           the day: bloc, repositories, timeline list, event page
server/
  src/
    agent/              the agent: OpenRouter client, tools, the board
                        (refs, dates, artifacts), actions/ (the registry:
                        one Action per verb), the answer and its A2UI
                        (answer.ts, speech.ts), gestures and the dry run, plans,
                        conversations (ConversationStore), plans
                        (PlanStore), evals/
    analytics/          PostHog: the provider, the route → event table
    auth/               Better Auth instance + SessionGuard
    calendar/           CalendarService (cache) over CalendarStore (Postgres)
    db/                 Drizzle schema + pool + boot-time migrations
    events/             the timeline routes, the read model, the layout rules
    links/              link previews: the guarded page fetcher, the image proxy
    tasks/              TaskStore (Postgres) over the task table
    notifications/      the reminder plan, derived from the calendar
    artifacts/          ArtifactStore (+ its module): deliveries, catalogue, goals, the schedule
    routines/           routine CRUD and day expansion
    time/               work hours, zones, the scheduler
  drizzle/              generated SQL migrations (committed)
  tool/coverage.mjs     which routes the agent reaches; every handler hands to a service
deploy/                 docker-compose.yml, nginx.conf, web.Dockerfile
product/
  spec/                 feature specs moved out of this file (agent, artifacts)
  delivery/             one folder per delivered feature: prompt, design, notes
  improvements/         one folder per /improve run: what changed, evidence, references
  research/             one folder per topic: the RFC (README.md, a deck), img/, data/, code/, reports/;
                        concepts.md, the ideas every RFC taught
.tool/                  internal tools: check (CI on what changed), preview (prints),
                        cost (session tokens), doc (open/annotate Markdown,
                        check an RFC's slides, print them),
                        queue (GitHub issues worked unattended, gate by gate),
                        multica (the second queue on the Mac: setup, check, score),
                        review.html (a PR's README on Pages, commented on by selection)
```

## Auth

Better Auth runs inside the Nest server, mounted at `/api/auth/*` in
`main.ts` ahead of Nest's body parser (it reads the raw request itself).
Everything else under `/api` is Nest, protected by `SessionGuard`, which asks
Better Auth for the session behind the request and puts an `AuthUser` on it.

Google is the only way in, by two roads:

- **Web:** the OAuth redirect. `POST /api/auth/sign-in/social` (provider
  `google` on Lunna, `google-focus` on Focus) answers with Google's URL, the
  browser leaves, comes back to `/`, and from then on sends the session
  cookie. The web app is served from the same origin as the API,
  so the cookie needs no CORS.
- **iOS/Android:** the native `google_sign_in` SDK produces an ID token
  (minted for the brand's web client, via `serverClientId`), the app posts
  it to the same route as provider `google`, and the server verifies it against `GOOGLE_CLIENT_IDS` and
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

A task's notes and a delivery's have the agent's bar at their foot, and
beside it a microphone that **dictates**: plain speech to text, straight
into the notes, each recording a paragraph of its own (at the cursor while
typing), saved like typing.
The bar's own microphone still asks the agent, which then knows the page
it was opened on (`about`). See "Dictation" in
[product/spec/agent.md](./product/spec/agent.md).

A link on a line of its own in the notes is drawn as a **link card**
(picture, title, site; a tap opens the browser). **The notes stay text**:
the card is the URL on its own line, and pages read and write
`LiveTextController.notes`, never `.text`. The server reads each link's
page once, for everyone (`link_preview`), never from an address that is
not public, and proxies the pictures for the web. See
[product/spec/links.md](./product/spec/links.md).

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
everything the calendar draws from now to the end of day N. A task of a
delivery carries `artifact: { id, title }` in all three, and Lista and the
event page name it (`AppTag`). Every write
under `/api/tasks` and `/api/events` takes the same `?days=` and answers
with the same shape.

## The timeline

The app draws the day two ways, switched at the top of Tempo and
remembered on the device (`TimelineModeCubit`):

- **Lista**: the tasks alone, each as tall as it needs, in two stages that
  are always drawn: **Fazer em breve** (every task with an hour, in one run
  with no day headings, except the days of routines: those are drawn on the
  calendar only, and come into the list once their hour has come or they
  are running; `inList`, which is also what a drop's `index` counts) and **Depois eu priorizo** (the backlog), each
  headed like a day of the calendar. A drag moves a
  task within either or across the line; the move carries `backlog: true`
  when it lands below it. A running task dropped in the backlog stops. Each
  stage ends in a **+** that writes something down at its end.
- **Calendário**: everything, to scale, day after day. Scrolling near the
  end asks for another week (`TimelineExtended`), up to 120 days. **Agora**
  is always drawn, the break with its line whenever nothing runs, and a
  task let go on it is begun. A card tall enough for a second line (72 px
  drawn) shows its delivery and the start of its notes under the title
  (`notesPreview`, up to 3 lines); a shorter one shows no notes at all and
  marks a delivery's task with the stack. A card is never taller for it. Every free stretch carries a small **+**
  and its hours, both stuck to the top of the part of it in sight (placed
  while painting, so they never lag the scroll); the hours run from the
  first one in sight, which is where the + writes.

  A drag on the calendar starts as a **nudge**: under 30 minutes of travel
  a task keeps its place and slides in time, five minutes at a time, and
  the run snapped to its end slides with it (`POST /tasks/:id/shift`).
  Past 30 minutes it is looking for somewhere else, and stays so: let go
  on another task that has not begun, the two **swap** (`POST
  /tasks/:id/swap { with }`): each takes the other's turn in the queue or
  its hour, so only what is between them moves, by the difference in
  length; on a heading or in the gap between two cards it takes that
  place; in free room, that hour. Held on its bottom
  edge, a card's **seam** comes up: the block above takes the new length,
  the snapped run below slides along keeping its own, and a block that is
  not snapped is left alone (`POST /tasks|events/:id/resize`). A drop at
  the top of a day asks for that day's first hour (`after`), since a place
  in the queue would pack the task back into what is left of the day
  before. While the running task is carried off Agora, Agora draws the
  break ("Agora fica livre") and the card says it is being paused. Outside
  the working day Agora is `DayOverTile`: nothing begins, a drop on it is
  refused, and it offers the Menu's hours.

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

**Nothing begins outside the working day.** Starting a task, or a drop
with `start: true`, before the day opens or after it ends is refused in
Portuguese (`refuseOutsideWorkDay`), and the queue never waits at the
current minute then: its first task is the next day's.

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
`POST /tasks/timing`:

| Answer | What happens |
|--------|--------------|
| `solve_current` | the running block is finished and gives its hour away |
| `postpone_current` | a running task goes back in the queue, next after this one; a fixed block stays, and the task waits for it |

### The app shell

Three tabs: **Tempo** (the timeline), **Entregas** (see below) and
**Menu**, which opens Rotina and **Feitas** and sets when the day starts
and ends. The `AppFab` (a `+`) writes down whatever the tab in front is
about: on Entregas a delivery, anywhere else something on the day Tempo is
showing (from Menu it brings Tempo forward). It sits in the same spot on
every tab and never animates between them (`noAnimation`). The
greeting at the top of Tempo is the account menu: **Rotina** and **Sair**.

**Feitas** (`/feitas`, `DoneArchivePage` over `DoneArchiveCubit`) is every
task ticked off, newest first under the calendar's day headings, searched
on the server: `GET /api/tasks/done?q=&limit=&before=&beforeId=` answers
`{ done: [card] }`, each card's `startTime` being its `doneAt`, paged by
the last one's `doneAt` and id. A tap opens `EventPage(finished:)`. A task
is ticked off only on Tempo (the running card's ✓, or carried right in
Lista); its page has no done control.

### Entregas (artifacts)

Projetos is gone: a project is now a **delivery** (*entrega*; `Artifact` in
code), something owed by a day, with an optional kind from the person's
**catalogue** (shelves and kinds, empty until they fill it), a total time,
a value and how the day may cut it. The open ones are a queue of their
own, under the **goals** (money delivered, or a count of one kind, per week
or month) and a line setting the time the month's deliveries owe against
the agenda's free hours. A delivery's tasks are ordinary tasks on the day
(`task.artifact_id`), and its Tarefas is Tempo's Lista kept to them
(`TimelineList(only:, done:)`). **Money counts when a delivery is
delivered** (`done_at`). The routes and the rules are in
[product/spec/artifacts.md](./product/spec/artifacts.md): read it before
touching `server/src/artifacts/` or `app/packages/artifacts/`.

### Reminders

`notifications.service.ts` plans them from the day for the next days. Only
the **next** task (the earliest, anchored or not) gets a reminder, a `confirmStart` at its hour that asks
rather than announces; tapping it opens *Começar agora* / *Esperar 15 min*.
Every other task's hour moves too often to be worth one. Events get a plain
`starting` reminder. An item's `eventId` is the id of the card a tap opens:
the task's for a task. The phone mirrors the
plan into local notifications, so reminders arrive without push or network.

### The agent

It reads the day and proposes changes to it: **reads run, writes are only
ever proposed**, the user applies a plan whole, the server makes it through
`EventLayoutService` and can undo it. **Every change the agent proposes is a
gesture the person could have made by hand** (a place in the queue, an
hour, the backlog, a swap), and leaves the day as that gesture would: the
model names cards by short refs and days as said, the server resolves
them, runs the plan on a sandbox copy of the day, and asks the doubts it
can see itself. Voice becomes text on the phone and reaches the server as
an ordinary turn. **The model answers with one `answer` tool whose blocks
name what to show (plan, choices, day, cards, artifact); the server fills
every fact and sends one A2UI v0.9 surface (`ui`)**, and nothing the
person reads carries a ref (`speakable`). **Each verb is one `Action` in
`agent/actions/`** (args, resolve, make through the same service the
button calls, the card's line); the schema, the dry run, Aplicar and the
card all read the registry, and Desfazer restores a snapshot of the rows
the plan touched, so a new control is one entry. Today it moves cards on
the day and makes, edits, delivers, moves and deletes deliveries, kinds
and goals; plans are kept in Postgres. Agent changes are measured with `npm run eval:agent`
(real model, costs money, never in CI). The tools, the plan rules, the
routes, the conversations and voice are in
[product/spec/agent.md](./product/spec/agent.md): read it before touching
`server/src/agent/` or `app/packages/agent/`.

### The landing page

Signed out, the app is `LandingPage` (`app/lib/landing/`): the agent, Tempo
and Entregas as three chapters beside a phone running the real app on
fakes (`app/lib/demo/`), or on a narrow screen each chapter's piece of it.
**The demo never reaches a server**, and while it is up **the app's clock
reads 10:00** (`DemoClock`, wrapped around the app in `main.dart`), so
code there reads `clock.now()`, never `DateTime.now()`. See
[product/spec/landing.md](./product/spec/landing.md).

## Analytics

PostHog (US cloud, one project for both brands) hears of each write that
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
flutter run --flavor focusDev --dart-define-from-file env/focus.dev.json
flutter run -d chrome --web-port 5173 --dart-define-from-file env/lunna.dev.json
flutter test --dart-define=BRAND=lunna     # tests default to Focus
(cd packages/l10n && flutter gen-l10n)   # after editing app_pt.arb; commit gen/
```

Migrations run on server boot (`migrateDatabase` in `main.ts`), so there is
no separate migrate step in deployment.
