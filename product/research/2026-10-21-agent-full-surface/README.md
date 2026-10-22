# Lunna can do anything the person can: one registry of controls

2026-10-21 · RFC · proposed · Scope: `server/src/agent/`,
`app/packages/agent/`, a few rules moved out of controllers · Follows
[agent-ui](../2026-10-17-agent-ui/README.md) §5.6, which planned the
first writes and was never built

## In one minute

**Declare each control once, as a gesture that calls the same service its
route calls, and the agent can do it behind the plan card it already has;
then grow it one domain at a time, deliveries first.**

Today it reaches **6 of the 39 routes** a person drives
([code/coverage.mjs](./code/coverage.mjs)): add, place, hour, backlog and
swap tasks, add or move fixed blocks. No delivery, catalogue, goal,
routine or working day; no rename, tick off, delete, start or pause.

- **Do:** a gesture registry with undo by snapshot, so a new control is
  one entry instead of eight edits across server and app.
- **Do:** fill it domain by domain: deliveries (with catalogue and goals),
  then the task lifecycle, then routines, working day and navigation.
- **Do:** move the two rules that live in controllers into services, so
  the route and the agent share one path.
- **Not needed:** new tools or tool search: new abilities are gesture
  kinds inside `answer`, and the model keeps its 4 tools.
- **You decide:** whether "now" actions skip Aplicar (recommended: no);
  whether the agent may append to notes (recommended: yes, shown on the
  card); whether plans survive a restart (recommended: yes, before deletes
  ship).

## Ideas to keep

1. **"Agents fail on the steps that change things, not the ones that
   read."** [SABER](https://arxiv.org/html/2512.07850v1) (2025): on
   τ-bench, writes are 14–18% of an agent's steps, yet each wrong write
   cuts the odds of success by up to 92–96%. A wrong read cuts them by
   under 10%. *For us:* reads can be generous. Every write gesture gets
   its own dry run, its own refusals and its own eval case. *New.*
