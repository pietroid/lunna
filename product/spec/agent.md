# The agent

> Moved out of [AGENTS.md](../../AGENTS.md) to keep every session's context
> small. It is binding the same way: read it before changing this feature.

The agent (named after the brand: "Pergunte à Lunna", "Pergunte ao
Focus") reads the day and proposes changes to it. It runs inside the Nest
server (`server/src/agent/`) and calls a model through OpenRouter
(`OPENROUTER_API_KEY`, `OPENROUTER_MODEL`; with no key, `POST /agent/turn`
answers 503 and nothing else changes).

**Reads run, writes are only ever proposed.** The model has three tools:
`read_timeline` (the day, with ids, wall-clock hours and `now`),
`read_conversations` (earlier conversations, by words or day) and
`propose_plan`. There is no tool that writes. `propose_plan` checks every
change against the day (the id exists, nothing begun is moved, nothing goes
into the past) and files a plan in memory (`PlanStore`, two hours); a bad
change goes back to the model as an error to answer.

**An hour asked for is kept, and what it pushes is asked about.**
`propose_plan` lays the day out again as if the plan were made (`rehearse`
in `timeline.service.ts`, the same `relayout`) and keeps on the plan the
tasks it would push later (`pushed`). The model is told to keep the hour
the person named rather than hop to another hour or day, and to ask whether
pushing is all right; the plan card shows the pushed tasks and its buttons
become Outro horário / Empurrar. A change that would not get its own hour
(an anchored task behind one already there, anything on an event) is
refused, so the model asks instead: nothing pushes an event. The user applies the
plan, and it is the server that makes each change, through
`EventLayoutService`, keeping what it needs to undo it. A plan applies
whole or not at all.

A change is one of `add_task` (anchored at its hour), `move_task` (from
the queue or the backlog), `add_event`, `move_event`. Nothing is removed.

| Route | What it does |
|-------|--------------|
| `POST /agent/turn` | `{ conversationId?, messages, day? }` → `{ conversationId, reply, steps, plan? }`; writes the turn down, changes nothing on the day |
| `GET /agent/conversations?before=&limit=` | earlier conversations, most recent first, for the person to read back |
| `GET /agent/suggestion` | the first backlog task that fits in the room left today, as a plan; no model |
| `POST /agent/plans/:id/apply?days=` | the timeline, plus `touched`: the ids it changed |
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
