# RFC: The agent answers in UI, speaks the app's words, and reaches projects

2026-10-17 · Status: proposed, not yet built · Scope: `server/src/agent/`,
`app/packages/agent/`, `server/src/projects/` · Follows
[2026-10-16-agent-reliability](../2026-10-16-agent-reliability/README.md)

**Revised 2026-10-17** after `d515d68` (parking dropped: a project's
tasks are ordinary backlog tasks) and `e88e08e` (the bar at the foot of a
task's and a project's notes, sending `about`). §5.4 is rewritten for
projects without parking. New: §5.6, create, edit and delete for tasks
and projects as gestures; §5.7, a conversation opened on a page has
that page's context and that page's history. Rows 9 and 11–15 of §3 are
new or rewritten.

## 1. Thesis

**The model composes the answer from a small Lunna catalog, and the
server binds every fact into it. Every answer becomes an A2UI surface:
the model picks the blocks, the slice of the day, the order and the
words; the server fills in hours, lengths and plans from the dry run, and
writes the A2UI. Code checks the model's only free text, one short
caption and the headings, before anyone reads it.**

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
actions sent back. **For us the split is layout vs facts.** The model
fills one tool, `answer`, with blocks from our catalog (plan, choices, a
slice of the day, some cards, a project, a caption). It chooses which,
in what order, under what headings. The server resolves each block from
the board and the dry run, and writes the A2UI (`toA2ui`). The plan card
then still equals the dry run, and the small model never writes an id, a
path or an hour. The app renders surfaces with the widgets it already
has. Because this half is the riskier one, a phase 0b eval compares it
with a fixed server layout before the app is built (§5.3).

Projects fit the same shape. The board gets a one-line index of open
projects, and `read_cards` (one tool for projects and notes) reads one on
demand: the "just in time" pattern. **Everything the person can do by
hand to a task or a project becomes a gesture in the same plan and the
same sandbox**: write it down, rename it, change its length, append to
its notes, tick it off, delete it, and for projects create, edit, set a
deadline and close. The agent still only proposes. The plan card shows
each change, a delete included, before Aplicar, and Desfazer takes all of
it back. That is the agent's own human-in-the-loop gate, so a delete
needs no second one. It does need an undo that can bring a deleted row
back (§5.6).

**A conversation opened on a page is about that page, before and after.**
`about` already puts the task or project into the turn, but the
conversation is stored without it. So the sheet shows Tempo's history,
the model can't find what was said about this task last week, and the
subject's own tasks lose their refs once they fall off the board. The
fix is to store the subject on the conversation, list and search by it,
and give the subject's cards their own refs (§5.7).

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
- Since `d515d68` there is no parking. A project's tasks are ordinary
  tasks with `project_id`, mostly in the backlog, so they are on the board
  and in the sandbox as `b…` refs. But the board shows only the first 30
  of the backlog (`MAX_BACKLOG`, `board.ts:29`), and no board line names
  a project (`board.ts` never reads `projectId`). Outside a project's
  page, projects don't exist for the agent.
- Since `e88e08e`, a turn can carry `about: { taskId } | { projectId }`
  (`agent.controller.ts:207`). `_subject` (`agent.service.ts:262`) writes
  the task's line, or the project's name, deadline, notes and tasks, after
  the board. A task not on the board gets a line with **no ref**
  (`agent.service.ts:281`).
- The only write is `propose_plan`, whose gestures are `place`,
  `at_hour`, `to_backlog` and `swap` (`plan.ts:54`). There is no rename,
  length, notes, done or delete gesture. There is nothing for projects
  either. Undo knows `remove_*` and `restore_*` (`gestures.ts:213`), and
  `restore_task` is an `update`, so it can't bring back a deleted row
  (`pg-task.store.ts:122`).
