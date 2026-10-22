# Lunna can do anything the person can: one registry of controls

2026-10-22 · delivery · **draft: plan for approval** · Track: **plan** ·
RFC: [agent-full-surface](../../research/2026-10-21-agent-full-surface/README.md)
(approved in #20, merged in #22) · Issue: #26

## 1. The prompt

> Implement: Lunna can do anything the person can: one registry of controls
>
> Build what the RFC [product/research/2026-10-21-agent-full-surface/README.md](https://github.com/pietroid/lunna/blob/main/product/research/2026-10-21-agent-full-surface/README.md) recommends, approved in #20 and merged in #22.
>
> - Read it as the research (see "From an RFC" in the /create skill): what it recommends, in its priority order, and its Rollout are the spec.
> - A `> **Decision**` note in it is binding; every other decision takes the option marked *(recommended)*.
> - The plan (or the board, if it changes what the person sees) says which rollout phases this PR ships, Phase 0 first.

## 2. The plan

**This PR ships the RFC's Phases 0, 1 and 2**: the failing eval cases,
the registry with snapshot undo under today's five gestures, and then
deliveries, catalogue and goals on top of it. Phases 3 (task and block
lifecycle) and 4 (routines, working day, `open`, persisted plans) are
the next PRs, each one domain, as the RFC's rollout says.

Why the plan track: Phases 0 and 1 change nothing anyone sees, and the
one screen Phase 2 touches, the plan card, already draws the artifact
kinds (`PlanChangeKind.addArtifact` and its siblings in
`app/packages/agent/lib/src/models.dart`, drawn by `plan_card.dart`).
There is no layout to approve; Phase 4 of the build shoots the card.

### Approach

1. **Phase 0, the measuring.** In `server/src/agent/evals/cases.ts`, one
   case per Phase 2 verb, each built around the trap in the RFC's
   *Writes, verb by verb* (a delivery twice, delivering with open tasks,
   a task for the wrong delivery, a kind named loosely, a goal amount not
   said, a delete that takes 6 tasks). `World` learns `kind()` and
   `goal()`, `State` learns `artifacts` (title, done, deadline, value, its
   tasks). Plus an **undo check** in `run.ts` for every case with a plan:
   Desfazer must leave the state identical to the setup. They fail on
   `main`; `coverage.mjs` moves into `server/tool/coverage.mjs` with a
   new check that each handler's first call is a service.
2. **Phase 1, the registry, no behaviour change.**
   `server/src/agent/actions/` holds one `Action` per verb (`name`,
   `domain`, `args` as JSON schema, `resolve`, `make`, `line`) in a file
   per domain (`queue.ts` today's five: `place`, `at_hour`,
   `first_free`, `to_backlog`, `swap`) and an `index.ts` registry. The
   `do` enum and `CHANGES` schema (`agent.prompt.ts`), the `_draft`
   switch and `_view` (`agent.service.ts`), `make` (`gestures.ts`) and
   `ChangeKind` (`plan.ts`) are all read from it. **Undo by snapshot**:
   `make` diffs the hands' stores before and after a gesture and writes
   `restore` for each changed row and `revive` for each one gone;
   `TaskStore`, `CalendarStore` and `ArtifactStore` gain `revive(row)`
   (insert with its own id, `ON CONFLICT DO NOTHING`), Pg and Memory.
   **Rules out of controllers**: the delivery check moves from
   `events/tasks.controller.ts` into `EventLayoutService.createTask`; the
   working-day write moves from `users/users.controller.ts` into a new
   `UsersService.setWorkDay`.
3. **Phase 1, the schema shape (decision 6).** The registry builds both
   shapes: `anyOf` with one variant per verb (each with only its own
   arguments) and today's flat item. `AGENT_SCHEMA=flat|variants` picks
   one; `eval:agent` runs both once and keeps `variants` unless it scores
   lower. The default ships as the winner.
4. **Phase 2, deliveries, catalogue and goals.** Board lines for kind,
   time owed, value and the 5 last delivered, and index lines for kinds
   (`k1`) and goals (`g1`) (`board.ts`). `Hands` gains a
   `MemoryArtifactStore` and an `ArtifactsService`. `actions/artifacts.ts`:
   `new_artifact` (with `as` for forward refs), `edit_artifact`,
   `deliver`, `remove_artifact`, `move_artifact`, `new_kind`, `new_goal`,
   `remove_goal`, and `artifact` on `new` for every task gesture.
   `ArtifactsService.create` returns the new id. The plan card gets the
   lines it lacks (`deliver`, kinds, goals) in `PlanChangeKind` and
   `app_pt.arb`.

### References

- [Claude structured outputs, JSON Schema limits](https://platform.claude.com/docs/en/docs/build-with-claude/structured-outputs):
  "`anyOf` and `allOf` (with limitations: `allOf` with `$ref` not
  supported)"; `additionalProperties` must be `false`. So the `variants`
  shape uses `anyOf` (never `oneOf`, not listed) with no `$ref`.
- [OpenRouter, tool calling](https://openrouter.ai/docs/guides/features/tool-calling):
  tools are an OpenAI-compatible JSON spec, "OpenRouter standardizes the
  tool calling interface across models and providers"; it does not
  promise how each provider reads `anyOf`, which is why Phase 1 measures
  both shapes on the real model instead of assuming.
- [Drizzle, `onConflictDoNothing`](https://orm.drizzle.team/docs/insert#on-conflict-do-nothing):
  what `revive` is written with, as routines' days already are.
- The RFC's own sources (SABER, GateArena, RAG-MCP) stand as cited there.

### Decisions

| # | Decision | Chosen | Why |
|---|---|---|---|
| 1 | Phases in this PR | 0, 1 and 2 | 0 alone measures nothing new and 1 alone changes nothing; 2 is the issue's ask (deliveries) and proves the registry carries a new domain |
| 2 | "Now" actions | behind Aplicar (RFC 1a) | recommended; not used until Phase 3 |
| 3 | Notes | the agent may append, shown on the card (RFC 2a) | recommended; lands with Phase 3's `note`, not here |
| 4 | Plans after a restart | persisted in Postgres before deletes ship (RFC 3a) | recommended. `remove_artifact` is a delete and ships here, so **the `plan` table ships here too**, pulled forward from Phase 4: one migration, `PlanStore` over it, same 2-hour TTL |
| 5 | Deletes asked once | a doubt past 3 rows (RFC 4a): "Apagar as 6" / "Só a entrega" | recommended |
| 6 | Order | deliveries before the lifecycle (RFC 5a) | recommended, the issue's ask |
| 7 | Shape of a change | `anyOf` per verb, kept unless the eval scores it lower (RFC 6a) | recommended; `AGENT_SCHEMA` is a switch for the eval, not a product setting |
| 8 | Read tool for kinds and goals | a `read_cards` mode, not a new tool | RFC §3 recommends; the model keeps 4 tools |
| 9 | `shift`, `resize` | left out | RFC §5, decided there |
| 10 | Real-model evals | run per domain, ~US$0.10–0.50 each on OpenRouter | never in CI; named in section 5 with what they cost |

### How it will be proved

- `npm test` in `server/`: unit specs for each action's `resolve`
  refusals, and an end-to-end spec per Phase 2 verb in
  `agent.controller.spec.ts` (frozen clock, memory stores): turn → plan
  → Aplicar → state, then Desfazer → state equal to the setup, including
  the snapped run of a delivery's tasks and a removed delivery's
  backlog tasks coming back with their ids.
- A spec that the registry's `flat` schema is byte-equal to today's
  `CHANGES` before Phase 2 adds verbs (Phase 1's "no behaviour change").
- `node server/tool/coverage.mjs`: from 6 of 39 routes to 6 + the
  Phase 2 routes (target 17 of 39), and no handler whose first call is
  not a service.
- `npm run eval:agent` (real model) on `main`'s cases before and after,
  and on both schema shapes: the pass counts go in section 3.
- `.tool/check` green under both brands; the plan card shot through a
  small `agent_registry_preview.dart` with a delivery plan, both brands.

## Build brief

Starts `/create build agent-registry` (or this session, on approval: a
plan doesn't split).

- **Read first:** `product/spec/agent.md`, `product/spec/artifacts.md`,
  then `server/src/agent/{plan,gestures,agent.prompt}.ts`,
  `agent.service.ts` from `_rehearse` to the end (~line 1238), and
  `artifacts/artifacts.service.ts`.
- **Server:** steps 1–4 above, in that order, each green before the
  next. The registry must leave `agent.controller.spec.ts` passing
  unchanged before any Phase 2 verb is added. The `plan` table:
  `src/db/schema.ts` + `npm run db:generate`, committed migration.
- **App:** `PlanChangeKind` and `plan_card.dart` lines for `deliver`,
  `new_kind`, `new_goal`, `remove_goal`, and the cascade line under
  `remove_artifact` ("e as 6 tarefas dela"); strings in `app_pt.arb`.
  `AgentLinks` keeps *Abrir entrega* for a new delivery.
- **Docs:** `product/spec/agent.md` (the registry, how to add a verb,
  the new verbs), `AGENTS.md` (agent section: "one `Action` per verb in
  `agent/actions/`"; notes now writable from Phase 3 on is not yet true,
  leave it), `SETUP.md`/`.env.example` for `AGENT_SCHEMA` if it stays.
- **Open questions:** see *Decided unattended* below; none blocks the
  build.
- **Cost of the design session:** measured by the queue and written in
  the PR.

## Decided unattended

- **Track: plan.** Nothing in Phases 0–2 needs a layout decision; the
  plan card already draws artifact changes.
- **Phases 0–2 in one PR**, not 0–1. If you would rather review the
  registry alone first, say so on the issue and the build stops after
  Phase 1.
- **Plans persisted now**, not in Phase 4, because RFC decision 3 says
  "before deletes ship" and `remove_artifact` is a delete.
- **`coverage.mjs` copied to `server/tool/`** so it runs on the code it
  measures; the RFC's copy stays as the evidence it was.
