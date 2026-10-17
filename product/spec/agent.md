# The agent

> Moved out of [AGENTS.md](../../AGENTS.md) to keep every session's context
> small. It is binding the same way: read it before changing this feature.

The agent (named after the brand: "Pergunte à Lunna", "Pergunte ao
Focus") reads the day and proposes changes to it. It runs inside the Nest
server (`server/src/agent/`) and calls a model through OpenRouter
(`OPENROUTER_API_KEY`, `OPENROUTER_MODEL`; with no key, `POST /agent/turn`
answers 503 and nothing else changes).

**Reads run, writes are only ever proposed.** The model has three tools:
`read_timeline` (days not already in its context), `read_conversations`
(earlier conversations, by words or day) and `propose_plan`. There is no
tool that writes. The design behind this is the RFC
[2026-10-16-agent-reliability](../research/2026-10-16-agent-reliability/README.md).

**The model says what the person meant; the server schedules.** Every turn
starts from one read of the day, the **board** (`board.ts`): each card under
a short ref (`t3` a task, `e1` an event, `b2` the backlog), a date table
(hoje, amanhã, the next six days, today marked over once its working day
is), the cards of today, tomorrow, the day on screen and any card the request
names, the backlog and the free room. It is written as the last user message,
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

**The dry run is the apply.** `propose_plan` makes the gestures on a sandbox
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

**One call when it can.** The model writes its reply inside `propose_plan`;
when the plan holds and pushes nothing, that reply ends the turn. Refusals
and pushes go back to it. Each turn logs `agent.turn` on its trace: calls,
tokens (cached included), cost and ms.

**Failures say what they were.** Every agent route answers an error as
`{ message, kind, traceId }`: `model_down` (OpenRouter erred or timed out,
twice: 20 s each, one retry), `model_empty` (an empty answer, twice),
`refused` (the server's own words), `drift` (the day changed under the plan;
nothing was made), `bug`. The app says each its own way and shows the trace
code under Detalhes; Tentar de novo resends the last request, except after
a refusal.

| Route | What it does |
|-------|--------------|
| `POST /agent/turn` | `{ conversationId?, messages, day? }` → `{ conversationId, reply, steps, plan?, options }`; writes the turn down, changes nothing on the day |
| `GET /agent/conversations?before=&limit=` | earlier conversations, most recent first, for the person to read back |
| `GET /agent/suggestion` | the first backlog task that fits in the room left today, as a plan; no model |
| `POST /agent/plans/:id/apply?days=` | the timeline, plus `touched`: the ids it changed; a plan or a quick reply's plan alike |
| `POST /agent/plans/:id/undo?days=` | the timeline; the plan can be applied again |

**A conversation is its own context.** Every turn is written to
`agent_message` (`ConversationStore`: Postgres, memory in tests), keyed by a
`conversationId` the server hands out on the first turn. The model is sent
only the conversation being had; the past reaches it only through
`read_conversations`. Each opening of the sheet starts a new conversation
(`AgentCubit.open`); the ones before are above it in the same list, out of
sight until it is pulled down, dimmed and read only, each under the day and
hour it began, their plans one line (aplicado, desfeito, não aplicado).

On the app, the ask bar sits beside the + on Tempo and opens the sheet.
The suggestion is drawn above the list, and "Agora não" rests it for 24
hours on the device. Applying replaces the day
(`TimelineReplaced(undoable:)`); the cards it changed are drawn like any
others. **Desfazer** (`UndoChip`) sits on the Lista/Calendário row while
`TimelineState.undoable` holds the plan: it does not time out, and any
change made by hand forgets it, since undoing restores the cards as they
were before the plan.

## Evals

`npm run eval:agent -- --model <ids> --k 4 --budget 0.5` (in `server/`) runs
`src/agent/evals/cases.ts` against a real model through OpenRouter: each case
a day in memory, a frozen minute, what the person says, and a check on the
day left after Aplicar (or that it asked, or that it only answered). It
reports pass^k (cases that passed every run), pass@1, p50/p95 latency, calls
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

The microphone on the ask bar opens the sheet already recording
(`showAgentSheet(listen: true)`); in the sheet, an empty composer offers it.
While recording, `VoiceCubit` writes the words into the composer as they are
heard (settled in ink, still provisional in ink3). Silence never sends: a
session the platform ends after a pause (Android) is followed by another,
and their words are joined; one that ends within a second having heard
nothing failed (no microphone, as on a simulator) and is not restarted.
`SpeechVoiceRecognizer` runs one plugin call at a time, and waits a moment
after a session ends before the next: the iOS plugin crashes when two
calls touch the audio engine at once. The recording ends on ↑ (send), × (discard),
tapping the words (to correct them by keyboard) or at one minute. A message
that was spoken carries `UserEntry.voice`, its length, shown as "por voz",
and kept on the device. A refused microphone, or a device with no
recognizer, is said in the composer and the microphone is no longer offered.
