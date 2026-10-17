# RFC: A reliable Lunna assistant

2026-10-16 · Status: proposed · Scope: `server/src/agent/`

## 1. Thesis

**The agent fails because we ask the model to be the scheduler. Its job
should be to say what the person meant, and the server should do the
scheduling.**

Today every change the model proposes ends up as an absolute hour
(`at: YYYY-MM-DDTHH:mm`). The server then replays that hour through
`editTask`, which **anchors** the task. When a person drags a card between
two others, the task gets a *place in the queue*. When the agent does the
same thing, the task gets a *pinned hour*. So the agent breaks the
timeline's rules by design (problem 3). Each anchor it leaves behind also
blocks later moves, which makes the next request more likely to be refused
(problem 5).

The rest follows from that. The model should name **intent in the app's
own vocabulary**: *this card, before that card*, *tomorrow, first free
hour*, *into the backlog*. The server resolves that intent with the same
`EventLayoutService` verbs the UI already calls. It runs the plan on a
sandbox copy of the day and hands back the result. The model never does
arithmetic on hours, never picks between "task" and "event" ids, and never
works out which date "amanhã" is.

Your **data / facts / doubts** split is the right shape for each turn,
and it says who owns what. The model owns **data** (what the person said).
The server owns **facts** (what is actually true). **Doubts** are the gap
between the two, and they are found mostly by the server, not guessed by
the model (§5.3).

This does **not** need RAG. One person's day plus 14 days ahead is about
1–3k tokens. The right move is to put the day in the context, not to
retrieve pieces of it.

## 2. How the agent works today

```
POST /agent/turn
  → model(system prompt + context line + conversation)        ← call 1
      → read_timeline(from, days)        (returns UUIDs, wall-clock hours)
  → model(... + day)                                           ← call 2
      → propose_plan(changes: [{kind, id?, title?, minutes?, at}])
          _change: validates the id, kind and "not in the past"
          _rehearse: relayout with every change as an *anchor*
  → model(... + plan result)                                   ← call 3
      → final text
POST /agent/plans/:id/apply
  → _make: createTask(notBefore) | editTask(startTime) | createEvent | editEvent
```

- Model: `google/gemini-3.1-flash-lite` via OpenRouter, temperature 0.3,
  no prompt caching, 60 s timeout, up to 6 rounds (`MAX_ITERATIONS`).
- Tests use `ScriptedModel`, so **no test has ever run the real model**.

## 3. Diagnosis: each problem traced to the code

| # | Symptom | Root cause | Where |
|---|---------|-----------|-------|
| 3 | Inserting "between two tasks" doesn't push the flexible ones the way a drag does | The change vocabulary has only absolute hours. `move_task` is applied with `editTask({startTime})`, which sets `notBefore` and keeps the **old queue position**. A drag uses `moveTask({index})`, which changes `position` and **lifts** the anchor. `_rehearse` also treats every change as an anchor, so it can't even model a queue move. | `agent.service.ts:805`, `_rehearse`, `rehearse()` in `timeline.service.ts:295` |
| 3→5 | Refusals stack up over time | Each agent move leaves an anchor. The next request that lands on it gets "a task that keeps its hour is there", so the model retries, loops, or gives up. | `_rehearse` error branch |
| 2 | "Move my event" creates a duplicate | The model has to pick `move_task` or `move_event` itself, and UUIDs are hard to copy. A wrong pick returns "No event with id" or "No task with id". The model then falls back to the change that has no id to get wrong, `add_*`. Nothing checks for an `add_*` whose title already exists. `read_timeline` also defaults to `days: 1` starting **today**, so an event tomorrow is never seen unless the model asks for it. | `_change`, `_read` |
| 4 | Misses today/tomorrow | The model gets `now` and the weekday and has to work out every date itself. Small models are poor at date arithmetic: across six calendars, SPAN measured 34.5% average accuracy, and 95% once the model was given a tool for it. After the working day ends, "hoje" has no room left, and the prompt doesn't say so. | `contextLine` |
| 1 | Slow | Every change costs at least 3 **sequential** model calls (read → propose → reply). Each refusal adds 2 more. The fixed prompt isn't cached. | `_answer` loop |
| 5 | Generic errors | Four different failures produce the same few messages. (a) Any exception in `apply` becomes "o dia mudou desde que ele foi feito". That includes real gaps between `_rehearse` and what `_make` does, because the two run different code. (b) An empty model reply becomes "Não consegui responder agora". (c) The 6-round limit. (d) OpenRouter 5xx or timeout, returned as 503 with no retry. | `apply`, `_reply`, `openrouter.client.ts` |

