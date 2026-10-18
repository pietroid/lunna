# The agent

> Moved out of [AGENTS.md](../../AGENTS.md) to keep every session's context
> small. It is binding the same way: read it before changing this feature.

The agent (named after the brand: "Pergunte à Lunna", "Pergunte ao
Focus") reads the day and proposes changes to it. It runs inside the Nest
server (`server/src/agent/`) and calls a model through OpenRouter
(`OPENROUTER_API_KEY`, `OPENROUTER_MODEL`; with no key, `POST /agent/turn`
answers 503 and nothing else changes).

**Reads run, writes are only ever proposed.** The model has four tools:
`read_timeline` (days not already in its context), `read_conversations`
(earlier conversations, by words or day), `read_cards` (a project whole, or
a card's notes) and `answer`, which ends every turn. There is no tool that
writes. The design behind this is the RFC
[2026-10-16-agent-reliability](../research/2026-10-16-agent-reliability/README.md).

**The model says what the person meant; the server schedules.** Every turn
starts from one read of the day, the **board** (`board.ts`): each card under
a short ref (`t3` a task, `e1` an event, `b2` the backlog, `d1` a done task),
a date table (hoje, amanhã, the next six days, today marked over once its
working day is), the cards of today, tomorrow, the day on screen and any
card the request names, the backlog (its first 30), the index of open
projects (`p2 · Tese · due 30/11 · 6 open tasks, 2 with an hour`), and the
free room, in the app's lengths ("1h30"). Each card names its project.
**A ref means the same card for the whole conversation**: the server keeps
an `id → ref` map per conversation (in memory), and a card it has not shown
yet gets the next number of its kind. `board.reach(task)` hands a ref to a
task off the board (the 31st of the backlog, a done one), so `read_cards`
on a project and the page's context name every task by a ref the gestures
accept. It is written as the last user message,
right before the request; the system prompt and tools stay byte-identical.
The model never sees a UUID, never computes a date and never works out an
hour from a place.

**Every change is a gesture the person could have made by hand, and leaves
the day as that gesture would** (`gestures.ts`):

| Change | Arguments | What the server does |
|--------|-----------|----------------------|
| `place` | `ref` or `new`, `after`/`before` refs | a drop between those cards: a place in the list (`createTask`/`moveTask` with `index`, no anchor); right under a card that keeps an hour, that card's end plus the pause, as a drop there |
| `at_hour` | `ref` or `new`, `day`, `time` | a drop in free room: an anchor for a task, the hour itself for an event (`editEvent`) or a new fixed block (`new.fixed`, `createEvent`) |
| `first_free` | `ref` or `new`, `day` | the first free stretch of that day long enough, then `at_hour` |
| `to_backlog` | `ref` or `new` | into Depois eu priorizo, at its end |
| `swap` | `ref`, `with` | `swapTasks` |

`day` is `hoje`, `amanhã`, a weekday, or YYYY-MM-DD, within 14 days; the
server resolves it and says what it came to ("Amanhã é sáb 17/10") in the
steps. Nothing begun is moved, nothing goes into the past, a task's hour
stays inside the working day, and an event only ever takes an hour. Nothing
is removed.

**The dry run is the apply.** A plan block makes the gestures on a sandbox
copy of the day (`sandbox`: memory stores seeded from the rows just read, a
throwaway `EventLayoutService`), reads the day it leaves, and draws the plan
from it: each change's hour, and `pushed`, the tasks the plan does not name
that would start later. Aplicar makes the same gestures, through the same
code, on the real day, so a plan that held cannot fail for a rule that
lives in only one of them. Refs are kept as ids and places as the cards
around them, so a plan applied minutes later lands as the drop would then.

**An hour asked for is kept, and what it pushes is asked about.** A task at
an hour something already keeps would land later: that is refused, naming
the card in the way, so the model asks. When a plan pushes tasks, the
answer goes back to the model to ask about them; the card shows them and
its buttons become Outro horário / Mover.

**Doubts are found by the server, and asked once.** Something new named
like a card already on the day or in the backlog (same words, contained, or
close by trigrams) does not become a plan: the reply is one question ("Você
já tem Dentista hoje às 16:00. É esse que vai para amanhã às 09:00, ou é
outro compromisso?") and two **quick replies** ("Mover o de hoje", "É outro,
marcar mais um"), each carrying its own plan. A tap applies that plan with
no other turn; typing is always there underneath. A doubt replaces the
plan, never follows it. The model asks the doubts only language can see.

**Nothing is assumed silently.** A length nobody said, "today" for a day
nobody named, the end of the queue for a place nobody named: each goes on
the plan as `assumed` and the card says it ("Assumi 30 min"). Something new
with no hour said gets an hour the model proposes from the free room, with
its reason in the reply, and a **Deixar para depois** quick reply that puts
it in the backlog instead. Answers to one question are exclusive: once one
plan of a group is applied, the others are refused.

**One call when it can.** An `answer` whose plan holds ends the turn;
only a refusal, or an answer with nothing to draw, goes back to the model
(at most four round trips). Each turn logs `agent.turn` on its trace: calls,
blocks, leaks, tokens (cached included), cost and ms.

**Failures say what they were.** Every agent route answers an error as
`{ message, kind, traceId }`: `model_down` (OpenRouter erred or timed out,
twice: 20 s each, one retry), `model_empty` (an empty answer, twice),
`refused` (the server's own words), `drift` (the day changed under the plan;
nothing was made), `bug`. The app says each its own way and shows the trace
code under Detalhes; Tentar de novo resends the last request, except after
a refusal.

| Route | What it does |
|-------|--------------|
| `POST /agent/turn` | `{ conversationId?, messages, day?, about? }` → `{ conversationId, ui, reply, steps, plan?, options }` (`ui` the A2UI surface; the rest for older builds); writes the turn down, changes nothing on the day |
| `GET /agent/conversations?before=&limit=` | earlier conversations, most recent first, for the person to read back |
| `GET /agent/suggestion` | the first backlog task that fits in the room left today, as a plan; no model |
| `POST /agent/plans/:id/apply?days=` | the timeline, plus `touched`: the ids it changed; a plan or a quick reply's plan alike |
| `POST /agent/plans/:id/undo?days=` | the timeline; the plan can be applied again |

**A conversation opened from a page is about it.** The bar also sits at the
foot of a task's notes and a project's (`NotesDock`); a conversation opened
there carries `about: { taskId }` or `{ projectId }` on every turn
(`AgentCubit.open(about:)`). The server writes it after the board: the
task's line (its ref when it is on the board) and its notes, or the
project's name, deadline, notes and tasks; the model is told "isso" means
it. Notes are cut at 2000 characters. A subject that is not the person's is
refused (404, `refused`, "Não encontrei essa tarefa."), anything else that
is not one is a 400. The agent still only changes the day: it reads notes
and never writes them.

**A conversation is its own context.** Every turn is written to
`agent_message` (`ConversationStore`: Postgres, memory in tests), keyed by a
`conversationId` the server hands out on the first turn. The model is sent
only the conversation being had; the past reaches it only through
`read_conversations`. Each opening of the sheet starts a new conversation
(`AgentCubit.open`); the ones before are above it in the same list, out of
sight until it is pulled down, dimmed and read only, each under the day and
hour it began, their plans one line (aplicado, desfeito, não aplicado).

On the app, the ask bar and the + are one row, centred at the foot of
Tempo (`AskDock`); the lists leave room under their last card for it.
Tapping the bar opens the sheet empty, on the field, keyboard up: no
welcome and no suggested questions.
The suggestion is drawn above the list, and "Agora não" rests it for 24
hours on the device. Applying replaces the day
(`TimelineReplaced(undoable:)`); the cards it changed are drawn like any
others. **Desfazer** (`UndoChip`) sits on the Lista/Calendário row while
`TimelineState.undoable` holds the plan: it does not time out, and any
change made by hand forgets it, since undoing restores the cards as they
were before the plan.

## The answer is a surface

**The model composes, the server binds.** `answer { caption?, blocks[] }`
ends every turn. Each block names what to show, never what it says:

| Block | The model chooses | The server fills or checks |
|---|---|---|
| `caption` (one) | the words, ≤ 80 chars, only for what the blocks can't show | `speakable`; longer is dropped |
| `plan { data, changes }` (≤ 1) | the gestures | the dry run, as above; a refusal goes back to the model |
| `choices { options: [{label, changes? \| say?}] }` (2–3) | labels, and each one's plan or words | each plan its own dry run, exclusive with the plan; a failing one is dropped |
| `day { day, from?, to?, free? }` | which day and hours | the cards and free stretches of that slice |
| `cards { refs, title?, notes? }` (≤ 8) | which cards, the order, the heading | title, hour, length, project, notes |
| `project { ref }` | which project | `ProjectPeek`: counts, deadline, the next 3 open tasks (hour first) |
| `focus: true` (any, one) | what matters most | drawn first |

At most 6 blocks; a block that breaks a limit is dropped and the rest
drawn; only an answer left with nothing goes back to the model. Headings
and labels are cut at 40 characters. A plan that pushes tasks ends the turn
like any other: the card shows what moves and asks. A doubt replaces the
answer with its question and its two choices. Plain text from the model
(it ignored the tool) becomes a caption.

**Nothing the person reads has a ref.** `speakable(text, board)`
(`speech.ts`) replaces every ref the board knows with its title and
"backlog" with "Depois eu priorizo", on the caption, headings, labels and
words to say, and the turn logs `agent.leak` with the count. The prompt asks
for the same; `speakable` is the guarantee.

**The wire.** `toA2ui` (`answer.ts`) writes one A2UI v0.9 surface per turn
against our catalog (`https://lunna.pietroteruya.dev/a2ui/v1/catalog.json`):
`createSurface`, `updateComponents` (a `Column` root, then `Caption`,
`Plan`, `Choices`, `DayPeek`, `Cards`, `ProjectPeek`, each bound by path to
its data) and `updateDataModel`. Actions: `apply`/`adjust` on the plan
(`{planId}`), `choose` on each option (`{planId}` or `{say}`). The app reads
it in one place, `AgentSurface.decode`, and draws a component it does not
know as a caption when it has a text. Changing A2UI version is those two
files. `reply` is still sent, the caption or one line per block written by
the server: it is what the conversation keeps and what older builds draw,
with `plan` and `options` (only the plan-carrying choices) for one release.

**In the app.** A choice with a plan applies it, as quick replies did; one
with `say` sends its words as the person's next message, and only on the
latest answer. Steps are folded under *Detalhes*. *Abrir projeto* on a
`ProjectPeek` opens its page through `AgentLinks`, which the shell provides
(the agent package can't import projects); on that project's own page, and
on pages pushed over the shell, it is not offered.

## Evals

`npm run eval:agent -- --model <ids> --k 4 --budget 0.5` (in `server/`) runs
`src/agent/evals/cases.ts` against a real model through OpenRouter: each case
a day in memory, a frozen minute, what the person says, and a check on the
day left after Aplicar (or that it asked, that it only answered, or that it
drew a given block). A case may say several things, the turns of one
conversation. Every run reads the model's raw words for refs and banned
words (`leak@1`), and fails when one reached the person after `speakable`.
It reports pass^k (cases that passed every run), pass@1, leak@1, p50/p95 latency, calls
per turn and cost, and with `--out` keeps the failing transcripts. It stops a
model once its cost reaches `--budget`. It costs money and is never in CI:
run it before merging a change to the prompt, the tools or the model. The
first comparison is in
[product/delivery/2026-10-17-agent-reliability](../delivery/2026-10-17-agent-reliability/README.md).

## Voice

The user can speak instead of typing. **Speech becomes text on the phone,
and only the text reaches the agent**: a spoken request is an ordinary
`POST /agent/turn`, and nothing on the server knows it was spoken.
`VoiceRecognizer` (`packages/agent/lib/src/voice/`) is the platform's own
recognizer through `speech_to_text`, in pt-BR: on the device where it has
Portuguese, in Apple's or Google's cloud where it does not. The audio never
reaches our server.

The microphone on the ask bar records on the spot, with no sheet: the row
becomes the recorder (`VoiceBar`: discard, a breathing dot, the time, the
live wave, stop), and the words rise above it in a card as they are heard
(settled in ink, still provisional in ink3). In the sheet, an empty
composer offers the microphone and draws the same recorder. There is one
recording for the app (`VoiceCubit`, provided in `main.dart`), so tapping
the card opens the sheet with the recording carrying on, and closing the
sheet leaves it on Tempo; leaving Tempo for another tab discards it.

The microphone records as soon as a finger lands on it. A quick tap
leaves it recording until stop; held for 0.4 s or longer, letting go is the
stop (`VoiceHold`, caught above the microphone, since the recorder replaces
it while the finger is down). If the permission dialog takes the finger, the
recording goes on as if tapped. Either way, **stop never sends**. It puts the
words in the field, all selected, keyboard up, to be sent, fixed or typed
over (from Tempo it opens the sheet on them, `showAgentSheet(draft:)`).
The trash discards; at one minute it stops on its own and says so. Silence
never sends: a session the platform ends after a pause (Android) is
followed by another, and their words are joined; one that ends within a
second having heard nothing failed (no microphone, as on a simulator) and
is not restarted. `SpeechVoiceRecognizer` runs one plugin call at a time,
and waits a moment after a session ends before the next: the iOS plugin
crashes when two calls touch the audio engine at once. A message
that was spoken carries `UserEntry.voice`, its length, shown as "por voz",
and kept on the device. A refused microphone, or a device with no
recognizer, is said in the composer and the microphone is no longer offered
there; tapped on Tempo's bar, it opens the sheet to say so.

### Dictation

Dictation is not the agent. At the foot of a task's notes (`EventPage.dock`)
and a project's Notas, `NotesDock` puts the bar, and beside it, where the +
is on Tempo, a microphone (`AppFab`, `AppIcons.microphone`) that writes what
is said straight into the notes: **the small microphone inside the bar asks
the agent, the big one beside it writes.**

- Each recording is a paragraph of its own, after a blank line at the end
  of the notes. The words appear as they are heard; the ones the recognizer
  may still revise are drawn in ink3 (`LiveTextController.live`, in
  `app_ui`). They are saved like typing: 800 ms after they stop changing,
  through the notes' usual route. Nothing on the server knows they were
  spoken.
- `DictationCubit` is a `VoiceCubit` with no limit, made by the dock, so it
  runs until stopped; a session the platform ends is followed by another
  and joined into the same paragraph. The recorder is the same `VoiceBar`:
  stop keeps the words, the trash takes this paragraph back out.
- One microphone: dictating cancels the agent's recording, and the agent's
  starting stops dictation, keeping what was said. A refused microphone, or
  no recognizer, is said in a snackbar.
- The dock steps aside while the keyboard is up (read off the `View`, since
  the Scaffold takes the insets out of its body's `MediaQuery`). The notes
  only take the server's copy when it differs from what they last saved and
  nothing is being dictated, so neither the echo of a save nor a refresh
  undoes words still arriving. Leaving the page saves what was heard.