- Conversations are stored without a subject (`agent_message`,
  `schema.ts:345`). The app has one `AgentCubit` whose past is one global
  list, read once (`agent_cubit.dart:143`).

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
| 9 | From Tempo, "what's left in project X?" or "put a task from X tomorrow" can't be done | Project tasks are on the board now (parking is gone), but no line says which project they belong to, there's no project index, and a 31st backlog task has no ref | `board.ts:29,116`; `agent.service.ts:262` only on a project's page |
| 10 | From Tempo, "what did I write on the Dentista?" or "note on the call to bring the contract" can't be done | The board never carries notes, and no gesture writes them. Only `_subject` reads notes, and only the open page's | `board.ts:116`; `plan.ts:54`; `agent.service.ts:267` |
| 11 | On a project's page, "move the third one to tomorrow" fails when the project has many tasks | `_subject` lists a task that is off the board (past the 30th of the backlog, further ahead, done) by title, with no ref. The model can name it but can't act on it | `agent.service.ts:273-282` |
| 12 | "Rename this", "make it 1h", "tick it off", "delete it", "create a project Mudança with these three tasks" can't be done | The only gestures are where and when. Title, length, done, delete and every project write have no gesture, and the spec says "Nothing is removed" (`product/spec/agent.md`) | `plan.ts:54`; `ChangeKind` at `plan.ts:9` |
| 13 | A delete the agent proposed couldn't be undone, even if it existed | `restore_task` is `TaskStore.update`, which changes an existing row. A deleted row has nothing to update, and neither store can put a row back with its id | `gestures.ts:220`; `pg-task.store.ts:122` |
| 14 | Opening the bar on a block's (event's) page gives the agent no context | `NotesDock.task` sends `about` only when the page is a task's; events have no `Subject` kind | `notes_dock.dart:49`; `agent.controller.ts:207` |
| 15 | On a task's page, the sheet shows Tempo's conversations, and "what did we decide about this last week?" finds nothing | `agent_message` has no subject. `GET /agent/conversations` and `read_conversations` filter by date and words only, and the app reads one global past list once | `schema.ts:345`; `conversation.store.ts:45`; `agent_cubit.dart:143` |

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
   ([repo](https://github.com/google/A2UI)). **For us:** both. The model
   picks the components and their order, and the server generates the
   props. Our components carry facts the dry run computed (hours, pushed
   tasks), which the model must not restate.
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
   ref) and `read_cards` for the detail. Don't put every parked task on
   every turn.
7. **More tools hurt small models.** Cutting the tools offered per task
   improved function-calling success and cut execution time by up to 70%
   ([Paramanayakam et al., DATE 2025](https://arxiv.org/abs/2411.15399)).
   **For us:** go from 3 tools to 4: `read_timeline`,
   `read_conversations`, `read_cards` (project contents and notes) and
   `answer`, which takes in `propose_plan`, `ask` and `show` (§5.3).
   Project and note writes are new gesture kinds inside its `changes[]`,
   not new tools. That holds for create, edit and delete too: 7 new
   gesture kinds in one enum, not 7 new tools (§5.6).
8. **Approval goes on the action, not in the prompt. Approval-required
   calls end the run and wait for a yes or no on the exact arguments.**
   Microsoft Agent Framework marks a tool `approval_mode="always_require"`.
   Calling it returns pending `user_input_requests` holding the name and
   arguments, and the run resumes with an approval response. The model
   isn't told which tools need approval
   ([Chaganti, on MS Agent Framework](https://ravichaganti.com/blog/human-in-the-loop-with-function-approvals-in-microsoft-agent-framework/)).
   **For us:** our whole write path already works this way. Every change
   is a plan, and Aplicar is the yes. So delete needs no new gate, only a
   plan row that says plainly it deletes ("Apagar · Dentista"). The
   server, not the prompt, decides which kinds need it.
9. **Avoiding harm and being able to undo it are separate properties.**
   On Agent RedressBench (64 scenarios), guardrails cut unsafe-action
   labels but produced no redress evidence. Redressability scored 4.58/24
   with guardrails and 19.21/24 with action traces
   ([Alqithami & Alzahrani, AIES 2026](https://ojs.aaai.org/index.php/AIES/article/view/43130)).
   **For us:** a prompt rule like "never delete without asking" is the
   guardrail. Desfazer that actually brings a deleted task back, plus a
   plan stored on the conversation, is the redress. Build the undo before
   offering delete (row 13).
10. **Thread memory and entity memory are different scopes.** In
    LangGraph, short-term memory is scoped to one thread. Long-term
    memories sit in "namespaces", like folders, and can be read from any
    thread. Semantic memory holds facts, episodic memory holds past events
    ([LangChain, Memory](https://docs.langchain.com/oss/python/concepts/memory)).
    **For us:** a conversation is the thread. A task or a project is the
    namespace: conversations opened on it, and plans that touched it, are
    its episodic memory. The notes are its semantic memory, and the
    person writes them. So the agent reads earlier talk about the subject
    from `agent_message` by subject, and never writes summaries into the
    notes on its own.

> **Q:** _“For us: the server generates it.”_ — Interesting choice. Given the idea is actually the LLM to have flexibility to return any interface.

> **A:** Fair challenge. The split I'd defend isn't "server vs model". It's **layout vs facts**. The model can pick freely which components to show, in what order and grouped how, plus every label and caption. What it can't write is any fact the dry run computed: hours, lengths, what gets pushed, ids. Those come from the server, so the plan card can never disagree with Aplicar. That gives the LLM its flexibility without bringing back the bug the first RFC removed. The worked design is under Decision 1's question below.

> **Note:** _“built on the widgets we already have (Decision 2)”_ — that seems good for now.

> **Q:** _“For us: UI for plans, choices and views of the day; one caption line is enough for a simple fact.”_ — That's precisely it!!

> **A:** Good. Then the bar for the caption is "a fact the card can't show". Decision 4 has the examples.

> **Q:** _“ever cross into what the person reads”_ — yep. Curious how you do it

> **A:** In three layers, and only the first is a prompt. (1) The prompt says refs are for tool arguments only. (2) `speakable(text, board)` runs on everything a person will read: caption, choice labels, fallback text, appended notes. It's deterministic. It matches `\b[tebdp]\d+(\.\d+)?\b` against the refs on this turn's board and swaps each for the card's title, and does the same for the glossary words ("backlog" → "Depois eu priorizo"). Every swap is logged as `agent.leak`, so the prompt's failure rate stays visible after the user stops seeing it. (3) Refusals the person must hear are written by the server in Portuguese (two-text `Refusal`), so the model never paraphrases them. The model can still slip. The person just never sees it.

> **Q:** _“The server”_ — perfect.

> **A:** 👍 Concretely: the server owns which kinds need approval, and none of it lives in the prompt.

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

> **Q:** _“Refs are for tool arguments only. In anything the person reads, name cards by title”_ — Really, is just a prompt? how to eval this?

> **A:** No, the prompt is the cheapest layer. `speakable` is the guarantee (see the answer in §4). It's measured three ways. (1) **Eval, deterministic:** in `evals/run.ts`, every case runs the *raw* model text (before `speakable`) through the same ref regex and the glossary's banned words. The rate is reported per model (`leak@1`), and a hit fails the case only when it also survives `speakable`. The raw rate tells us how good the prompt is, and the final text tells us whether the person ever sees a ref (that one must be 0). (2) **Unit tests** for `speakable` itself: "a e2" → "a Reunião", refs from another turn left alone, "t1" inside a word left alone. (3) **Production:** the count of `agent.leak` per turn in the trace logs, plus `code/replies.mjs` over the database for the before and after.

### 5.2 Answers are surfaces (priority 1)

**What.** `POST /agent/turn` answers with `ui`, a list of A2UI v0.9
messages for one surface per turn, against our own catalog. During one
release it keeps `reply/plan/options` too, for builds still on phones.

The model's blocks (§5.3) become these components:

| Component | Props (all from the server) | Drawn by | Replaces |
|---|---|---|---|
| `Caption` | `text` (≤ 80 chars, after `speakable`) | `Text` | the paragraph |
| `Plan` | the `PlanView` as it is today | `PlanCard` | unchanged |
| `Choices` | `options: [{label, action}]`, at most 3 | `QuickReplies` | prose either/or |
| `DayPeek` | `day`, `cards: [{title, start, end, kind}]`, `free: [{start, end}]` | a compact Tempo row list (reuse `TimelineList` tiles) | the list in prose |
| `Cards` | `title?`, `cards: [{title, start?, end?, minutes, project?}]` | Lista tiles, read only | a list of cards in prose |
| `ProjectPeek` | `title`, `deadline`, `counts`, `next: [task]` | the Projetos card | (new, §5.4) |

> **Q:** _“ProjectPeek title, deadline, counts, next: [task] the Projetos card (new, §5.4”_ — We need some interface on it

> **A:** Agreed. It needs a mockup before it's built. My sketch, to take into `/create`: the Projetos list's own row (name, deadline bar, counts), then up to 3 of its next tasks as Lista tiles (title, hour or "Depois eu priorizo", length), then "Abrir projeto" to open its page. No new widget, only two existing ones stacked. It's drawn for a `project` block ("como está a Tese?") and above a plan that changes a project. Decision 7 adds a variant: a delete row that names what goes with it.

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
stored message, and in the app they go under a **Detalhes** disclosure,
the one the failure note already has (`failure_note.dart:84`). The day a change lands on is already the card's header.

**Caption.** `propose_plan.reply` becomes the `answer`'s optional `caption`, written
only when it adds something the card can't show (the reason for a
proposed hour). The prompt drops "at most three sentences", "end your
reply by naming what moves" and "Fica assim". A plan with nothing to add
draws no text at all.

**Why the model composes but the server writes the A2UI.** The `Plan`
props are the dry run's output. If the model wrote them, the card could
disagree with what Aplicar does, which is the bug the first RFC removed.
The layout is where the model's judgement helps: whether "organiza minha
tarde" is best answered by the afternoon with two choices, or by a plan
and nothing else. A2UI's ids, paths and data model help no one when
typed by a small model, so `toA2ui` writes them. The props match the
tool results one to one, so binding them costs no extra model time.

**App.** `AgentSurface` takes the message list and keeps a
`Map<id, component>` plus the data model. It builds each component by name
from a `const` registry of our widgets, and falls back to `Caption` for
any name it doesn't know (A2UI says to keep going past a failed message).
`_Answer` (`agent_sheet.dart:606`) becomes one `AgentSurface`. Old
conversations keep drawing through `PlanLine`.

### 5.3 The model composes the answer, the server binds it (priority 1)

**Decided 2026-10-17** (the note under Decision 1): the model picks the
layout, and the server fills in every fact. This replaces the earlier
`ask` + `show` pair and the free-text final message.

**One tool ends every turn: `answer`.** It replaces `propose_plan`'s
`reply`, `ask` and `show`. `propose_plan` itself becomes one kind of
block. The model fills in a list of blocks, and each block **names what
to show, never what it says**:

```json
{"caption": "Sua tarde tem duas janelas.",
 "blocks": [
   {"day": "hoje", "from": "13:00", "to": "18:00", "free": true},
   {"cards": ["t3", "b2"], "title": "Para encaixar"},
   {"choices": [
     {"label": "Só a Troca 2", "changes": [{"do": "at_hour", "ref": "b2", "day": "hoje", "time": "15:00"}]},
     {"label": "As duas amanhã", "changes": [ … ]}]}]}
```

| Block | The model chooses | The server fills or checks |
|---|---|---|
| `caption` (one per answer) | the words, ≤ 80 chars | `speakable`; dropped when longer |
| `plan { changes }` (at most one) | the gestures | the dry run, as `propose_plan` does today: refusals and pushes go back to the model, and only a plan that held is drawn, as `Plan` with the `PlanView` |
| `choices [{label, changes? \| say?}]` (2–3) | the labels and what each does | each choice with `changes` gets its own dry run (one sandbox each, as `_doubt`); a choice that fails is dropped and the model told why |
| `day { day, from?, to?, free? }` | which day and hours, whether free room is drawn | the cards and free stretches, from the board or `read_timeline`; a range out of reach is refused |
| `cards { refs[], title? }` | which cards, in what order, under what heading | each card's title, hour, length and project, by ref; an unknown ref is dropped |
| `project { ref }` | which project | `ProjectPeek`'s data (§5.4) |
| any block: `focus: true` (at most one) | what to emphasise | drawn first, or highlighted |

**What the model never writes:** an A2UI id, a JSON path, an hour, a
length, an id, a pushed task, the data model. `toA2ui(answer, board,
dryRuns)` builds all of them. **What it is free in** is what changes what
the person sees: which blocks, which slice, the order, the grouping, the
headings and the words.

**Limits live in code**, each with a refusal the model can act on
(§4.5): at most 6 blocks, at most one `plan`, choices 2–3, `cards` at
most 8 refs, headings ≤ 40 chars (through `speakable`), `day` within the
14 days the resolver accepts. A block that breaks a limit is dropped,
and the rest is drawn. Only an empty answer is sent back to the model.

**The loop.** The model may call the read tools and then `answer`. When
the answer's plan or a choice fails its dry run, the tool result says
why, and the model answers again, at most twice, as `propose_plan` does
now. An `answer` with a plan that held and nothing dropped ends the
turn in one call. With `tool_choice: 'required'` (check that it passes
through OpenRouter, in phase 0), every turn ends in `answer`, and the
plain-text fallback is only for a provider that ignores it.

**Tools, after this:** `read_timeline`, `read_conversations`,
`read_cards`, `answer`. That's four, one more than today and two fewer
than the six §4.7 allowed. The gestures of §5.5–5.6 are the `changes`
enum inside `plan` and `choices`.

**The prompt gains**: "Open requests (organizar, encaixar) get a plan,
and other ways go in as choices, never a question in prose. Questions
about the day get a `day` or `cards` block, not a list in words. Add a
caption only for what the blocks can't show." For the dev conversation,
that makes turn 1 a `day` block for the afternoon plus two choices, each
a plan. That's one turn instead of four.

The refusals of §5.1 that reach the person use the same blocks, written
by the server, not the model. "Outside the working day" becomes
`choices`: *Amanhã às 07:00* · *Deixar para depois*.

**Exploring it (phase 0b).** This is the riskier half of the RFC, so it
gets measured before the app is built. Use `npm run eval:agent` on the
same cases, plus 6 open ones ("organiza minha tarde", "como está a
Tese?", "o que tenho amanhã?"), comparing **(F) a fixed layout** (the
server picks the blocks from what the tools returned) against **(C) the
model composing**:

| Metric | How | Moves to C when |
|---|---|---|
| valid answers | % of `answer` calls with nothing dropped | ≥ 95% on Haiku 5.5 |
| turns per plan | multi-turn cases, as in §5.1 | not worse than F |
| tokens and p50 latency per turn | the `agent.turn` log | ≤ 1.2× F |
| which answer helps more | pairwise LLM judge on F vs C screenshots of the same turn, both orders, plus 20 read by you | C preferred, consistent across orders |

The rendered pairs come from `AgentSurface` in a widget test (golden
PNGs), so the judge sees what the person would. If C loses, F is the
same `answer` tool with the blocks filled in by the server, so nothing
built for C is thrown away.

### 5.4 The agent sees projects from anywhere (priority 3)

Since `d515d68` a project's task is an ordinary task, so most of the old
§5.4 is gone: no `let_out`, no `park`, no second placing path in
`ProjectsService`. What's left is for the agent to **know which project a
card belongs to, and to reach the tasks that aren't on the board.**

The options for awareness:

| Option | What the model sees | Tokens per turn | Verdict |
|---|---|---|---|
| A. Everything on the board | every open project, every project task with a ref, notes | grows with every project; notes unbounded | no |
| **B. Index on the board + `read_cards`** *(recommended)* | one line per open project: `p2 · Tese · prazo 30/11 · 6 tarefas, 2 com hora`; `read_cards([p2])` gives its notes and every task with a ref | ~15 per project | yes: the just-in-time pattern (§4.6) |
| C. Tool only | nothing until it asks | 0 | misses "isso é do projeto X?" turns |
| D. RAG / search over notes | snippets | small | not needed until notes are long; full-text search later |
| E. A separate projects agent | — | — | not needed: one person, one domain |

- **Each card names its project** (`b4 · Capítulo 2 · 45 min · Tese`),
  read from `Task.projectId`, which is already on the row. The `projects`
  list is one more read per turn (`ProjectStore.list`).
- **Every task the model is shown gets a ref, wherever it is.** Today a
  task off the board is shown with no ref (row 11). The fix is
  `board.reach(tasks)`: it hands out the next ref of the task's kind (a
  backlog task after the 30th gets `b31`, a task further ahead gets the
  next `t`, a done one `d1`). It also seeds the task's row into the
  sandbox, so a gesture on it is made the same way as on any other card.
  `_subject` and `read_cards` both go through it. This is the stable-refs
  map of §5.1 in another form: one `id → ref` table per conversation.
- `read_cards([p2])` answers what `_subject` writes today (name,
  deadline, notes cut at 2000 characters, tasks), with refs. **The page
  context and the tool are one function**, so what the model reads about
  a project is the same whether it opened on its page or asked from
  Tempo.
- A done task (`d…`) takes only `edit` and `note` (as its page allows:
  name and notes only, `projects.md`). The other gestures refuse it,
  naming it.
- One component, `ProjectPeek`, for the `project` block (§5.3).

Project writes are in §5.6, with the rest of create, edit and delete.

### 5.5 Notes on every card: tasks, blocks and projects (priority 3, with 5.4)

A note is the same thing wherever it lives: free text the person keeps on
a card. So the agent gets **one way to read notes and one gesture to write
them**, for any ref: a task (`t3`), a block (`e1`), a backlog task (`b2`),
a project (`p2`), or a project's task (`p2.1`).

**Reading.** On the board, a card with notes says so in one word
(`t3 · Dentista · … · notas`). Notes are free text of any length, so the
text itself is not put on every turn: that is the same just-in-time
choice as for projects (§4.6). `read_cards(refs[])` returns them, trimmed to
about 2k characters each. It is the same tool that reads a project
(§5.4 reads a project by its `p` ref), so notes add no tool.
A `cards` block can then draw a card with its notes (`Cards` gains `notes` per
card) when the person asks "o que eu anotei no Dentista?".

**Writing.** One gesture kind inside the `plan` block's `changes`:

| Gesture | What it is by hand | Made with | Undo |
|---|---|---|---|
| `note { ref, append }` | typing at the end of the notes on the event page | `editTask(id, { notes })` / `editEvent(id, { notes })` / `ProjectsService.edit` | `restore_task` / `restore_event` already exist (`plan.ts:90`); `restore_project` is new (§5.6) |
| `new.notes` on `place`/`at_hour`/... | writing it down with notes | `createTask` / `createEvent` with `notes` | `remove_task` / `remove_event`, as today |

- `editTask` with only notes changes no hour (`event-layout.service.ts:313`),
  so a note never pushes anything, and the dry run shows that.
- **Append only**, on a new line, by default. The `Plan` row shows the
  added text in full ("+ Dentista · notas: levar o exame"), so the person
  reads exactly what will be written before tapping Aplicar.
- A note goes through `speakable()` like a caption, so no ref ever lands
  in the person's own text.
- A begun task can still take a note. Notes aren't an hour, so the
  "nothing begun is moved" rule doesn't apply to them.

Rewriting or tidying notes ("organiza as notas da Tese") is Decision 6(c).
It needs a before/after view on the card, because it replaces the
person's own words.

### 5.6 Create, edit and delete tasks and projects (priority 2, with 5.4 and 5.5)

**What.** Every write a person can make on a task's page, on a project's
page or in Lista becomes a gesture kind in the `changes[]` of `answer`'s
`plan` and `choices` blocks (§5.3).
They're made by `make()` on the sandbox and on the real day through the
same services the routes call. So the rule of the first RFC still holds:
**every change is a gesture the person could have made by hand.** A
request with no gesture behind it is not offered (moving a task to
another project, for example: no screen does that today, so it is out of
scope).

| Thing | Gesture | By hand | Made with | Undo | Plan row |
|---|---|---|---|---|---|
| task / block | create: `new` on `place`/`at_hour`/`first_free`/`to_backlog`, gaining `notes?` and `project?` (a `p` ref) | + on Tempo or in a project | `createTask { projectId }` / `createEvent` | `remove_task` / `remove_event`, as today | "+ Mala · Mudança · Depois eu priorizo" |
| task / block | `edit { ref, title?, minutes? }` | the event page's name and length | `editTask` / `editEvent` with `{ title, workMinutes }` | `restore_task` / `restore_event` | "Dentista → Dentista (Dra. Ana)", "Relatório · 30 min → 1h" |
| task / block / project | `note { ref, append }` | typing at the end of the notes | §5.5 | §5.5 | §5.5 |
| task / block | `done { ref }` | carry right | `doneTask` / `doneEvent` | the snapshot (below) | "✓ Relatório" |
| task / block | `remove { ref }` | carry left | `removeTask` / `removeEvent` (a routine's day is cancelled, not deleted, `event-layout.service.ts:611`) | `revive_task` / `revive_event` (new) | "Apagar · Dentista" |
| project | `new_project { title, deadline?, notes?, tasks?: [{title, minutes}] }` | + on Projetos, then + in it | `ProjectsService.create`, then `addTask` each | `remove_project` (its tasks are in the backlog, so they go with it) | "+ Projeto Mudança · 3 tarefas" |
| project | `project { ref, title?, deadline? \| null, done? }` | the project's sheet | `ProjectsService.edit` | `restore_project` (new) | "Tese · prazo 30/11 → 15/12", "Tese · concluído" |
| project | `remove_project { ref }` | the project's sheet, Apagar | `ProjectsService.remove` | `revive_project` + `revive_task` for each backlog task it took + `restore_task` for the rest (Decision 7) | "Apagar projeto Tese · 4 tarefas vão junto" |

**How.**

- **`Hands` gains `projects`.** `sandbox()` seeds a `MemoryProjectStore`
  (`project.store.ts:26`) with the person's projects. That's one more
  read per plan, and a few rows. It also builds a `ProjectsService` over
  the same hands (its four dependencies are already in `Hands`,
  `projects.service.ts:28`). The sandbox's task store must hold every
  task a gesture names, including the off-board ones, which
  `board.reach` (§5.4) seeds.
- **Undo is a snapshot of what the dry run changed, not of the named
  card.** `done` re-anchors the run snapped after it (`snappedAfter`).
  `remove_project` deletes some tasks and detaches others. Today's
  `keep()` (`gestures.ts:231`) notes only the card it's given, so undoing
  either would leave the rest moved. `make()` should diff the sandbox
  (or the real stores) before and after each gesture, then write
  `restore_*` for each row that changed and `revive_*` for each row that
  went. That's one function for every kind, and it also fixes this for
  the gestures we have today.
- **A deleted row comes back with its id.** `TaskStore`,
  `CalendarStore` and `ProjectStore` each gain `revive(user, row)`:
  insert with the row's own id, `ON CONFLICT (id) DO NOTHING`. Without
  it, Desfazer can't undo a delete (row 13), and §4.9 says that undo is
  the safety, not the prompt. Build it first, and offer `remove` only
  after it passes a test: delete, undo, and the day reads back identical.
- **Rules live in code.** A begun task can be renamed, noted and ticked
  off, but not resized (that is Estender, `extendTask`). Nothing in the
  past changes. A done task takes only `edit { title }` and `note`, as
  its page allows. Each rule is a two-text refusal (§5.1).
- **Deletes read as deletes.** The plan card draws destructive rows
  first, in their own words ("Apagar", never "remover da lista"), and
  names whatever goes with them (a project's tasks). Over a threshold the
  server asks once before it plans (Decision 8): the duplicate doubt's
  machinery with two pills, "Apagar as 6" and "Só a Mala".
- **"Isso" is the page.** On a page, the subject's ref is written first
  in the subject block (§5.7), so "apaga isso" or "renomeia para…"
  resolves to it. When an applied plan deleted the page's subject, the
  app pops the page (`touched` contains the id and the next read lacks
  it).
- **Prompt.** Drop "Nothing is removed" from the spec. Add one line:
  "Edit, tick off or delete only what the person named. Delete only when
  they said to delete." The server enforces the rest.
- **App.** `PlanChangeKind` (`models.dart:28`) gains `edit`, `note`,
  `done`, `remove`, `addProject`, `editProject`, `removeProject`. Each
  gets its own line in `PlanLine`, with copy in `app_pt.arb`.
- **Evals** (`cases.ts`): rename, length change (with what it pushes),
  done (the snapped run moves back), delete, then undo restoring the day
  exactly, a project with three tasks, a deadline moved, "apaga isso"
  from a task's page, and the 31st backlog task of a project named from
  its page.

### 5.7 A page is the conversation's subject: its context and its history (priority 1, small)

The bar on a page already sends `about`. Four things stop the subject
from being the conversation's real context:

| # | Gap | Change | Where |
|---|---|---|---|
| a | A block's page sends nothing | `Subject` gains `{ eventId }`; `NotesDock.task` passes the card's kind and id. `_subject` writes the block's line and notes | `agent.controller.ts:207`; `notes_dock.dart:49` |
| b | The subject's tasks off the board have no ref | `_subject` goes through `board.reach` (§5.4) and is the same function as `read_cards` | `agent.service.ts:273` |
| c | The conversation forgets what it was about | `agent_message` gains `subject_kind` and `subject_id` (nullable, no foreign key, so history outlives a delete), written on every message of a conversation opened on a page, and indexed `(user_id, subject_id, created_at)` | `schema.ts:345`; a migration |
| d | History isn't the subject's | below | `conversation.store.ts:45`; `agent_cubit.dart:143` |

**What "related" means.** A conversation is about a task if it was opened
on the task's page, **or** if a plan in it that was applied touched the
task (`plan->'changes' @> '[{"id": …}]'`, already stored in
`agent_message.plan`). For a project, it is the project's page, plus
those same conditions for any of its tasks. This way "move the Dentista
to Friday", said on Tempo, appears on the Dentista's page too.
`ConversationQuery` gains `subject?: Subject`, and both stores answer it.

**What the person sees.** `GET /agent/conversations` takes
`?taskId=|eventId=|projectId=`. Opened on a page, the sheet's past is
that subject's conversations. Opened on Tempo, it is every conversation,
as today. `AgentCubit` keeps the past per subject: `open(about:)` with a
different subject drops the list it has and reads that subject's first
page, instead of `_asked` reading once per app (Decision 9).

**What the model sees.** This is the "namespace" of §4.10. Under the
subject block, the server writes up to the last three earlier exchanges
about it, one line each, with no refs (titles only, through
`speakable`), and a cap of about 300 tokens:

```
Earlier about this task:
  12/10 · "passa pra sexta de manhã" → plan applied: Dentista sex 09:00
  14/10 · "anota que é na Dra. Ana" → (no plan)
```

Past refs are never replayed: they were another board's (row 7). More
than three goes through `read_conversations { here: true }`, the same
search narrowed to the subject. The notes stay the person's semantic
memory. The agent never writes a summary of a conversation into them
unless asked, and then as a `note` gesture the person approves.

**Ordering in the turn.** Board, then subject, then its history, then
the request, as now (`agent.service.ts:362`). What the person is
looking at sits closest to what they asked, and the system prompt and
tools stay byte-identical, as the spec requires.

## 6. Decisions for you

1. **Who writes the A2UI.** *Decided 2026-10-17 (the note below):* the
   model composes blocks from the catalog in one `answer` tool, and the
   server binds the facts and writes the A2UI (§5.3). It's explored
   first in phase 0b against a fixed server layout. What's still open:
   whether to go further, to *(b) the model writing A2UI itself,
   prompt-first, as `genui` does*. That means freer layouts, but a small
   model typing ids and paths, and the plan's facts coming from the
   model. Revisit at A2UI 1.0, if phase 0b shows C holding ≥ 95% valid
   answers.
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
5. **Project awareness.** *(a) Index on the board + `read_cards`*
   *(recommended)*. *(b) Tool only.* *(c) Everything on the board.*
6. **Project and note writes** (notes on tasks, blocks and projects
   alike). *(a) Gestures in plans, notes append-only* *(recommended)*.
   *(b) Read-only first, writes in a later release.* *(c) Notes rewritable
   by the agent*: more useful for "organize my notes", but it overwrites
   the person's own text, so it would need a before/after view first.
7. **Delete.** *(a) `remove` for tasks and blocks once `revive` passes
   its round-trip test; `remove_project` after that* *(recommended)*: full
   CRUD, and every delete can be undone. *(b) Tasks and blocks only;
   projects stay manual*: a project's delete takes its backlog with it,
   so its undo is the largest. *(c) No delete*: the agent can still tick
   off, so "tira isso" becomes "done", which is wrong for things that
   were never done.
8. **When a delete asks first.** *(a) A plan that deletes more than 3
   cards, or any project, becomes one server doubt before the plan*
   *(recommended)*: one extra tap only for bulk, where rubber-stamping
   costs most. *(b) Never: the plan card and Desfazer are enough.*
   *(c) Every delete*: safest, but it doubles the turns for "apaga o
   dentista".
9. **History on a page** (a task's or a project's only; Tempo keeps
    today's global history and gets no extra context). *(a) The subject's
    conversations on its page, and the last 3 exchanges written for the
    model* *(recommended)*. *(b) The same, but nothing written for the model,
    only `read_conversations { here }`*: cheaper, but "o que a gente
    combinou?" then costs a tool call. *(c) A page resumes its last
    conversation instead of starting one*: more continuity, but against
    the spec's "each opening is a new conversation", and the board from
    last time is stale.

> **Q:** _“a) The server, from typed tools (recommended): no new model behaviour, and the card still equals the dry run.”_ — I would lean to model to generate. But I would like to know specifically how you plan the model picking something and the server picking the json. Because there are many degrees of freedom, so the model still needs to choose some properties anyway.

> **A:** Here is the concrete split. The model fills **one tool, `show`, with a tree of catalog nodes**. Each node names what to show, never what it says:
>
> ```json
> {"caption":"Sua tarde tem duas janelas.",
>  "blocks":[
>    {"day":"hoje","from":"13:00","to":"18:00","free":true},
>    {"cards":["t3","b2"],"title":"Para encaixar"},
>    {"choices":[{"label":"Só a Troca 2","changes":[…]},{"label":"Deixar tudo amanhã","changes":[…]}]}]}
> ```
>
> | The model chooses | The server fills or checks |
> |---|---|
> | which components and in what order (`day`, `cards`, `project`, `plan`, `choices`, `caption`), how they're grouped, and the section titles | every hour, length, free stretch, title and id of a card (from the board, by ref) |
> | which slice: a day and an hour range, refs, a project ref, and whether free room is drawn | that each ref exists and each range is within reach; a bad one is dropped and the model told why |
> | the labels and caption (through `speakable`) | each choice's plan, from its `changes`, through the dry run; one that fails is dropped |
> | emphasis: one block marked `focus` | the A2UI ids, paths and data model (`toA2ui(tree, board)`) |
>
> So the model has the degrees of freedom that change what the person sees: what, which slice, order, grouping, words. It never types an A2UI id, a JSON path or a fact. That's my updated recommendation: Decision 1 becomes *(a) model composes from the catalog, server binds the data*. Fully free A2UI from the model stays the other option, for when the catalog outgrows a fixed schema. Say yes and I'll rewrite §5.2–5.3 and Decision 1 to match.

> **Q:** _“a) Our own small renderer over our widgets, speaking A2UI v0.9 (recommended): about 150 lines, no new dependencies, both brands for free.”_ — That's good. on a2ui1.0 which should be available soon I think this will be more mature.

> **A:** Agreed. Everything A2UI-specific goes behind one encoder (`toA2ui`) and one decoder (`AgentSurface`), with the version pinned at v0.9. Moving to 1.0 then means changing those two files, not the tools or the widgets.

> **Q:** _“Steps. (a) Under Detalhes (recommended).”_ — What this means?

> **A:** "Steps" are the lines the server writes for each resolution, drawn today above the answer with a ✓ each: "✓ Achei Troca 2 · tarefa · Depois eu priorizo", "✓ Amanhã é sáb 17/10", "✓ Livre hoje: 19:03–22:00". They help debugging, and they're noise for the person. (a) hides them behind a small "Detalhes" link under the answer that expands them, the same disclosure the failure note already has (`failure_note.dart:84`, which today exists only on errors). So the answer is the card, and the trace is one tap away.

> **Q:** _“The caption. (a) Optional, ≤ 80 characters, only to add a reason (recommended). (b) Never: the surface speaks alone. (c) Keep prose, shortened. (c) leaves symptom 1 in place.”_ — can you illustrate.

> **A:** For "encaixa a academia amanhã":
>
> - **(a) Optional, only for a reason.** The card says "Academia · amanhã 18:00 · 1h". No caption, since the card says it all. When there is a reason the card can't show: "Às 18:00 porque de manhã você tem a Reunião até 12:00." (one line), then the card.
> - **(b) Never.** Only the card, always. The reason for the hour is lost, and so is "Assumi 1h", unless the card says it (it does today, as `assumed`).
> - **(c) Prose, shortened.** "Coloquei a Academia amanhã às 18:00, por 1h, depois da Reunião. Fica assim?", then the card repeating the same thing. That's symptom 1 again, with fewer words.

> **Q:** _“Moving a task between projects. No screen does it, so no gesture can”_ — no need to worry about this.

> **A:** Noted. I've dropped it from the decisions, and the agent won't offer it.

> **Q:** _“History on a page. (a) The subject's conversations on its page; everything on Tempo; the last 3 exchanges written for the model (recommended).”_ — Not sure if needed. for tempo we need no context because it is wide open. for project and task it is useful.

> **A:** That matches (a): on Tempo, nothing changes. There's no subject, the full history is as today, and nothing extra is written for the model. All of it happens only on a task's or a project's page. I've reworded the option to say so.

> **Q:** _“ay yes and I'll rewrite §5.2–5.3 and Decision 1 to match.”_ — I loved this approach. Let's see how it works. I think this is an interesting approach enough to exlpore further.

> **A:** Done. §5.3 is now "The model composes the answer, the server binds it": one `answer` tool whose blocks replace `propose_plan`'s reply, `ask` and `show` (4 tools in all), its limits in code, and the retry loop. Decision 1 records the choice, and the thesis, §4.2, §4.7 and §5.2 match it. Since you want to explore it, I added **phase 0b**: the same `answer` tool evaluated two ways, F (the server picks the blocks) vs C (the model composes), on valid-answer rate, turns per plan, tokens and latency, and a pairwise judge on rendered PNGs. C ships if it holds ≥ 95% valid answers on Haiku 5.5 and isn't worse elsewhere. F is the fallback, and it reuses everything.

## 7. Rollout

| Phase | Ships | Fixes | Size |
|---|---|---|---|
| 0 | Eval reply checks (refs, banned words, words per plan turn), 3 multi-turn cases, a baseline run on Haiku 5.5; `code/replies.mjs` run on the production database (read only) for real leak counts; check whether `tool_choice: 'required'` works through OpenRouter; eval cases opened on a page (`about`), including the 31st backlog task | measuring 8, 11 | S |
| 1 | Prompt: refs in tool arguments only, the glossary; `speakable`; lengths as "1h30"; stable refs per conversation, as `board.reach` | 5, 6, 7, 11 | S |
| 1b | `Subject { eventId }`; subject columns on `agent_message`; related-conversation query; `?taskId=` on the list; `AgentCubit` past per subject; the last 3 exchanges for the model; `read_conversations { here }` | 14, 15 | S–M |
| 2 | Two-text refusals for the four that reach people, as server `Choices` | 6, 3 (partly) | S |
| 0b | `answer` with its blocks and `toA2ui` on the server only; eval F (fixed layout) vs C (model composes) on the cases plus 6 open ones; golden PNGs from a bare `AgentSurface` for the pairwise judge | deciding C vs F | M |
| 3 | A2UI envelope + catalog (`Caption`, `Plan`, `Choices`, `DayPeek`, `Cards`) + `AgentSurface`; steps under Detalhes; optional caption | 1, 2 | M |
| 4 | `answer` replaces `propose_plan` (C or F, from 0b); the `choose` action; `tool_choice: 'required'` | 3, 4 | M |
| 5 | Project index on the board, `read_cards`, `ProjectPeek`, project on day cards | 9 (read) | S–M |
| 5b | Notes on the board (the `notas` mark), `read_cards` on any ref, the `note` gesture and `new.notes` for tasks and blocks | 10 | S |
| 6 | Undo as a snapshot diff in `make()`; `revive` on the three stores, with the delete→undo→identical test; then `edit`, `done`, `remove` for tasks and blocks; new `PlanChangeKind`s; the bulk-delete doubt | 12, 13 | M |
| 7 | `Hands.projects` + a sandbox `ProjectsService`; `new_project`, `project`, `note` on projects, `new.project`; `remove_project` last (Decision 7) | 12 (projects), 10 | M |

Run `npm run eval:agent` before merging each of phases 1–7, as
`product/spec/agent.md` asks. Phases 1b and 6 also change
`product/spec/agent.md` ("Nothing is removed", "it reads notes and never
writes them", "Each opening of the sheet starts a new conversation" stays).

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
- Chaganti, "Human-in-the-loop with function approvals in Microsoft Agent Framework": `approval_mode`, pending `user_input_requests`, approve and resume; the model isn't told. <https://ravichaganti.com/blog/human-in-the-loop-with-function-approvals-in-microsoft-agent-framework/>
- Alqithami & Alzahrani, "Who Can Undo the Agent? Redressability as a First-Class Safety Property for Tool-Using AI Agents" (AIES 2026): guardrails 4.58/24 vs traces 19.21/24 on redressability; avoiding harm ≠ being able to undo it. <https://ojs.aaai.org/index.php/AIES/article/view/43130>
- LangChain, "Memory" (concepts): thread-scoped short-term memory, namespaced long-term memory, semantic vs episodic. <https://docs.langchain.com/oss/python/concepts/memory>
- The previous RFC, whose contract this keeps (the model says what was meant, the server decides): [2026-10-16-agent-reliability](../2026-10-16-agent-reliability/README.md)

**Unverified.** The exact v0.9 component field names in §5.2 (the spec
page gives only a `Text` example). Whether `a2ui_core` can be used without
`genui`. Whether OpenRouter passes `tool_choice: 'required'` through to
the configured model. The "a2" reply itself, which is not in the dev
database. Phase 0 checks the first three, and the production read checks
the last. From the revision: the approval pattern (§4.8) comes from a
blog post about Microsoft Agent Framework, not from its own docs.
RedressBench (§4.9) was rated by a single validator and tested GPT-4.1
and Llama 3.1 8B, not our model. The "related conversation" JSONB
containment query (§5.7) hasn't been measured on Neon, and may need a GIN
index on `agent_message.plan`.