The most important finding is the last line of problem 5. **The check
(`_rehearse`) and the action (`_make`) run different code.** Any rule that
lives in only one of them shows up as a plan that looked fine and then
failed to apply.

## 4. What the literature says, applied here

1. **Design the interface for the agent, not the API.** Anthropic's
   tool-writing guide gives a calendar as its own example: prefer one
   `schedule_event` that finds availability and books it over
   `list_events` + `create_event`. It also recommends returning readable
   names instead of opaque UUIDs, writing errors that tell the agent what
   to do next, and making invalid calls hard to write ("poka-yoke"). In
   SWE-bench, requiring absolute paths made path errors disappear. For us,
   that means arguments shaped like a drag (`before: <card>`), short refs,
   server-resolved days, and errors that name the right change.
2. **Use a workflow where the path is known.** *Building effective
   agents* separates workflows (code chooses the path) from agents (the
   model chooses). Our path is always the same: read the day, propose,
   reply. Hard-coding it saves a round-trip and removes one way to fail.
3. **Context beats retrieval when the corpus is small.** Li et al. (EMNLP
   2024) found long context beats RAG on quality when the material fits,
   and that RAG wins on cost. Our corpus is one person's two weeks, so
   long context wins. Placement still matters: *Lost in the Middle* shows
   recall drops for facts in the middle of the context, so put the day
   (and the date table) last, right before the request.
4. **Reliability is measured with pass^k, not pass@1.** τ-bench grades an
   agent by the **database state** after the conversation, and gpt-4o's
   pass^8 fell under 25% on retail. Anthropic's eval guide makes the same
   point: at k=10, pass@k approaches 100% while pass^k can approach 0. A
   planner that is right 80% of the time feels broken, so this is the
   metric to track.
5. **Don't force reasoning into rigid formats.** *Let Me Speak Freely*
   found strict JSON schemas hurt reasoning but help classification. Our
   new changes are close to classification ("which card, which verb,
   which ref"), which suits constrained arguments. The reasoning ("what did
   they mean?") should stay in free text, for example a short `intent`
   string the model writes before its changes.
6. **Agent Skills means progressive disclosure.** A skill's metadata is
   always loaded, its body only when it's relevant. That isn't needed at
   runtime yet: the agent has one domain. It will be worth it once the
   agent also handles projects and routines (§5.8). For development it's
   useful now (§5.7).

> **Q:** _“Design the interface for the agent, not the API”_ — That's a great learning for the future of the agents. I need more real cases on this

> **A:** Some real cases, from public work and from this repo:
> - **Claude Code's own Edit tool** (the one that wrote this answer) refuses to edit a file it hasn't read, and its `old_string` must match exactly once. Both rules exist because models edited files they hadn't seen and replaced the wrong occurrence. That is poka-yoke: the bad call can't be written.
> - **SWE-agent** (Yang et al., NeurIPS 2024) named the idea "agent-computer interface". Instead of a raw shell, the agent got a file viewer that shows about 100 numbered lines, a search that summarises hits instead of dumping them, and an edit command that runs a linter and rejects edits that break syntax. With the same model and a better interface, it solved far more issues.
> - **Anthropic's tool guide**: `search_contacts` instead of `list_contacts` (an agent can't read 10k rows), `schedule_event` instead of list + create, a `response_format: concise | detailed` switch, names instead of UUIDs, and truncated results that say how to narrow the query.
> - **This repo, today**: `read_timeline` hands out UUIDs and `propose_plan` asks for an absolute `at`, both shaped for the REST API. The duplicate Dentista and the anchored "drags" in §3 are what that costs; §5.1–5.2 are the agent-shaped version.
>
> A quick test for any tool: could a new hire use it correctly from its description alone? If you'd have to explain it to them, the model needs it explained too, so change the tool instead.

## 5. Recommendations (in priority order)

### 5.1 Changes the model can't get wrong (problem 3, priority 1)

Replace the four `at`-based kinds with one change per **gesture the app
already has**. Each maps 1:1 onto a layout verb:

| Change | Arguments | Server does (same as the UI) |
|--------|-----------|------------------------------|
| `place` | `ref` or `new {title, minutes}`, plus one of `before: ref` / `after: ref` / `end_of_queue` | `moveTask` / `createTask` with `index` counted by `inList`. After a card that keeps an hour, `after` is its end plus the pause, exactly like a drop. **No anchor.** |
| `at_hour` | `ref` or `new`, `day`, `time` | `moveTask({after})` / `createTask({notBefore})`, the anchored drop |
| `first_free` | `ref` or `new`, `day` | the **+** on the calendar: `nextFreeSlot` from that day's first free minute |
| `to_backlog` | `ref` | `moveTask({backlog: true})` |
| `swap` | `ref`, `with: ref` | `swapTasks` |
| `add_event` / `move_event` | `ref` or `new`, `day`, `time` | `createEvent` / `editEvent` (fixed things only) |

Then replace `_rehearse` with a **dry run**. Copy the person's pending
tasks and window events into `MemoryCalendarStore` plus an in-memory
`TaskStore`, and build a throwaway `EventLayoutService` over them. Run the
plan's changes through the **same** `_make`, read the day, and diff it
against the real one to get `pushed`. Keep the refusal rule: an anchored
`at_hour` that lands later than asked is reported to the model to ask
about, as it is now.

The rule behind the table: **every agent change is a gesture the person
could have made by hand, and leaves the day as that gesture would.**

Why: the plan and the apply run the same code, so they can't disagree.
That closes the "o dia mudou" class of errors and keeps the agent in step
with every future change to the layout rules for free. The memory stores
already exist for the end-to-end timeline tests.

The prompt shrinks to match. "How the day works" no longer has to teach
the scheduler. It only says which change matches which kind of request:
"between / before / after" → `place`, a named hour → `at_hour`, "quando
der hoje" → `first_free`.

### 5.2 Ground every reference (problem 2, priority 2)

- **One `move` concept, one ref namespace.** Show cards as short refs
  (`t1`, `t2`, `e1`, `b1` for backlog) and map them to UUIDs on the
  server. The model never sees a UUID, and every `ref` argument accepts
  any kind, so there is no `move_task` vs `move_event` to get wrong. Each
  line names its kind in words: `e1 · Dentista · evento fixo · sáb 17/10
  10:00–11:00`.
- **Duplicate guard (poka-yoke).** `new` is refused when its normalized
  title (lowercase, accents stripped, trigram similarity ≥ 0.8) matches a
  card in the horizon or the backlog. The error tells the model what to
  do instead: *"Dentista já existe (e1, sáb 10:00). Para mudar o horário
  use move com ref e1. Se é outro compromisso, envie
  `duplicate: true`."*
- **Read the whole horizon by default** (§5.5), so "the event" is always
  in view.

### 5.3 Data, facts, doubts: the shape of a turn (problems 2, 3, 4)

The idea is sound, and it lines up with what the research on clarifying
questions shows. The value is in giving each part a **single owner**:

| | What it is | Owner | Example: "coloca o dentista entre a academia e o almoço amanhã" |
|---|---|---|---|
| **Data** | What the person said, unresolved: *what*, *when* (as said), *relation*, *length* | Model, in a light-structure `data` field | `what: "dentista"`, `when: "amanhã"`, `between: ["academia", "almoço"]`, `minutes: null` |
| **Facts** | What the system knows: refs matched, the resolved date, dry-run result, pushes, conflicts | Server, deterministic. The model never writes a fact | `amanhã = sáb 17/10`; `academia → t4 (anchored 07:00)`; `almoço → e2 (fixed 12:00)`; `dentista → e5 (fixed, sáb 10:00) already exists`; `place between t4/e2 pushes t5, t6` |
| **Doubts** | What is missing or contradictory **and would change the outcome** | The server finds the structural ones. The model adds only semantic ones | *"Já tem Dentista às 10:00 de sábado. Mover esse ou é outro?"* |

How it runs:

1. The model calls `propose_plan({ data, changes })`. `data` comes first,
   written loosely: it is the model's reasoning space. *Let Me Speak
   Freely* says to keep that loose, and to keep `changes` strict.
2. The server turns data into facts (§5.1, §5.2, §5.4) and works out the
   **doubts deterministically**:
   - a reference with 0 or ≥ 2 matches;
   - a `new` that duplicates an existing card (this catches problem 2
     before any plan exists);
   - an hour on an event;
   - an hour outside the working day;
   - a day that has already ended;
   - a push that crosses into another day.
3. **Only doubts that change the outcome block the plan.** This is the
   EVPI idea from SAGE-Agent: ask only when the answer changes the
   result. A missing length doesn't block anything. It takes a default
   and becomes a stated assumption in the reply ("coloquei 30 min").
