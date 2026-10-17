# RFC: The agent answers in UI, speaks the app's words, and reaches projects

2026-10-17 · Status: proposed · Scope: `server/src/agent/`, `app/packages/agent/`,
`server/src/projects/` · Follows
[2026-10-16-agent-reliability](../2026-10-16-agent-reliability/README.md)

## 1. Thesis

**The model should pick what to show, never write it. Every answer becomes
an A2UI surface that the server builds from a small Lunna catalog. The
model's only free text is one short caption, which code checks before
anyone reads it.**

The first RFC moved scheduling from the model to the server. Text is the
last thing the model still owns, and both new symptoms live there. The
`reply` argument is required, and the prompt asks for up to three
sentences that say why and what moves. So a plan arrives with prose that
restates the card drawn under it, plus 2–3 server "steps" above it. In the
dev data, that is five lines of text over one card. Choices are prose too:
the model has no way to offer a button, so "Quer A ou B?" gets "sim", and
the turn is spent again ([data](./data/dev-conversation.md): four turns
for one plan). The leaks have the same cause. Everything the model reads
is written for the model: refs (`e2`), English refusals ("a task that
keeps its hour"), minutes ("900 min"), "backlog". Nothing stands between
those words and the reply, so the model paraphrases them to the person:
"o sistema recusou", "a e2".

A2UI is the right envelope for the fix. It is declarative JSON: surfaces,
components drawn from a catalog the client trusts, a data model, and
actions sent back. But **for us its value is the contract, not layouts
written by the model.** Our catalog is five Lunna components (plan,
choices, a slice of the day, a project, a caption). A component's props
are exactly what our tools already return, so the server writes the A2UI
from typed tool calls (`propose_plan`, a new `ask`, a new `show`). The
plan card then still equals the dry run, and the small model never writes
ids, paths or layout. The app renders surfaces with the widgets it already
has.

Projects fit the same shape. The board gets a one-line index of open
projects, and a `read_project` tool reads one on demand: the "just in
time" pattern. Project writes become gestures in the same plan and the
same sandbox (let a task out, park it, add one, append to the notes). So
the agent reads and writes projects, still only by proposing.

What is **not** needed: the A2A transport (A2UI rides any JSON channel,
so our REST answer is enough), letting the model author layouts, RAG over
projects (one person's open projects are a few hundred tokens), or a
second agent for projects.

## 2. How a turn reaches the screen today

```
POST /agent/turn
  → Board(day)                                   board.ts:92  refs t1…, e1…, b1…
  → model(SYSTEM_PROMPT + history text + board + "Request: …")
      → propose_plan { data, changes[], reply }  reply is required prose
          _draft / _doubt / _rehearse            refusals in English, with refs
  ← { reply, steps[], plan?, options[] }
app: _Answer (agent_sheet.dart:606)
  steps (one ✓ line each) → reply text → PlanCard → QuickReplies
```

- The model writes free text in two places: the `reply` argument of
  `propose_plan` (`agent.prompt.ts:194` makes it required) and a plain
  final message when it asks or answers (`agent.service.ts:305`). Both
  reach the screen verbatim.
- The only structured answers come from the server: the plan card, the
  duplicate doubt's two pills (`_doubt`, `agent.service.ts:703`) and
  "Deixar para depois" (`agent.service.ts:692`).
- Model: `anthropic/claude-haiku-5.5` was recommended over
  `gemini-3.1-flash-lite` in the last delivery. `tool_choice: 'auto'`,
  temperature 0.3 (`openrouter.client.ts:157`).
- Projects are invisible to the agent. `TaskStore.pending` leaves out
  parked tasks (`task.store.ts:74`), so neither the board nor the sandbox
  (`gestures.ts:39`) ever holds one, and a task let out carries no project
  on the board (`board.ts:116`).

## 3. Diagnosis

The evidence is the one conversation in the dev database,
[data/dev-conversation.md](./data/dev-conversation.md); the aggregates
come from [code/replies.mjs](./code/replies.mjs), in
[data/replies.json](./data/replies.json). It took four turns to get one
plan, the median reply is 42 words, and the plan reply had 5 lines of text
above its card. Four replies are far too few to make a baseline, so phase
0 makes one (§7).

| # | Symptom | Root cause | Where |
|---|---------|-----------|-------|
| 1 | Asked to do something, it answers with paragraphs | `reply` is required, and the prompt asks for up to three sentences, to say why, and to end by naming what moves. The result is prose that restates the card under it | `agent.prompt.ts:14,35,37,39`; `required` at `:194` |
| 2 | Steps add 2–3 more lines to every answer | Every resolution writes a step ("Achei Troca 2 · tarefa · Depois eu priorizo", "Livre hoje: 19:03–22:00"), and the app draws them all, with a ✓ each | `agent.service.ts:956,1111`; `agent_sheet.dart:625` |
| 3 | Choices are asked in prose, and "sim" answers neither half | The model has no tool for offering options; only the server's duplicate doubt makes pills | `agent.prompt.ts:40`; `_doubt` is the only producer of `options` |
| 4 | Questions about the day ("organiza minha tarde") come back as a list in prose | Only text can carry a slice of the day back; the board is for the model alone | `agent.service.ts:305` |
| 5 | It names cards like "a2" or "e2" | The prompt says "Use refs, never titles, to name existing cards" without limiting that to tool arguments, and `reply` is itself a tool argument | `agent.prompt.ts:22` |
| 6 | It says "o sistema recusou", "backlog", "900 minutos livres" | Refusals are written for the model: in English, with refs and the scheduler's words ("fixed event", "a task that keeps its hour"). The model paraphrases them to the person. The board's spans are in minutes, and its kinds are the scheduler's ("task in the queue") | 22 `Refusal`s, e.g. `agent.service.ts:718,825,850,1077,1096,1107`; `board.ts:363,394` |
| 7 | A ref in an earlier answer now points at another card | Refs are renumbered every turn by start order, but earlier replies are replayed as text without their board | `board.ts:135`; `agent.service.ts:273` |
| 8 | Nothing catches either problem | Evals grade the day after Aplicar and whether the agent asked; no check reads the reply. Every case is a single turn | `evals/run.ts:216` |
| 9 | "What's left in project X?" or "put a task from X tomorrow" can't be done | Parked tasks never reach the board or the sandbox, and projects have no tool. `placeTask('scheduled')` anchors through `editTask`, a second path beside the gestures | `task.store.ts:74`; `gestures.ts:39`; `projects.service.ts:201` |

Row 6 is the original bug pattern again: **two audiences, one text.**
Each refusal is written once, for the model, and the person ends up
reading it secondhand.

## 4. What the literature says, applied here

1. **A2UI is declarative data rendered by native widgets from a catalog
   the client trusts.** The agent sends `createSurface`,
   `updateComponents` and `updateDataModel`, and the client sends an
   `action` back. Components are a flat list joined by id, bound to a data
   model by path. Messages "travel over any transport" (A2A, AG-UI, SSE,
   WebSockets). The current release is v0.9.1, v1.0 is a release
   candidate, and the project calls itself an "early stage public preview"
   ([spec](https://a2ui.org/specification/v0.9.1-a2ui-extension-specification/),
   [intro](https://a2ui.org/introduction/what-is-a2ui/),
   [repo](https://github.com/google/A2UI)). **For us:** we adopt the
   message shapes and a custom `catalogId`, carried in our REST answer.
   Pin v0.9 and keep it behind one encoder, since v1.0 will rename things.
2. **The A2UI repo leaves room for either an LLM-written response or a
   pre-built one.** An agent "either generates an A2UI response or uses a
   pre-generated one", and the catalog limits what can be asked for
   ([repo](https://github.com/google/A2UI)). **For us:** the server
   generates it. Our components carry facts the dry run computed (hours,
   pushed tasks), which the model must not restate.
3. **Flutter's `genui` renders A2UI, but its approach is "prompt-first".**
   The catalog schema goes into the system prompt as text, and the model
   writes A2UI JSON inside its replies. `genui` 0.9 removed
   `ContentGenerator` in favour of `SurfaceController` +
   `A2uiTransportAdapter` + `Conversation`
   ([Flutter blog, 2026-05-14](https://flutter.dev/blog/new-updates-to-a2ui-and-flutters-genui-package),
   [components](https://docs.flutter.dev/ai/genui/components)). `genui`
   0.10.4 depends on `audioplayers`, `video_player`,
   `flutter_markdown_plus` and `a2ui_core`
   ([pub.dev](https://pub.dev/packages/genui)), and its docs call it alpha.
   **For us:** its prompt-first design is the opposite of our typed-tool
   design, and its dependencies bring media players into a planner. A
   small renderer of our own is about 150 lines, built on the widgets we
   already have (Decision 2).
4. **Generated interfaces beat chat where the task is interactive, and
   lose on simple questions.** In a Stanford preprint, people preferred
   generated UIs over Claude 3.7 chat 84% to 12%, and 80% on interactive
   queries. Chat won on simple "how-to" questions, and real users split
   only 51/41. The authors flag latency (minutes of refinement) as the
   limit ([Chen et al. 2025](https://arxiv.org/html/2508.19227v2)).
   **For us:** UI for plans, choices and views of the day; one caption
   line is enough for a simple fact. The latency lesson argues against
   model-written layouts: a fixed catalog costs no extra model time.
5. **Return meaningful names, not low-level identifiers. Write errors that
   tell the agent what to do.** Replacing UUIDs with readable names
   reduced hallucinations ([Anthropic, Writing tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents)).
   **For us:** refs stay because they are short and unambiguous in tool
   arguments, but they must never cross into what the person reads. A
   refusal has two audiences, so it carries two texts (§5.1).
6. **Context should be just in time: lightweight identifiers up front,
   details loaded by tools, and a minimal set of tools that don't
   overlap** ([Anthropic, Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)).
   **For us:** an index of projects on the board (name, deadline, counts,
   ref) and `read_project` for the detail. Don't put every parked task on
   every turn.
7. **More tools hurt small models.** Cutting the tools offered per task
   improved function-calling success and cut execution time by up to 70%
   ([Paramanayakam et al., DATE 2025](https://arxiv.org/abs/2411.15399)).
   **For us:** go from 3 tools to 5 at most (`ask`, `show`/read folded),
   and add project writes as new gesture kinds inside `propose_plan`, not
   as new tools.

## 5. Recommendations

### 5.1 Stop the leaks (priority 2, but first to ship: small and fixes trust)

| Change | Where | Fixes |
|---|---|---|
| Limit refs to tool arguments: "Refs are for tool arguments only. In anything the person reads, name cards by title." | `agent.prompt.ts:22` | 5 |
| A glossary in the prompt: the app's words for its own things (*Depois eu priorizo*, *bloco fixo*, *fila*), and words never to say (ref, sistema, servidor, âncora, backlog, evento + ref) | `agent.prompt.ts` | 6 |
| **Refusals carry two texts**: `Refusal(model, person?)`. The model gets the English with refs; when the person needs to be told, the server says it in Portuguese itself, as a doubt with choices (§5.3), so the model never paraphrases. Start with the four that reach people: outside the working day, an hour already passed, no room today, an event on an event | `agent.service.ts:98` and the 22 call sites | 6 |
| `speakable(text, board)`: replace every board ref with its title, swap "backlog" for "Depois eu priorizo", log `agent.leak` when anything was replaced. Deterministic, run on every caption and fallback text | new, `agent/speech.ts` | 5, 6 |
| The board says lengths like the app does ("15h livres", "1h30"), not "(900 min)" | `board.ts:394` (reuse `formatSpan`, `:478`) | 6 |
| Refs stay stable within a conversation: keep `id → ref` per `conversationId` and give new cards the next number | `Board` constructor, a map like `_asked` | 7 |
| Evals read the reply: no ref pattern, no banned word, ≤ 15 words when there is a plan. Add 3 multi-turn cases ("organiza minha tarde" → choice → applied) | `evals/run.ts`, `cases.ts` | 8 |

### 5.2 Answers are surfaces (priority 1)

**What.** `POST /agent/turn` answers with `ui`, a list of A2UI v0.9
messages for one surface per turn, against our own catalog. During one
release it keeps `reply/plan/options` too, for builds still on phones.

| Component | Props (all from the server) | Drawn by | Replaces |
|---|---|---|---|
| `Caption` | `text` (≤ 80 chars, after `speakable`) | `Text` | the paragraph |
| `Plan` | the `PlanView` as it is today | `PlanCard` | unchanged |
| `Choices` | `options: [{label, action}]`, at most 3 | `QuickReplies` | prose either/or |
| `DayPeek` | `day`, `cards: [{title, start, end, kind}]`, `free: [{start, end}]` | a compact Tempo row list (reuse `TimelineList` tiles) | the list in prose |
| `ProjectPeek` | `title`, `deadline`, `counts`, `next: [task]` | the Projetos card | (new, §5.4) |

The wire shape for a plan turn (check the field names against the v0.9
schema when building):

```json
[
  {"version":"v0.9","createSurface":{"surfaceId":"turn-81f2","catalogId":"https://lunna.pietroteruya.dev/a2ui/v1/catalog.json"}},
  {"version":"v0.9","updateComponents":{"surfaceId":"turn-81f2","components":[
    {"id":"root","component":"Column","children":["say","plan","more"]},
    {"id":"say","component":"Caption","text":"Tem 1h30 livre às 18:00."},
    {"id":"plan","component":"Plan","plan":{"path":"/plan"}},
    {"id":"more","component":"Choices","options":{"path":"/options"}}]}},
  {"version":"v0.9","updateDataModel":{"surfaceId":"turn-81f2","path":"/","value":{"plan":{"id":"…","changes":[…]},"options":[…]}}}
]
```

**Actions.** A tap sends an A2UI `action` (`name`, `surfaceId`,
`sourceComponentId`, `context`):

| `name` | `context` | Server |
|---|---|---|
| `apply` | `{ planId }` | `POST /agent/plans/:id/apply`, as today |
| `choose` | `{ planId }` or `{ say }` | a choice carrying a plan applies it, as quick replies do today; one carrying `say` becomes the next turn, written down as the person's message ("Só a Troca 2, hoje"), so "sim" never has to be read |
| `adjust` | `{ planId }` | puts the person back in the field, as Ajustar does |

**Steps.** They leave the surface. They stay in the trace and on the
stored message, and in the app they go under the existing **Detalhes**
disclosure. The day a change lands on is already the card's header.

**Caption.** `propose_plan.reply` becomes an optional `caption`, written
only when it adds something the card can't show (the reason for a
proposed hour). The prompt drops "at most three sentences", "end your
reply by naming what moves" and "Fica assim". A plan with nothing to add
draws no text at all.

**Why the server writes the A2UI, not the model.** The `Plan` props are
the dry run's output. If the model wrote them, the card could disagree
with what Aplicar does, which is the bug the first RFC removed. The
catalog is five fixed components, so a model-written layout would have
nothing to choose. And because the props match the tool results one to
one, writing them in the server costs no extra model time.

**App.** `AgentSurface` takes the message list and keeps a
`Map<id, component>` plus the data model. It builds each component by name
from a `const` registry of our widgets, and falls back to `Caption` for
any name it doesn't know (A2UI says to keep going past a failed message).
`_Answer` (`agent_sheet.dart:606`) becomes one `AgentSurface`. Old
conversations keep drawing through `PlanLine`.

### 5.3 The model offers choices and views instead of writing them (priority 1)

There are two new tools, and the final plain message becomes a fallback:

| Tool | Arguments | The server |
|---|---|---|
| `ask` | `question` (one sentence), `choices: [{label, changes?, say?}]` (2–3) | runs each choice that has `changes` through `_rehearse` (one sandbox each, as `_doubt` already does) and returns `Caption` + `Choices`. A choice that fails its dry run is dropped and the model is told why |
| `show` | `day?` / `refs?` / `project?`, `caption?` | returns `Caption` + `DayPeek` (or `ProjectPeek`), built from the board, with no model in the loop |

The prompt gains: "Open requests (organizar, encaixar) get a plan, with
other ways as `ask` choices, not a question in prose. Questions about the
day get `show`." With `tool_choice: 'required'` (if the provider honours
it through OpenRouter; check in phase 0), a turn always ends in a tool
call, so the text fallback is rare. For the dev conversation, this makes
turn 1 a plan for the afternoon with "Só a Troca 2" and "As duas amanhã"
as choices, each a plan. That is one turn instead of four.

The refusals in §5.1 that reach people use the same machinery. "Outside
the working day" becomes `Choices`: *Amanhã às 07:00* · *Deixar para
depois*, written by the server.

### 5.4 The agent reads and writes projects (priority 3)

The options for awareness:

| Option | What the model sees | Tokens per turn | Verdict |
|---|---|---|---|
| A. Everything on the board | every open project, every parked task with a ref, notes | grows with every project; notes unbounded | no |
| **B. Index on the board + `read_project`** *(recommended)* | one line per open project: `p2 · Tese · prazo 30/11 · 6 no projeto, 2 no dia`; `read_project(ref)` gives tasks with refs (`p2.1`…) and notes | ~15 per project | yes: the just-in-time pattern (§4.6) |
| C. Tool only | nothing until it asks | 0 | misses "isso é do projeto X?" turns |
| D. RAG / search over notes | snippets | small | not needed until notes are long; full-text search later |
| E. A separate projects agent | — | — | not needed: one person, one domain |

On the day, each card also says its project (`t3 · Capítulo 2 · … · Tese`),
since `Task.projectId` is already on the row.

Writes stay proposals. They are new gesture kinds inside `propose_plan`,
made by `make()` on the sandbox and the real day alike:

| Gesture | What it is by hand | Made with |
|---|---|---|
| `let_out { ref, then }` | Projetos → a stage, or `PlaceSheet` | unpark (as `ProjectsService._unpark`), then the existing `place`/`at_hour`/`first_free`/`to_backlog`, so the drop rule is the same |
| `park { ref }` | dragging back into the project | `ProjectsService._park`; refused when begun, as today |
| `add_to_project { project, new }` | + in the project | `addTask`, parked at the end |
| `note { project, append }` | typing in the notes | append only, shown in full on the card before Aplicar; never rewrites what is there |
| `project { project, deadline?, done? }` | the project sheet | `edit` |

What this needs:

- `sandbox()` seeds the parked tasks of the projects a plan names, and a
  `MemoryProjectStore` (it already exists, `project.store.ts:26`).
- `Undo` gains `restore_project`.
- `ProjectsService` calls the same `make()`, so `placeTask('scheduled')`
  stops anchoring through `editTask` (`projects.service.ts:201`). That
  removes the second code path from row 9.
- Two components: `ProjectPeek`, and a `Plan` row for project changes ("→
  Tese: Capítulo 2 · sai do projeto, amanhã 09:00").

Deleting a project is not offered. It is the one destructive project
action, and a person does it by hand in a few taps.

## 6. Decisions for you

1. **Who writes the A2UI.** *(a) The server, from typed tools*
   *(recommended)*: no new model behaviour, and the card still equals the
   dry run. *(b) The model, prompt-first, as `genui` does*: freer layouts,
   but a small model writing ids and paths is a new failure surface, and
   the plan card's facts would come from the model. *(c) (a) now, (b)
   later* for `show` only, once the catalog grows.
2. **The renderer.** *(a) Our own small renderer over our widgets,
   speaking A2UI v0.9* *(recommended)*: about 150 lines, no new
   dependencies, both brands for free. *(b) `genui`*: the official path,
   but alpha, prompt-first, and it pulls in media and markdown packages.
   *(c) `a2ui_core` for parsing only* (unverified whether it is usable on
   its own).
3. **Steps.** *(a) Under Detalhes* *(recommended)*. *(b) Fold the one
   that matters (the day said) into the card header, drop the rest.*
   *(c) Keep them as they are.*
4. **The caption.** *(a) Optional, ≤ 80 characters, only to add a reason*
   *(recommended)*. *(b) Never: the surface speaks alone.* *(c) Keep
   prose, shortened.* (c) leaves symptom 1 in place.
5. **Project awareness.** *(a) Index on the board + `read_project`*
   *(recommended)*. *(b) Tool only.* *(c) Everything on the board.*
6. **Project writes.** *(a) Gestures in plans, notes append-only*
   *(recommended)*. *(b) Read-only first, writes in a later release.*
   *(c) Notes rewritable by the agent*: more useful for "organize my
   notes", but it overwrites the person's own text, so it would need a
   diff view first.

## 7. Rollout

| Phase | Ships | Fixes | Size |
|---|---|---|---|
| 0 | Eval reply checks (refs, banned words, words per plan turn), 3 multi-turn cases, a baseline run on Haiku 5.5; `code/replies.mjs` run on the production database (read only) for real leak counts; check whether `tool_choice: 'required'` works through OpenRouter | measuring 8 | S |
| 1 | Prompt: refs in tool arguments only, the glossary; `speakable`; lengths as "1h30"; stable refs per conversation | 5, 6, 7 | S |
| 2 | Two-text refusals for the four that reach people, as server `Choices` | 6, 3 (partly) | S |
| 3 | A2UI envelope + catalog (`Caption`, `Plan`, `Choices`) + `AgentSurface`; steps under Detalhes; optional caption | 1, 2 | M |
| 4 | `ask` and `show`, `DayPeek`, the `choose` action; `tool_choice: 'required'` | 3, 4 | M |
| 5 | Project index on the board, `read_project`, `ProjectPeek`, project on day cards | 9 (read) | S–M |
| 6 | Project gestures in plans, sandbox seeding, `restore_project`; `ProjectsService` on `make()` | 9 (write) | M–L |

Run `npm run eval:agent` before merging each of phases 1–6, as
`product/spec/agent.md` asks.

## 8. References

- A2UI v0.9.1 extension spec: message names, catalogs, `action`, processing rules. <https://a2ui.org/specification/v0.9.1-a2ui-extension-specification/>
- What is A2UI: flat components, data model by path, any transport. <https://a2ui.org/introduction/what-is-a2ui/>
- google/A2UI README: release status, renderers (Flutter through GenUI), generated or pre-generated responses, Apache-2.0. <https://github.com/google/A2UI>
- Flutter blog, "New updates to A2UI and Flutter's GenUI package" (2026-05-14): prompt-first, the new class names. <https://flutter.dev/blog/new-updates-to-a2ui-and-flutters-genui-package>
- GenUI components: `Conversation`, `SurfaceController`, `CatalogItem`, how actions loop back. <https://docs.flutter.dev/ai/genui/components>
- `genui` on pub.dev: version 0.10.4 and its dependencies. <https://pub.dev/packages/genui>
- Chen et al., "Generative Interfaces for Language Models" (arXiv 2508.19227v2): 84% vs 12%; chat wins on simple questions; latency. <https://arxiv.org/html/2508.19227v2>
- Anthropic, "Writing effective tools for agents" (2025-09-11): readable names over identifiers; actionable errors. <https://www.anthropic.com/engineering/writing-tools-for-agents>
- Anthropic, "Effective context engineering for AI agents" (2025-09-29): just-in-time identifiers; minimal, non-overlapping tools. <https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents>
- Paramanayakam et al., "Less is More" (DATE 2025, arXiv 2411.15399): fewer tools, better function calling on small models. <https://arxiv.org/abs/2411.15399>
- The previous RFC, whose contract this keeps (the model says what was meant, the server decides): [2026-10-16-agent-reliability](../2026-10-16-agent-reliability/README.md)

**Unverified.** The exact v0.9 component field names in §5.2 (the spec
page gives only a `Text` example). Whether `a2ui_core` can be used without
`genui`. Whether OpenRouter passes `tool_choice: 'required'` through to
the configured model. The "a2" reply itself, which is not in the dev
database. Phase 0 checks the first three, and the production read checks
the last.
