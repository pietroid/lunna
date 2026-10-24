# A minute tick keeps Neon awake all day: stop it

2026-10-23 · delivery · **built** · track: plan · issue #38

## 1. The prompt

From [issue #38](https://github.com/pietroid/lunna/issues/38):

> **Implement: A minute tick keeps Neon awake all day, for two people**
>
> Build what the RFC [product/research/2026-10-23-neon-compute/README.md](https://github.com/pietroid/lunna/blob/main/product/research/2026-10-23-neon-compute/README.md) recommends, approved in #35 and merged in #36.
>
> - Read it as the research (see "From an RFC" in the /create skill): what it recommends, in its priority order, and its Rollout are the spec.
> - A `> **Decision**` note in it is binding; every other decision takes the option marked *(recommended)*.
> - The plan (or the board, if it changes what the person sees) says which rollout phases this PR ships, Phase 0 first.

The research is the RFC
[product/research/2026-10-23-neon-compute](../../research/2026-10-23-neon-compute/README.md).
It has no binding `> **Decision**` note, so every decision takes its
recommended option: **delete** the minute tick and catch up on read,
**pause** the app's refresh while hidden, cap compute at **0.25 CU**, stay
on **Launch one month, then Free** if under 50 CU-h, and keep a paused
block's end **written on read** by a fixed `catchUp`.

## 2. The plan

Nothing the person sees changes (Tempo still turns over each minute while
it is in front), so this is the plan track: no board.

### What this PR ships

The RFC has no Rollout section; its three changes, in its order, are the
phases.

| Phase | What | Ships here |
|---|---|---|
| 0 | Measure: re-run the RFC's `count-queries.ts` and `tick-vs-read.ts` against the build | yes |
| 1 | Server: fix `catchUp`, run it before every route that reads the day, delete `PauseTickerService` | yes |
| 2 | App: no minute refresh while Tempo is hidden, one refresh on return | yes |
| 3 | Neon console: max 0.25 CU, Neon Auth off; after a month, Free if under 50 CU-h | no: a checklist for the person (section 4) |

### Approach

- **The fix** (`events/event-layout.service.ts`, `catchUp`): judge a begun
  task "over" by the end it has *after* the paused block is moved, not by
  the list read before the move. A spec reads a day with a task paused at
  09:20 an hour later and finds it still paused, not done.
- **Catch up on read** (`events/catch-up.interceptor.ts`, new): a Nest
  interceptor that runs `layout.catchUp(user, trace)` before the handler,
  bound with `@UseInterceptors` on every controller that reads the day:
  timeline, tasks, events, notifications, agent, artifacts. It replaces
  the explicit call in `timeline.controller.ts:41`. Links, routines and
  users don't read the day and stay without it.
- **Delete** `events/pause-ticker.service.ts`, its provider in
  `events.module.ts` and the three `ticker.watch(who)` calls; the specs that
  build it drop it.
- **The pool** (`db/db.ts`): `pool.on('error', …)` logs instead of letting
  an idle connection Neon dropped while asleep crash the process.
- **App** (`app/lib/home/view/home_page.dart`, `_MinuteRefresh`): an
  `AppLifecycleListener` cancels the timer on `onHide` and, on `onShow`,
  refreshes once and schedules the next minute boundary. Its clock becomes
  `clock.now()` (the demo's rule).
- **Docs**: `AGENTS.md` loses "and on the server's minute tick" and gains
  the rule (below); the RFC's status moves to *built*.

The rule that goes into `AGENTS.md`: **nothing on the server runs on a
timer that touches Postgres.** Whatever changes with the clock is stored
as when it happened and settled on the next read (`catchUp`), so Neon can
sleep after 5 quiet minutes.

### References

- [NestJS, Interceptors](https://docs.nestjs.com/interceptors): code
  before `next.handle()` runs before the handler; `@UseInterceptors()` on
  a class "attaches the interceptor to every handler declared by this
  controller".
- [NestJS, Request lifecycle](https://docs.nestjs.com/faq/request-lifecycle):
  guards run before interceptors, so `SessionGuard` has put the `AuthUser`
  on the request by then.
- [Flutter, `AppLifecycleListener`](https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html):
  `onHide` "when the application is hidden", `onShow` "when the
  application is shown". Its page doesn't say how web maps to it; the RFC
  marks that "to confirm on the build", and Phase 0 does.
- [Neon, Scale to zero](https://neon.com/docs/introduction/scale-to-zero):
  compute "scales to zero after an inactive period of 5 minutes", wakes
  in a few hundred ms, and on Free "this setting is fixed".

### Decisions

| # | Decision | Chosen | Why |
|---|---|---|---|
| 1 | The minute tick | delete; `catchUp` on read | RFC, recommended: no screen shows a day nobody read |
| 2 | Where catch-up runs | one interceptor, per controller | RFC Change 1; a controller added later opts in with one decorator |
| 3 | Skip a second `catchUp` in the same minute | no memo | RFC: "fewer queries per read" not needed; a memo is state that can go wrong when a write lands mid-minute |
| 4 | A paused block's end | written on read by the fixed `catchUp` | RFC, recommended: not storing it touches every reader of `endTime` |
| 5 | Hidden app | pause the refresh, refresh at once on return | RFC, recommended: one open tab is ~113 CU-h a month |
| 6 | Phone's 6-hourly background refresh | kept | RFC: 4 wake-ups a day |
| 7 | Neon console (cap, Neon Auth, plan) | left to the person, as a checklist | not reachable from here; no code |

### How it will be proved

- `npm test` in `server/`: the new `catchUp` spec (paused at 09:20, read
  at 10:20: still paused, end 10:20 + owed) fails before the fix and
  passes after; the existing end-to-end timeline specs pass with no tick.
- An interceptor spec: a `GET /api/notifications` on a paused day,
  without a timeline read first, answers with the moved end.
- The RFC's scripts, re-run from `server/`
  (`NODE_PATH=$PWD/node_modules npx tsx …`): `count-queries.ts` prints
  **0** statements for a day with nobody reading (5,761 today);
  `tick-vs-read.ts` prints 28 of 28 reads equal to the tick's.
- `flutter test` for a widget test of `_MinuteRefresh` (hidden: no
  refresh at the minute; shown: one refresh at once), under both brands;
  `.tool/check` on the whole change.
- On the web build, by hand: hide the tab, watch the network panel stay
  quiet past a minute, come back and see one `GET /api/timeline`.

## 3. What was built

Nothing the person sees changed, so there are no prints: the proof is the
runs below.

### The contract

**Nothing on the server runs on a timer that touches Postgres.** What
changes with the clock (a paused block's end, a task whose hour ran out, a
routine's day nobody began) is stored as when it happened and settled by
`catchUp` on that person's next request, before the handler reads or
writes the day. The app asks for the day each minute only while it is in
sight. So with nobody looking, Neon sees nothing and sleeps after 5
minutes.

### The proof

**1. A day with nobody reading sends nothing.**
[`code/idle-day.ts`](code/idle-day.ts) boots the server's own feature
modules (everything in `AppModule` but auth and analytics) over PGlite
with every timer faked, lets 24 hours pass, then pauses a task at 09:20
and reads the day at 10:20:

```
$ cd server && NODE_PATH=$PWD/node_modules npx ts-node --transpile-only -P tsconfig.json ../product/delivery/2026-10-23-neon-compute/code/idle-day.ts
{
  "timersAfterInit": 0,
  "statementsInAnIdleDay": 0,
  "statementsInAPausedQuietHour": 0,
  "statementsInTheFirstReadAfter": 6,
  "readAt": "10:20",
  "pausedTask": { "paused": true, "start": "09:00", "end": "10:45" }
}
```

The RFC measured **5,761** statements for the same idle day before
(`data/queries.json` there). Its `count-queries.ts` drove
`PauseTickerService` by hand and can't run now that the class is gone,
hence this script. Nothing in `server/src` outside the specs calls
`setInterval` or `setTimeout` any more (`grep` finds none).

**2. Catching up on read gives the same day as the tick.** The RFC's own
[`tick-vs-read.ts`](../../research/2026-10-23-neon-compute/code/tick-vs-read.ts),
unchanged, against the build (output in
[`data/tick-vs-read.json`](data/tick-vs-read.json)):

| | RFC, before | This build |
|---|---|---|
| reads (every 30 min, 09:30 to 23:00) | 28 | 28 |
| read equal to the tick's | **1** | **28** |
| rows written after setup, tick / read | 1,647 / 64 | 1,647 / 63 |

The tick world still writes 1,647 rows because the script ticks
`catchUp` by hand; the server no longer does.

**3. The bug the tick hid, as a spec.** "is still paused when read long
after its hour would have run out" (`events.controller.spec.ts`): begun at
10:00, paused at 10:10, read at 11:10. Against `HEAD`'s
`event-layout.service.ts` it fails (the task is taken for done at 10:30 and
leaves the list); with the fix it is still paused, ending 11:30.

### Server

| File | What |
|---|---|
| `events/event-layout.service.ts` | `catchUp` judges "over" and "begun" by each block's end *after* a paused one is moved (`_revise` returns the saved row) |
| `events/catch-up.interceptor.ts` (new) | `CatchUpInterceptor`: `catchUp(owner(user))`, then the handler |
| `events/{timeline,tasks,events}.controller.ts`, `notifications/…controller.ts`, `agent/agent.controller.ts`, `artifacts/artifacts.controller.ts` | `@UseInterceptors(CatchUpInterceptor)`; the timeline's explicit call and the three `ticker.watch` calls are gone |
| `events/pause-ticker.service.ts` | deleted, with its provider in `events.module.ts` and in three specs |
| `db/db.ts` | `pool.on('error')` logs a lost idle connection instead of ending the process |

No route, no env var, no migration changed.

### App

- `lib/home/view/minute_refresh.dart` (new, out of `home_page.dart`):
  `MinuteRefresh(onRefresh:)`. An `AppLifecycleListener` cancels the timer
  `onHide` and, `onShow`, refreshes at once and goes back to the minute
  boundary. Its clock is `clock.now()`. The guard check (no refresh under
  an open `GuardSheet`) stays in `home_page.dart`, as `_Threads._refresh`.

### Tests

- Server: 2 new specs in `events.controller.spec.ts` (the paused-an-hour
  read; `GET /notifications/schedule`, with no timeline read, moves the
  paused end in the store). The rest pass unchanged with no tick.
- App: `test/home/minute_refresh_test.dart`, 4 tests (on the boundary, not
  a minute from now; nothing while hidden; once at once on return, then the
  boundary; nothing after dispose), under both brands by `.tool/check`.
- `npm test` in `server/`: **335 tests in 24 suites, all passing**.
- `.tool/check` on the whole change: app-analyze, server-eslint,
  server-tsc and server-test all pass. It runs the packages' tests, not
  the root app's, so `test/home` and `test/app` were run by hand under
  both brands: 7 of 7 each. No flaky test seen.

### Where the build differs from the plan

- **The minute refresh moved to its own file** and became public
  (`MinuteRefresh`), so a widget test can pump it without the home page.
- **Phase 0's scripts:** `count-queries.ts` can't run against the build
  (it imports the deleted ticker), so `code/idle-day.ts` measures the same
  idle day through the real modules instead. `tick-vs-read.ts` ran as is.
- **The web check by hand was not run**: no browser here. Flutter's docs
  don't say how the web maps tab visibility to `onHide`/`onShow`; the
  widget test proves the widget's side. To see it: section 4.
- Comments that named the minute tick (`timeline.service.ts`,
  `analytics.ts`, `product/spec/analytics.md`) now name `catchUp`.

## 4. How to turn it on

Nothing to set: deploying the image is the change. No env var, no
migration.

**The Neon console, by hand** (Phase 3, not reachable from here):

1. Branch `main` → compute → autoscaling **max 0.25 CU** (min 0.25), and
   scale to zero left at its default, **5 minutes**.
2. Project settings: check that **Neon Auth is off** (we use Better Auth);
   it polls on its own and would keep the compute up.
3. In a month (around 2026-11-23), read the month's **CU-hours** on
   Billing. Under **50**, move to **Free** (100 a month); over it, stay on
   Launch and look at who is reading.

**To see the app's side on the web:** open the app, open the network panel,
switch to another tab for over a minute: no `GET /api/timeline` meanwhile.
Come back: one at once, then one per minute.

Without the console steps the code still lets the compute sleep; the cap
only keeps a spike from billing more.

## 5. Cost and time

Measured by the queue: see the pull request.

## Decided unattended

- Plan track: nothing the person sees changes.
- No rollout in the RFC: its three changes are the phases; Phases 0–2 ship
  here, Phase 3 (the Neon console) is the person's.
- No per-minute memo on `catchUp` (decision 3).
- The interceptor's routes: the six controllers that read the day; links,
  routines and users left out.
- The pool's `on('error')` is in, as the RFC's "cheap insurance".
- Cost and time: left to the queue, which measures every run and writes the
  figures in the PR.
- Build: the refresh became a public `MinuteRefresh` in its own file, to
  be testable on its own.
- Build: Phase 0 measured through a new `code/idle-day.ts`, since the RFC's
  `count-queries.ts` imports the deleted ticker.
- Build: the hand check on the web was left to the person (section 4).