4. A blocking doubt comes back as **one question with options** (`doubt:
   { text, options: [{label, changes}] }`). The app shows it as quick
   replies ("Mover o das 10:00" / "É outro"). Picking one applies that
   option's changes with no extra model call.
5. **Ask before proposing, never after.** Clarification timing research
   finds that a question about the *goal* loses nearly all its value
   after the first 10% of execution, and that asking past mid-trajectory
   does worse than never asking. For us that means a doubt replaces the
   plan; it never follows one.

> **Note:** _“The model calls propose_plan({ data, changes }). data comes first, written loosely: it is the model's reasoning space.”_ — Doubt about tools: By anthropic docs, it says a lot about MCP. Shouldnt we implement a MCP server instead? Why, why not?

> **A:** Not for this. MCP is a **transport**: a standard way for a host (Claude Desktop, Claude Code, ChatGPT) to discover and call tools that live in another process. Our agent loop and our tools live in the same Nest process and we own both ends, so MCP would add a JSON-RPC hop, a session and a second auth path, and give the model nothing new: it sees the same name, description and schema either way. What Anthropic writes about tools (descriptions, schemas, errors) applies however the tools are delivered; MCP is just where much of it was written.
>
> It would make sense as a **second door**: saying "passa o dentista pra amanhã" to Claude or another assistant. Then an MCP server (say `/api/mcp`, behind OAuth and the same `SessionGuard`) would expose the §5.1 gesture changes, propose first and apply on confirmation. If §5.1's changes are written as plain functions with a schema, wrapping them later is small. Added to §5.8.

Why this beats a prompt rule like "ask when unsure": whether a model asks
is mostly the model's own habit, and prompting barely moves it. In *Ask
Early, Ask Late, Ask Right*, under the same harness, Gemini 3 Flash asked
in 0% of sessions, Claude Sonnet 4.5 in 23% and GPT-5.2 in 52%. Ambig-SWE
found agents "almost never" ask unless told to. When2Call found models
fill in missing arguments with made-up values rather than ask, and size
doesn't fix it. We run on Gemini, so a model-detected doubt is the one
least likely to happen. The server can see, with certainty, that
"dentista" matches a card that already exists. So whatever *can* be
detected should be detected in code, and the model is left with only the
doubts that need language.

The facts also go into the stored message (`agent_message.steps`). The
person can then see why the agent asked, and `read_conversations` can
return them later.

### 5.4 Dates resolved by the server (problem 4)

- Put a **date table** in the context: `hoje = sex 2026-10-16 (dia de
  trabalho termina 22:00, faltam 3h10)`, `amanhã = sáb 2026-10-17`, then
  the following 6 days. Mark today as `encerrado` once the working day is
  over.
- **`day` accepts `"hoje" | "amanhã" | weekday | YYYY-MM-DD`** and `time`
  is `HH:mm`. Splitting date from time removes the most common mistake:
  the right hour on the wrong date.
- Every proposal **echoes the resolved day in words** ("sábado, 17/10 às
  09:00"), both to the model and on the plan card, so a wrong day can be
  seen before Aplicar.

### 5.5 One or two calls per turn (problem 1)

1. **Preload** the day in the second system message: today, tomorrow,
   the `focusDay`, the backlog, and anything named by title in the
   request. The model starts with the day already there, so
   `read_timeline` becomes a rare fallback for days further out.
2. **Let the plan end the turn.** Add `reply` to `propose_plan`. If the
   dry run is clean and pushes nothing, the server returns that reply
   without another model call. Only refusals and pushes go back to the
   model. Common case: **3 calls → 1**.
3. **Don't count on caching.** Gemini 3.x caches only a prefix of at
   least 4,096 tokens (6,144 on 3.7/3.8 Flash), and our fixed prefix is
   about 2k. At $0.0005 per call there is little money to save either.
   Still keep the prompt and tools byte-identical and put whatever varies
   in a `user` message, not the system message. Then the 2nd–4th calls of
   a turn can hit once the history passes the threshold. OpenRouter's
   live metadata says `supports_implicit_caching: false` for these models,
   which contradicts its own docs, so check
   `usage.prompt_tokens_details.cached_tokens` on one real call before
   relying on it.
4. **Thinking effort is the bigger lever.** Set a low `reasoning_effort`.
   Classifying intent doesn't need deep thinking. (This is inferred; no
   published time-to-first-token figures exist for these models.)