2. **"Bind the approval to the exact call."**
   [GateArena](https://neurips.cc/virtual/2026/168290) (Jiang, Quinzan,
   Bhatt, 2026): a confirmation token tied to the call's exact
   parameters cut irreversible harm from 37.5–60% to 2.5%. With the check
   moved into the tool handler, broken-protocol runs went from 91/400 to 0.
   *For us:* a plan id already binds Aplicar to the exact gestures the
   person saw. Every new control goes behind it, never behind a line in
   the prompt. *Deeper than* [Approval on the action](../concepts.md#approval-on-the-action).
3. **"One action, declared once, reached by every caller."** Android's
   [AppFunctions](https://developer.android.com/ai/appfunctions)
   (experimental): the app annotates `createTask` once, a schema is
   generated, and the OS lets agents call it over the app's own
   repository. *For us:* a gesture and a route call one service method, and
   a rule that lives in a controller is a rule the agent skips. *New.*
4. **"Tool count is a budget: spend it on kinds, not tools."**
   [RAG-MCP](https://arxiv.org/html/2505.03275v1) (2025): above 90%
   success with under ~30 tools, failures from 31–70 as descriptions
   overlap, failure dominating past ~100. Anthropic's
   [tool search](https://www.anthropic.com/engineering/advanced-tool-use)
   pays off past 10 tools or 10K tokens of definitions. *For us:* 4 tools
   and ~3.4K tokens of prompt and tools, so no tool search. But ~35
   gesture kinds in one enum can overlap the same way, so each kind
   needs a distinct verb. *Deeper than* [Fewer tools](../concepts.md#fewer-tools).

## The change

| # | Change | Fixes | Size |
|---|---|---|---|
| 1 | Gesture registry, snapshot undo, `revive` | eight edits per control; undo restores only the named card | M |
| 2 | Rules out of controllers | the agent would skip a check the route makes | S |
| 3 | Board and reads per domain | catalogue, goals, routines, delivered work: invisible | M |
| 4 | Deliveries, whole | the issue's ask: no delivery write at all | M |
| 5 | Task and block lifecycle | rename, length, done, remove, start, snooze, pause, extend | M |
| 6 | Routines, working day, navigation | the rest of the map | S–M |
| 7 | Evals per domain | 1 of 29 cases touches a delivery | S |

### 1. The registry

**What.** Today one gesture lives in eight places: the `do` enum
(`agent.prompt.ts:94`), the draft switch (`agent.service.ts:1452`), the
`Gesture` type (`plan.ts:54`), `make()` (`gestures.ts:73`), `Undo` and
`takeBack` (`plan.ts:87`, `gestures.ts:206`), `ChangeKind` and `_view`
(`plan.ts:9`, `agent.service.ts:1335`), and the app's `PlanChangeKind`.
Instead, one entry per control in `agent/actions/<domain>.ts`:

```ts
export const done: Action<{ ref: string }> = {
  name: 'done',                       // the enum value
  domain: 'task',
  args: { ref: REF },                 // JSON schema, merged into CHANGES
  resolve: (turn, args) => ({ id: turn.card(args.ref, { begun: 'ok' }).id }),
  make: (hands, user, { id }, trace, now) => hands.layout.doneTask(user, id, trace, now),
  line: (before, after, { id }) => ({ kind: 'done', id, title: before.title(id) }),
};
```

`resolve` turns refs and day words into ids and refuses in the model's
terms. `make` calls the **same service method the route calls**. `line`
is what the plan card draws.

**Undo by snapshot.** `keep()` (`gestures.ts:231`) notes only the card
named. `doneTask` also re-anchors the snapped run after it, and removing
a delivery deletes its backlog tasks, so undoing either would leave rows
moved. `make` diffs the stores before and after each gesture and writes
`restore` for each changed row and `revive` for each one gone. Each
store gains `revive(row)`: an insert with the row's own id, `ON CONFLICT
DO NOTHING`. This was agent-ui's §5.6 plan. It also fixes undo for
`shift` and `resize` when they come.

**`Hands` grows.** The sandbox (`gestures.ts:39`) seeds tasks and events
only. It adds a `MemoryArtifactStore` (it exists, `artifact.store.ts:71`)
and an `ArtifactsService` over the same hands. Routines already go
through `CalendarService` and `TaskStore`
(`routines.service.ts:26`), so they come for free.

**The app is half done.** `PlanChangeKind` already reads `edit`, `note`,
`done`, `remove` and three artifact kinds, and `plan_card.dart:133`
draws them (a delete: struck title, red bin), built for agent-ui's
phases 5b–7, which the server never shipped.

### 2. One path per rule

Two rules live in controllers, so a gesture calling the service would
skip them:

- `POST /tasks` checks the delivery exists (`tasks.controller.ts:121`),
  not `createTask`.
- `PATCH /users/me` writes the working day straight to the database
  (`users.controller.ts:57`), with no service at all.

Move both into services (`EventLayoutService.createTask`, a new
`UsersService.setWorkDay`). Then add a check to `coverage.mjs`: the
first call of every handler must be a service.

### 3. What the agent sees

The board stays the day. Everything else gets one index line and is
read on demand, the [just-in-time](../concepts.md#just-in-time-context)
pattern already used for deliveries:

| Domain | On the board (new) | `read_cards` gives |
|---|---|---|
| Deliveries | kind, time owed, value, and the 5 last delivered (`board.ts:479` shows open ones only) | as today, plus kind, minutes, value, blocks |
| Catalogue | `k1 · Mapa astral · Atendimentos · 1h30 · R$ 250` | — |
| Goals | `g1 · R$ 4.000/mês · 1.250 entregue, 2.000 na fila`; the month's need vs free | — |
| Routines | `r1 · Academia · dias úteis 07:00 · flexível` | its days ahead |
| Feitas | — | `read_done { text }`: the search `GET /tasks/done` makes |

That is new refs `k`, `g` and `r`, a line each, and one new read tool
or a `read_cards` mode. Recommended: a mode, which
keeps it at 4 tools.

### 4. Deliveries

| Gesture | By hand | Made with |
|---|---|---|
| `new_artifact { title, kind?, deadline?, minutes?, value?, at?, tasks? }` | + on Entregas, the catalogue sheet | `ArtifactsService.create`, then `addTask` each |
| `edit_artifact { ref, title?, deadline?, minutes?, value?, blocks? }` | the delivery's line | `ArtifactsService.edit` |
| `deliver { ref, open? }` | the ✓ on its page | `edit { done }` |
| `remove_artifact { ref }` | Apagar | `ArtifactsService.remove` |
| `move_artifact { ref, after?, before? }` | dragging the queue | `move { index }` |
| `new { …, artifact: p2 }` on any task gesture | + in Tarefas | `createTask { artifactId }` (`NewThing`, `plan.ts:34`, has no field for it) |
| `new_kind { name, shelf, minutes, price? }` | `TypeSheet` | `addType` |
| `new_goal`, `remove_goal` | `GoalSheet`, a long press | `addGoal`, `removeGoal` |

Two challenges. `ArtifactsService.create` returns nothing
(`artifacts.service.ts:141`), so "make a delivery Tese with three tasks"
cannot name the new one. It must return its id, and a plan needs
**forward refs**: `new_artifact` gets `as: "n1"` and later gestures say
`artifact: "n1"`. Kinds are named loosely ("um mapa" for *Mapa astral*),
so `resolve` matches them with the board's `alike()`, and two matches
become a doubt.

### 5. Task and block lifecycle

`edit` (title, length), `done`, `remove`, `start`, `snooze`, `pause`,
`resume`, `extend`, each over its `EventLayoutService` method
(`event-layout.service.ts:155–815`). Rules in `resolve`: nothing in the
past changes. A begun task can be renamed, ticked off, paused and
extended, but not resized. Removing a routine's day cancels it
(`event-layout.service.ts:611`), and the line says "folga hoje", not
"Apagar". **Starting while something runs is the one guard**
(`start_now`): it becomes a server doubt with the guard's two answers as
choices, so the agent never picks `solve_current` alone. `shift` and
`resize` wait: people say "empurra tudo 15 min" rarely, and `at_hour`
covers most of it.

### 6. Routines, working day, navigation

- `new_routine`, `edit_routine`, `remove_routine` over `RoutinesService`.
  Changing a routine deletes its days ahead, so these need snapshot undo
  (§1) before they ship.
- `work_day { start, end }` over the new `UsersService.setWorkDay`.
- **Navigation needs no server write.** An `open` block with a fixed
  list of places (a delivery, a task's page, Feitas, Rotina, Lista or
  Calendário on a day). It is drawn as a button, like *Abrir entrega* is
  today through `AgentLinks`. Opening a page is the person's tap, not a
  plan.

### 7. Evals

One eval case per gesture, graded on the state after Aplicar, plus
Desfazer leaving the state identical (`cases.ts` has 29 cases, and
`artifact-from-tempo` is the only one about a delivery). Run
`eval:agent` after each domain, since [SABER](#ideas-to-keep) says the
new writes are where the misses will be.

## Decisions for you

1. **"Now" actions (start, pause, done).** (a) Behind Aplicar like
   everything *(recommended)*: one more tap, and the same undo. (b)
   Applied at once when undoable. That is faster by voice, but it breaks
   "the person always decides" and needs its own undo chip.
2. **Notes.** (a) The agent appends, the card shows the text, Desfazer
   takes it back *(recommended)*: "anota isso na Tese" is the most
   natural voice request on a delivery. (b) Read only, as the spec says
   today (`agent.md`: "reads notes and never writes them").
3. **Plans after a restart.** (a) Persist plans and their undo in
   Postgres before deletes ship *(recommended)*: an undo lost to a deploy
   is a lost delivery. (b) Keep the in-memory `PlanStore` (`plan.ts:130`,
   2-hour TTL).
4. **Deletes asked once.** (a) A delete that takes more than 3 rows with
   it (a delivery's tasks) is a doubt first, "Apagar as 6" / "Só a
   entrega" *(recommended)*. (b) The plan card alone.
5. **Order.** (a) Deliveries before the lifecycle *(recommended, the
   issue's ask)*. (b) The lifecycle first: smaller, and the app already
   draws it.

## Decided unattended

- Scope is the 39 routes the person drives. Sign-in, the account, typing
  and dictation, link previews and the suggestion's "Agora não" are out:
  nothing a person asks the agent for.
- `shift` and `resize` are left for later (§5).
- Phase 4 (deep research) not run, as the queue asked. GateArena and SABER
  were read from their abstract page and HTML. RAG-MCP's thresholds are
  read from its figure, not a table.

## Deeper

### How it works today

```
POST /agent/turn → board (day, backlog, artifact index) → model
  read_timeline | read_conversations | read_cards     (reads run)
  answer { blocks } → _draft (refs→ids, refusals) → _rehearse on sandbox
    → plan card (ChangeKind: 5 kinds) ── Aplicar → make() on the real day
                                         Desfazer → takeBack(Undo: 4 kinds)
```

### The domain map

From [data/coverage.csv](./data/coverage.csv). *Reach* is what the agent
does today. *Effort* includes server, app line, copy and evals once the
registry exists.

| Domain | The person can | Agent reach | Missing | Effort | Hard part |
|---|---|---|---|---|---|
| Queue and hours | add, place, hour, backlog, swap, nudge, seam | all but nudge and seam | `shift`, `resize` | S | rarely spoken |
| Task lifecycle | rename, length, start, snooze, done, remove, pause, resume, extend | none | all | M | the guard; undo of the snapped run |
| Fixed blocks | add, hour, rename, length, done early, remove, pause, extend | add, hour | the rest | S | shares task code |
| Deliveries | create, edit, deliver, reopen, remove, reorder, add tasks | read open ones | every write; delivered ones unseen | M | no id back; forward refs; cascade |
| Catalogue | add a kind | none | read, add | S | loose names |
| Goals | add, remove, read progress | none | all | S | numbers are computed: server fills |
| Routines | create, edit, remove, a day off | sees days | list, CRUD | M | edits delete days ahead |
| Working day | set start and end | reads it | set | S | write lives in the controller |
| Feitas | search | via a delivery only | search | S | — |
| Navigation | tabs, Lista/Calendário, open a page | *Abrir entrega* | `open` | S | app only |

### Diagnosis

| # | Symptom | Root cause | Where |
|---|---|---|---|
| 1 | "Can't do anything with entregas" | no gesture writes an artifact; the index hides delivered ones | `gestures.ts:73`, `board.ts:479` |
| 2 | A task can't be made for a delivery | `NewThing` has no artifact | `plan.ts:34` |
| 3 | Adding a control is slow | one gesture in eight places | §1 |
| 4 | Undo would be wrong for writes that move others | undo restores the named card only | `gestures.ts:231` |
| 5 | Two code paths | delivery check and working-day write in controllers | `tasks.controller.ts:121`, `users.controller.ts:57` |
| 6 | The app shows rows the server never sends | agent-ui phases 5b–7 not built | `plan_card.dart:133` |
| 7 | A new delivery can't be followed by its tasks | `create` returns void | `artifacts.service.ts:141` |
| 8 | Writes untested on a real model | 1 of 29 eval cases touches a delivery | `evals/cases.ts` |

### The literature

- **SABER** (arXiv 2512.07850): deviations on writes, not reads, predict
  τ-bench failure. Its fix, confirmation gated to writes only, is what
  the plan card already is. *For us:* measure each new write.
- **GateArena** (NeurIPS 2026 workshop): confirmation must be enforced by
  the environment and bound to the call's parameters. *For us:* a plan is
  stored server-side with its gestures, and Aplicar makes exactly those,
  so it already passes. Keep it that way for deletes.
- **AppFunctions** (Android, experimental): one annotated function per
  action, a generated schema, the app's own repository behind it. *For
  us:* the registry is our version, and it could be exported as
  AppFunctions or MCP later without rewriting anything.
- **RAG-MCP** (arXiv 2505.03275): selection degrades as options overlap
  and grow. *For us:* keep the enum's verbs distinct and the args per
  kind few. If pass^k drops as kinds grow, list only the domain's kinds
  for a page (`about`) before reaching for retrieval.
- **Anthropic, advanced tool use**: tool search above 10 tools or 10K
  tokens, and 1–5 input examples per tool (72%→90% on complex
  parameters). *For us:* an example per new gesture kind in the schema
  description may be cheaper than prose rules.

### Rollout

| Phase | Ships | Fixes | Size |
|---|---|---|---|
| 0 | `coverage.mjs` (done); eval cases for each domain, failing | measuring | S |
| 1 | registry over today's 5 gestures, snapshot undo, `revive`, rules out of controllers; no behaviour change, evals green | 3, 4, 5 | M |
| 2 | deliveries, catalogue and goals: reads and writes, forward refs | 1, 2, 7 | M |
| 3 | task and block lifecycle; the guard as a doubt | 6 | M |
| 4 | routines, working day, `open`; plans persisted | the map | M |

Each phase ends with `eval:agent` and `node code/coverage.mjs`.

## References

- [SABER](https://arxiv.org/html/2512.07850v1): writes are 14–18% of
  steps and drive failure (odds ratio 0.04 vs 0.81).
- [GateArena](https://neurips.cc/virtual/2026/168290): parameter-bound
  confirmation, harm 37.5–60% → 2.5%.
- [AppFunctions](https://developer.android.com/ai/appfunctions): actions
  declared once for agents, over the app's own code.
- [RAG-MCP](https://arxiv.org/html/2505.03275v1): >90% success under ~30
  tools, failure past ~100.
- [Anthropic, advanced tool use](https://www.anthropic.com/engineering/advanced-tool-use):
  tool search thresholds; input examples 72%→90%.
- [agent-ui RFC §5.6](../2026-10-17-agent-ui/README.md): the first plan
  for writes and snapshot undo, reused here.
