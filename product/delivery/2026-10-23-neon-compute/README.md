# A minute tick keeps Neon awake all day: stop it

2026-10-23 · delivery · **plan, awaiting approval** · track: plan · issue #38

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

## Build brief

Phase 3 starts here; Phase 4 replaces this section with sections 3–5.

**Server**
- Fix `catchUp` (event-layout.service.ts ~L916): compute `over`/`begun`
  from the ends after `_revise`, keep the rest.
- New `events/catch-up.interceptor.ts`; bind it on the timeline, tasks,
  events, notifications, agent and artifacts controllers; drop the call in
  `timeline.controller.ts`.
- Delete `pause-ticker.service.ts`, its provider and the `watch` calls;
  fix the specs that construct it (events, artifacts, agent controller
  specs).
- `db.ts`: `on('error')` on the pool.
- Specs: the paused-an-hour-later read; a non-timeline route catching up.

**App**
- `_MinuteRefresh`: `AppLifecycleListener` (`onHide` cancels, `onShow`
  refreshes and reschedules), `clock.now()`; a widget test.

**Docs**
- `AGENTS.md`: the rule above; drop the minute tick from "A paused block
  owes its work". RFC header to *built*.
- Section 4 of this README: the Neon console checklist (max 0.25 CU,
  Neon Auth off, the CU-hours to read after a month, then Free).

**Open questions**: none.

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