5. **OpenRouter routing:** `provider.sort: "latency"`, a short `models:
   [...]` fallback list, and possibly `service_tier: "priority"`. Avoid
   the flex tier: its Vertex endpoint showed 53–63% uptime. The fallback
   list is documented to fire on errors (rate limits, downtime,
   moderation, context length) but **not on timeouts**. So keep a client
   timeout of about 20 s with one retry instead of one 60 s attempt.
6. Log `calls/turn`, `tokens`, `cached_tokens`, and `ms` per turn on the
   `Trace`. This is the latency baseline. Also log how each doubt was
   answered (an option tapped, or free text): free text means the options
   missed what the person meant.

### 5.6 Honest errors (problem 5)

- Type the failures: `ModelDown`, `ModelEmpty`, `Refused(reason)`,
  `ApplyDrift`, `Bug`. Each gets its own Portuguese line in
  `app_pt.arb`, and a `traceId` is shown under "detalhes".
- Retry once on an empty reply or a 5xx before giving up.
- Once §5.1 is in, `ApplyDrift` can only mean the day really changed
  between plan and Aplicar. Re-run the dry run on Aplicar and, if it
  still holds, apply it rather than refusing.

### 5.7 Evals before more prompt work (the multiplier)

Without evals, every prompt change is a guess. Build a τ-bench-style
suite:

> **Q:** _“Without evals, every prompt change is a guess. Build a τ-bench-style suite:”_ — I have no idea on what you are saying. I want to understand a bit more about evals

> **A:** An eval is an automated test of the **model's behaviour**, not of our code. Our tests use `ScriptedModel`, which replays answers we wrote. They prove the server works *when the model behaves*; they never check whether it does. One eval case is:
> 1. a **starting day**: Academia 07:00, Responder e-mails (queued), Almoço 12:00 fixed, Dentista sábado 10:00;
> 2. a **fixed clock**: `now` = sexta 16/10 15:00, America/Sao_Paulo;
> 3. **what the person types**: *"passa o dentista pra amanhã às 9"*;
> 4. a **check on the result, not on the words**: after Aplicar there is exactly one Dentista, and it starts on 17/10 at 09:00.
>
> The runner calls the **real model** (this is the part that costs money), applies its plan to an in-memory copy of the day, and runs the check. "τ-bench-style" means exactly this: grade the final state, not the exact tool calls, so the model may take any route that ends right.
>
> Models are random, so each case runs k times (here 4). **pass^4** is the share of cases that passed all 4 times. That is the number to watch: a request that works 3 times and fails on the 4th feels broken.
>
> What it buys you: change the prompt, a tool or the model, run `npm run eval:agent`, and read "27/30 → 29/30, nothing newly failing" instead of trying three requests by hand and guessing. The five bugs you reported become the first five cases, so none of them can come back unnoticed.

- `server/test/agent-evals/*.yaml`: a fixture day (written into
  `MemoryCalendarStore`), a fixed `now` and zone, a request in pt-BR, and
  a **state predicate** checked after Aplicar. Example: *"Dentista
  started 2026-10-17T10:00, no other card titled Dentista, Responder
  e-mails still un-anchored."*
- Start with about 30 cases: the five reported bugs as regressions, then
  between/before/after, today vs tomorrow around the end of the working
  day, an event versus a task with a similar name, and a question that
  should produce no plan. **A doubt counts as a correct outcome**: an
  ambiguous request passes only if the agent asks, and a clear request
  fails if the agent asks anyway (over-asking costs the person a turn).
- `npm run eval:agent -- --model X --k 4` runs the real model and reports
  **pass^4**, p50/p95 latency, calls per turn, and cost. Keep it out of CI
  because it costs money; run it before merging agent changes.
- **A Claude Code skill, `.claude/skills/agent-eval/`**, alongside the
  existing `feature` skill. It runs the suite, reads failing transcripts,
  sorts each failure into grounding, date, rules, error, or latency, and
  proposes a tool or prompt diff. This is the loop Anthropic describes in
  *Writing tools for agents, with agents*.

### 5.8 Later, not now

- **Runtime skill packs.** When the agent learns Projetos and Rotina,
  keep each domain's rules in a separate block that loads only when the
  request touches it, as Agent Skills do, instead of one growing prompt.
- **An MCP server** as a second way in, so another assistant (Claude,
  ChatGPT) can propose and apply the same §5.1 changes. Our own agent
  doesn't need it: its tools run in-process.
- **A2UI**, if the agent ever has to compose UI beyond the plan card and
  the doubt options.
- **RAG over past conversations.** `read_conversations` uses `ILIKE`.
  `pg_trgm` is enough until the history becomes large; embeddings only
  after that.

## 6. Decisions for you

1. **How the dry run works.** (a) In-memory sandbox stores seeded from
   the real rows. *Recommended*: no cache pollution, and it reuses the
   test stores. (b) A Postgres transaction that is rolled back: the same
   fidelity, but `CalendarService`'s write-through cache would have to be
   bypassed. (c) Extending the hand-written `rehearse`: cheapest now, but
   it keeps the two-code-paths bug.
   **Decided (2026-10-17): (a).**
2. **What "between A and B" means.** A place in the queue with no anchor
   (what a drag does, *recommended*), or an anchor at A's end. This is a
   product rule: the agent's tasks would then move with the queue later,
   just like hand-placed ones.
   **Decided (2026-10-17): a place in the queue, no anchor.**
3. **Which model.** No public benchmark scores any of the candidates on
   multi-turn tool use, so our own evals have to decide. Price is no
   longer an argument for Flash-Lite. Claude Haiku 5.5 is the cheapest
   ($0.10/$0.50 per 1M tokens), against $0.25/$1.50 for
   gemini-3.1-flash-lite. The family has also moved on: 3.5 Flash-Lite
   and 3.8 Flash are out. The last data point, Gemini 2.5 Flash-Lite,
   scored 13.5% on BFCL multi-turn against Haiku 4.5's 53.6%. Gemini 3
   Flash also asked 0% of the time in the clarification study. Run the
   suite on 3.1 Flash-Lite, 3.5 Flash-Lite, 3.8 Flash and Haiku 5.5, and
   choose on pass^4 first, then p95 latency, then cost. My prior is Haiku
   5.5, but the evals decide.
   **Decided (2026-10-17):** run it, after phase 3, with a budget of
   about $0.50 per model (`--budget`).
4. **Who writes the reply on the fast path.** The model writes it inside
   `propose_plan`, which keeps the tone and still takes one call
   (*recommended*). Or the server writes a template, which takes zero
   extra tokens but sounds flat.
   **Decided (2026-10-17): the model, inside `propose_plan`.**
5. **What "add X" with no hour means.** The backlog (what `POST /tasks`
   does by default) or the end of the queue. Today the agent is forced to
   invent an hour.
   **Decided (2026-10-17): neither as a silent default.** The agent
   proposes a place from facts (free room, what's already on the day),
   says why, and offers "Deixar para depois" (the backlog) as a quick
   reply. The backlog is the fallback when there is nothing to reason from.
6. **How a doubt reaches the person.** As structured quick replies, where
   each option carries its own changes and tapping one applies them with
   no model call (*recommended*: fast, can't be misread, and testable).
   Or as a free-text question the model writes, which needs no app work
   but costs another turn and another chance to misread the answer.
   Either way, decide which defaults are allowed to stand silently. A
   proposed starting point: length 30 min, place = the end of the queue,
   day = today while there is room left in it.
   **Decided (2026-10-17): quick replies, free text as the fallback.**
   No default is silent: the reply names each one it took.

> **Q:** _“n-memory sandbox stores seeded from the real rows. Recommended: no cache pollution, and it reuses the test stores.”_ — Yep, In-memory seems good for me, because it's just another concrete implementation of the database, right?

> **A:** Yes. `MemoryCalendarStore` and `MemoryTaskStore` extend the same abstract `CalendarStore` and `TaskStore` as the Postgres ones, so `EventLayoutService` can't tell them apart. The dry run copies your rows into fresh memory stores, builds a throwaway `EventLayoutService` over them, runs the plan, reads the day and throws it all away. One caveat: the copy is only as faithful as the memory stores are to Postgres, so any rule that lives in SQL (a constraint, an `ON CONFLICT`) must be mirrored in them. The end-to-end timeline tests already rely on that. Phase 1 should add a test that runs the same plan on both stores and compares the resulting days. Taken as decided (§6.1).

> **Q:** _“just like hand-placed ones.”_ — Just like hand-placed ones. You pinned. That's always the right call when designing agent tools. Things that matches manual behavior.

> **A:** Agreed, and taken as decided (§6.2): "between A and B" is a place in the queue with no anchor, exactly what a drag does. It's also the general rule, now stated in §5.1: **every agent change is a gesture the person could have made by hand, and leaves the day as that gesture would.** The agent's results are then explainable ("it did what dragging there does"), and each new layout rule reaches the agent for free. It goes into `product/spec/agent.md` when phase 1 ships.

> **Q:** _“Which model. No public benchmark scores any of the candidates on multi-turn tool use, so our own evals have to decide. Price is no longer an argument for Flash-Lite. Claude Haiku 5.5 is the cheapest ($0.10/$0.50 per 1M tokens), against $0.25/$1.50 for gemini-3.1-flash-lite. The family has also moved on: 3.5 Flash-Lite and 3.8 Flash are out. The last data point, Gemini 2.5 Flash-Lite, scored 13.5% on BFCL multi-turn against Haiku 4.5's 53.6%. Gemini 3 Flash also asked 0% of the time in the clarification study. Run the suite on 3.1 Flash-Lite, 3.5 Flash-Lite, 3.8 Flash and Haiku 5.5, and choose on pass^4 first, then p95 latency, then cost. My prior is Haiku 5.5, but the evals decide.”_ — Let's do the eval precisely for this. I don't want to spend super amount of tokens but I think around $0.50 each model just to find out isnt too much.

> **A:** It fits, if the comparison runs after phases 1–3, as §7 already orders it. Estimate per model, 30 cases × k=4 = 120 turns, at list price:
> - **Haiku 5.5**: ~$0.22 with today's agent (≈3 calls of ~5k tokens in), ~$0.08 after phase 3 (≈1.3 calls of ~4k in)
> - **3.1 Flash-Lite**: ~$0.56 today, ~$0.23 after
> - **3.5 Flash-Lite**: ~$0.72 today, ~$0.31 after
> - **3.8 Flash**: ~$1.60 today, ~$0.65 after
>
> So about $1.30 for all four, and only 3.8 Flash goes over $0.50. Thinking tokens are billed as output and are not in these numbers, which is one more reason for a low `reasoning_effort`. The runner gets `--budget 0.50`: it adds up the `cost` OpenRouter reports on each call and stops that model when the budget is spent, so a surprise can't cost more. For 3.8 Flash, run k=2 first and go to 4 only if it's in contention. These are estimates; the first real run replaces them.

> **Q:** _“Who writes the reply on the fast path. The model writes it inside propose_plan, which keeps the tone and still takes one call (recommended). Or the server writes a template, which takes zero extra tokens but sounds flat”_ — yep, preferably fast path. I think it can be the model, we could evaluate using a2ui for that (if we dont do it already)

> **A:** Agreed, decided (§6.4): the model writes the reply inside `propose_plan`, so a clean plan takes one call. On **A2UI**: we don't use it. A2UI is Google's open format for an agent to describe UI as JSON (components plus data), which the app renders with its own native widgets; Flutter's GenUI SDK is built to render it. We already have a closed version of that idea: the agent can produce exactly two things, a plan card and (with §5.3) a doubt with options. Both are typed, drawn by our own widgets and checkable in evals. A2UI pays off when the agent has to compose screens we didn't build (a picker of three free hours, a comparison of two weeks), not for the reply, which is plain text. Added to §5.8, to revisit when the agent learns Projetos and Rotina.

> **Q:** _“Today the agent is forced to invent an hour.”_ — Well, it is a really good question. Ultimately, the agent will learn what would be the best place to put some event given x,y,z facts. Lets imagine that we have an available room for today, the task is about exercising, you dont have any other exercise task today, so the model _suggests_ putting at certain time. So, it is driven by facts. However, I would like the agent to have an active aspect, not just a passive one. So the agent can suggest things (but should not take as granted anything implicit). The agent must always suggest and ask the user if that seems good.

> **A:** Taken as the rule (§6.5): **the agent proposes from facts and says why; nothing implicit is applied silently.** For "add X" with no hour:
> - The server gives the model the facts a good suggestion needs: the free stretches today and tomorrow and what's already on the day. Later it can add what similar tasks usually look like (when you usually exercise, for how long).
> - The model proposes a concrete place and gives its reason in the reply: *"Coloquei Academia hoje às 18:00: tem 1h livre e você ainda não fez exercício hoje. Pode ser?"*
> - The plan card is the question: Aplicar means yes, and a quick reply *"Deixar para depois"* sends it to the backlog instead, with no model call.
>
> So there's no fixed default. The backlog is the fallback only when there are no facts to go on (no room left, nothing to reason from), and the reply says so. This matches `GET /agent/suggestion`, which already proposes a backlog task that fits the room left today: suggest, never assume. The **active** side (the agent offering things nobody asked for) is a bigger feature. I'd give it its own RFC once evals exist, because a wrong suggestion nobody asked for is worse than none.

> **Q:** _“How a doubt reaches the person. As structured quick replies, where each option carries its own changes and tapping one applies them with no model call (recommended: fast, can't be misread, and testable)”_ — Yep, I prefere the first option, what you suggested. The slow option, fallback, written free form reply is just when the answer does not fit for the user. But that is a good metric to understand if AI is replying in a good way or not.

> **A:** Agreed, decided (§6.6): quick replies, each carrying its own changes, with free text always available underneath. And it's a good metric: **how often a doubt is answered in free text instead of a tap** tells us the options missed what the person meant. It goes in the per-turn log (§5.5.6) and in the evals. Following your note on §6.5, the defaults (30 min, end of the queue, today) are never silent: the reply names each one.

## 7. Rollout

| Phase | Ships | Fixes | Size |
|-------|-------|-------|------|
| 0 | The eval harness, plus the 5 reported bugs as failing cases | Measuring | S |
| 1 | §5.1: gesture changes and the dry run | 3, most of 5 | M |
| 2 | §5.2 + §5.3 + §5.4: refs, duplicate guard, data/facts/doubts with quick-reply doubts, date table, `day`/`time` | 2, 4 | M |
| 3 | §5.5 + §5.6: preload, one-call path, routing, typed errors | 1, 5 | S |
| 4 | Model comparison on the suite (decision 3) | All | S |

The app needs almost nothing. `PlanChange` stays the shape the card
draws. A `place` change shows the resolved hour like any other, and gains
a day label.

## 8. References

- Anthropic, [Writing effective tools for agents, with agents](https://www.anthropic.com/engineering/writing-tools-for-agents) (2025): consolidated tools (`schedule_event`), readable ids, actionable errors, eval-driven tool design.
- Anthropic, [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) (2024): workflows vs agents, ACI, poka-yoke tools.
- Anthropic, [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) (2025): the smallest high-signal context, just-in-time loading.
- Anthropic, [Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) (2025): progressive disclosure.
- Anthropic, [Demystifying evals for AI agents](https://anthropic.com/engineering/demystifying-evals-for-ai-agents): graders, pass@k vs pass^k.
- Yao et al., [τ-bench: tool-agent-user interaction in real-world domains](https://arxiv.org/abs/2406.12045) (2024): state-based grading, pass^k. [Sierra's summary](https://sierra.ai/blog/benchmarking-ai-agents).
- [SPAN: cross-calendar temporal reasoning](https://arxiv.org/abs/2511.09993) (AAAI): 34.5% average for LLMs alone, 95% with tool-based date computation.
- [TCP: temporal constraint-based planning](https://arxiv.org/html/2505.19927v2): scheduling and time-zone failure modes.
- Li et al., [RAG or long-context LLMs?](https://arxiv.org/abs/2407.16833) (EMNLP 2024): long context wins when the material fits.
- Liu et al., [Lost in the Middle](https://arxiv.org/abs/2307.03172) (TACL 2024): where in the context to put what matters.
- Tam et al., [Let Me Speak Freely?](https://arxiv.org/abs/2408.02442) (EMNLP 2024): format constraints hurt reasoning and help classification.
- Suri et al., [Structured Uncertainty guided Clarification for LLM Agents](https://arxiv.org/abs/2511.08798) (SAGE-Agent, arXiv 2025; venue unconfirmed): uncertainty over tool arguments, asking by EVPI; 7–39% more coverage of ambiguous tasks with 1.5–2.7× fewer questions. The paper's text and table disagree on one baseline figure.
- Ross et al., [When2Call](https://arxiv.org/abs/2504.18851) (NAACL 2025): call, ask, or decline; models invent missing arguments, and size doesn't help.
- [CAR-bench](https://arxiv.org/abs/2601.22027) (2026): acting too early causes about 90% of GPT-5's failures on ambiguous tasks; settle from data, ask only when two or more valid options remain.
- Full research notes behind §5.3, §5.5 and decision 3: [reports/caching-and-models.md](./reports/caching-and-models.md).
- [Ask Early, Ask Late, Ask Right](https://arxiv.org/abs/2605.07937) (2026): a question about the goal loses nearly all its value after the first ~10% of execution, and asking past mid-trajectory is worse than never asking.
- [Ambig-SWE: interactive agents and underspecified instructions](https://arxiv.org/html/2502.13069v2) (2025): agents tend to go ahead on unwarranted assumptions instead of asking.
- OpenRouter, [Provider routing](https://openrouter.ai/docs/features/provider-routing) (latency sort, fallbacks) and [Structured outputs](https://openrouter.ai/docs/features/structured-outputs) (strictness varies by provider).
