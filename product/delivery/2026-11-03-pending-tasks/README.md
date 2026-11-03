# Pendentes: the day in the corner, a piece at a time, one drag between all

> Issue [#83](https://github.com/pietroid/lunna/issues/83), **mockup track**
> (it changes the pending card, adds a sheet on play, a third answer to the
> guard and drags between Plano's sections). Designed unattended; the
> person approved on the issue ("approve"); built unattended.

## 1. The prompt

From the issue, verbatim:

> **Improve UI and UX: part 3**
>
> This task is focused on pending tasks
>
> Tasks will be created according to the time it has. If we fill in more subtasks that actually increase the total time, we just consider the sum of the subtasks.
>
> This should reflect on the bar of pending tasks. We just consider green those sum of time which were done. The red bar stays the same about the proportion of the end time.
>
> If a task is delayed, we should label it as urgent and the bar will always be red, and the color will change, etc.
>
> The deadline must be at the top right as the time is for tasks. And we should be like 05/Nov when the week is not this one or quinta-feira/terca feira, etc for the same week (or today), or if delayed "para ontem". Also, pending tasks should have +1 day and -1 day always.
>
> Also, when hitting play on a pending task, if the previewed task is longer than 1 hour, it should ask how much I want to tackle with a dialog, 30 min, 1h or talk to lunna.
>
> # Management of partial task completion
>
> Here the logic splits: If I have a task that has no subtasks, we should be able to split it as much as we can. The mechanism basically is that it will automatically create a subtask for that time that will fill in the time that I have asked. That way we can see the block in the in progress and also inside the task. If I take the full task, it will not create a subtask.
>
> For things that already have a subtask the dialog will actually confirm if I want to do X next subtask.
>
> # Moving between pending and now
>
> I should be able to drag between pending and now, as well as para depois too (and even em seguida). They are all interchangeable. But with some caveats:
>
> - When moving something to in progress (or tapping play, the same thing) and something is already in progress it will ask what should I do with the current task (finish or move that to later or pending)
> - When moving something out of in progress and to any other place, it is clear what this means so no popup
> - When moving to in progress or hitting play when the agora is vacant, it will just play along

The design was reviewed on the issue, and the person replied:

> Remove the icons from the buttons, they are too ugly

and then, on the revised design:

> approve

## 2. The design

![The board](img/mockup-board.png)

The screens one by one, for a phone: [1](img/mockup-1.png) ·
[2](img/mockup-2.png) · [3](img/mockup-3.png) · [4](img/mockup-4.png) ·
[5](img/mockup-5.png). The pins are in [board.json](board.json). The real
app (Lunna) draws them through `app/lib/pending_tasks_preview.dart`: Plano
on the demo's day at 10:00 (a Tuesday), with five canned tasks.

### The rules

- **A task's time is the larger of its own and its tasks' together.**
  Written down with 5 h, given tasks of 45 min + 1h30 + 2 h + 2 h, it is
  6h15. The green of the bar is the minutes of the tasks done over that
  whole; the red is the share of its working days gone, as today.
- **Urgent means past its day.** The card takes `urgentFill`, the corner
  says *para ontem* in the danger ink, the line under the name starts with
  *Urgente*, and the red fills the whole bar (the green still drawn over
  it, so what was done shows). Behind pace but not past its day is no
  longer urgent: the red showing past the green already says it.
- **The day is in the corner**, where a task with an hour shows its hour:
  *hoje*; the weekday in full in this week (Monday to Sunday),
  *quinta-feira*; the date in another week, *12/nov*; *para ontem* once
  it is past. No deadline, nothing in the corner.
- **−1d +1d ✓** on every pending card, replacing −10 +10. The length
  follows the tasks now, so the step that matters on a pending card is
  its day. −1d is faded with no deadline.
- **Play asks when what would begin is over an hour.** With no tasks of
  its own (what it still owes, say 2h30): *30 min*, *1 h*, *Tudo · 2h30*,
  *Falar com a Lunna*. A piece writes a task of that length into it and
  begins that, so the piece is on Agora and inside the task; *Tudo*
  writes nothing. With tasks: *Começar Roteiro do vídeo?*, its parent and
  length, *Começar* or *Falar com a Lunna*. An hour or less begins at once.
- **Agora, Em seguida, Pendentes and Para depois are one drag.** Let go on
  Agora is play (and the sheet above may ask); out of Agora to any other
  section never asks. Let go on Agora while something runs asks what of
  the running one: *Concluir o atual*, *Pausar em Pendentes*, *Mandar para
  Para depois*. On a vacant Agora it just begins.

### Decisions (the pins)

| Pin | Label | Decision |
|-----|-------|----------|
| 1A | Prazo no canto | Where a task with an hour shows its hour: hoje; the weekday in full this week (quinta-feira); 12/nov in another week; para ontem once past, in the danger ink. |
| 1B | Urgente = passou do dia | Past its day: urgentFill, 'Urgente ·' before the time done, and the red runs the whole bar with the green still over it. Behind pace alone no longer tints the card. |
| 1C | −1d +1d ✓ | On every pending card, replacing −10 +10: they move the deadline a day (shiftDeadline). −1d is faded with no deadline. Agora keeps −10 +10. |
| 1D | Soma das tarefas | The whole is the larger of the task's own time (5h) and its tasks' together (6h15). Green: the minutes of tasks done over that whole. Red: working time gone, unchanged. |
| 1E | Play pergunta > 1h | Play begins at once when what would begin is an hour or less; over that, the sheet of screens 2–3. |
| 2A | 30 min em destaque | The pieces: 30 min (accent, the sheet exists to take a piece) and 1h. A piece writes a task of that length into it, titled with its name, and begins it: on Agora and inside the task. |
| 2B | Tudo · 2h30 | The whole of what it owes, no new subtask. |
| 2C | Falar com a Lunna | Text only, as every button of the sheet: opens the conversation with this task as its 'about'. |
| 3A | Nomeia a próxima | The next subtask (the queue's first, else the backlog's), its parent and length. Asked only when it is over an hour. |
| 3B | Começar | Text only, accent: begins that subtask (ArtifactPlayed), as today. |
| 3C | Ou conversar | Falar com a Lunna, as on screen 2. Cancelar closes. |
| 4A | Solte para começar | Only Agora draws itself as a target: the running card fades under an accent outline. Letting go here is play (and screens 2–3 may ask). |
| 4B | Cartão carregado | Long-press any task card (not an event) to carry it; it leaves a gap where it was (Mapa astral left Pendentes). |
| 4C | Entre seções, sem pergunta | Out of Agora to any section never asks: into Pendentes pauses it, into Para depois sends it to the backlog, into Em seguida queues it next. |
| 5A | O que fazer com ela? | The same GuardSheet, on Plano and the calendar; its three answers are text only. On a vacant Agora nothing asks: it just begins. |
| 5B | Concluir | Finishes the running one, which gives its hour away (solve_current). |
| 5C | Pausar em Pendentes | New pause_current: it stops owing what it had left and stays begun, so it waits in Pendentes. |
| 5D | Para depois | New later_current: back to the backlog. 'Deixar para depois' (next in the queue) goes. |

### References

Drawn from known patterns, not browsed (no Mobbin session here):
**Things 3** (the deadline flag in the row's corner, *Today* and weekday
names this week, a date beyond), **Sunsama** (on starting a task, the
"how long are you working on this now?" prompt, and dragging tasks between
*Today* and the backlog), **Toggl Track** (the running entry replaced by a
new one asks nothing; here it asks because a task in progress has work it
owes).

### Decided unattended

- **Urgent = past its day** only. The issue's "delayed" read as late on
  the deadline; behind pace stays visible in the bar but no longer tints
  the card. Sorting keeps urgent ones first, then the most behind.
- **−1d +1d replace −10 +10** on Pendentes ("always"); the length is
  edited on the task's page or follows its tasks. Agora keeps −10 +10.
- **The week runs Monday to Sunday**, as `weekdaysShort` does. Tomorrow
  is its weekday's name, not *amanhã*, as the issue lists.
- **The piece is a task of the task, titled with its name**
  ("Proposta para a Moinho"), the length picked; it takes its turn
  first in the task's tasks. Once the task has a piece it has tasks, so
  its next play is the second kind of sheet.
- **Over an hour** counts the next task (with tasks) or what is owed
  (without), never the whole task.
- **30 min is the accented choice**: the sheet exists to take a piece.
- **The guard's three answers** replace the two (*Deixar para depois* is
  gone): pause keeps it begun, so it waits in Pendentes; Para depois puts
  it in the backlog. The same sheet answers on the calendar.
- **Only Agora draws itself as a target** while a card is carried (the
  outline and *Solte para começar agora*); the other sections open a gap
  where the card would land, as Lista did.
- **No icons on the sheets' buttons** (the review's reply): *Começar*,
  *Falar com a Lunna*, *Concluir o atual*, *Pausar em Pendentes* and
  *Mandar para Para depois* are text only, the accent alone marking the
  one offered. Read as the buttons of the two sheets: the guard's heading
  keeps its timer (it is not a button), the cards keep their play and ✓
  (controls drawn on every card, not buttons with a label), and *Solte
  para começar agora* keeps its play (a label).
- **Falar com a Lunna** opens the conversation with the task as its
  `about`, as the notes' bar does.

### Open questions, as the build answered them

The approval left both open; the build took these and lists them under
section 3's *Decided unattended*:

1. A loose task that is not pending, over an hour: **its play does not
   ask**. A piece is a task written *inside* the task, and a loose task
   has no inside (one level: only a delivery has tasks). Every
   **delivery's** play asks, wherever it is drawn (Pendentes and Para
   depois).
2. Out of Pendentes into Para depois: **yes, it stops being begun** (a
   delivery is stopped, `ArtifactsCubit.stop`; a loose task loses
   `pending`), keeping what was done.

## 3. What was built

### The real build, both brands

Drawn by `app/lib/pending_tasks_preview.dart` (deleted afterwards) over
the real `HomePage`, `ArtifactsCubit` and `TimelineBloc`, on the demo's
day at 10:00, a Tuesday. Scene 4 is a **real long press and drag**, sent
as pointer events, not a drawing of one.

**Lunna**

![Lunna](img/build-lunna.png)

**Focus**

![Focus](img/build-focus.png)

1. Pendentes: the day in the corner (*para ontem* in the danger ink,
   *hoje*, *quinta-feira*, *12/nov*), −1d +1d ✓, the urgent card, and a
   loose task paused off the day (*Falta 40 min*, −10 +10 ✓).
2. Play on *Proposta para a Moinho* (no tasks, 2h30 owed).
3. Play on *Vídeo do lançamento* (next task 1h30).
4. *Proposta para a Moinho* held and carried over Agora (it leaves a gap in Pendentes).
5. Let go while something runs: the guard's three answers.

### The contract

- **A delivery's time is the larger of its own and its tasks'
  together.** The server's `minutes` on the wire is `max(own, Σ tasks)`
  (`viewOf`), so the bar, the schedule, goals and the agent's board all
  read the same whole; the own minutes stay stored.
- **Urgent is past its day** (`isUrgent`), nothing else.
- **Play with a piece**: `POST /tasks/of/:id/play { minutes }` (5–480):
  with no task left, the task written is that long (its name) and begins;
  the delivery's own time is unchanged, so the next play owes the rest.
- **Pending is a fact on the task**: `task.pending_at` (migration
  `0020`), set by `move { backlog: true, pending: true }` and by the
  guard's `pause_current`, cleared by any other move. A pending task is
  in the backlog, drawn in Pendentes (`BacklogCard.pending`).
- **The guard has three answers**: `solve_current`, `pause_current` (the
  running task stops owing what it had left, top of the backlog,
  pending), `later_current` (the same, not pending). `postpone_current`
  stays for older apps. A fixed block is moved by none of them.

### Server

| File | What changed |
|------|--------------|
| `src/db/schema.ts`, `drizzle/0020_lonely_kree.sql` | `task.pending_at` |
| `src/tasks/*` | `Task.pendingAt`, both stores |
| `src/events/timing.ts`, `request.ts`, `dto/` | `pause_current`, `later_current`; `pending` on a move (backlog only); `requirePiece`; `PlayArtifactDto` |
| `src/events/event-layout.service.ts` | the two answers (through `_shelve`), `pendingAt` set and cleared, `playArtifact(piece)` |
| `src/events/tasks.controller.ts` | `POST /tasks/of/:id/play` reads `{ minutes }` |
| `src/events/timeline.service.ts`, `entities/` | the backlog card's `pending` |
| `src/artifacts/artifacts.service.ts`, `src/agent/board.ts` | the whole is `max(own, Σ tasks)` |

No new route, so no new analytics row (`artifact_played` and the move's
event already count them; no body is sent).

### App

- `lib/plan/view/plan_drag.dart` (new): `PlanSection`, `PlanCarry`
  (`CarryCard`, `CarryDelivery`), `dropOnPlan` (what a drop on each
  section does), `PlanDraggable`, `PlanDropTarget`, `PlanDropGap`.
- `lib/plan/view/home_page.dart`: each section a drop target, every task
  card (not a fixed block) held to carry; Pendentes is drawn while a card
  is carried even when empty, so it can be dropped on.
- `lib/plan/view/plan_items.dart`: `Pending` (`PendingDelivery`,
  `PendingTask`), `PendingTaskCard`; Para depois's deliveries play through
  `playPending` too.
- `lib/plan/view/play_sheet.dart`: `PlayPiece` sends its minutes,
  `PlayTalk` opens the agent's conversation about the delivery
  (`AgentSubject.artifact`), `playAsks`.
- `packages/timeline`: `TimelineEvent.pending`, `EventMoved.pending`,
  `ArtifactPlayed.minutes`, the repository's two bodies; the guard sheet
  as designed.
- `packages/artifacts`: `isUrgent` is past its day; `dueLabel`.
- `l10n`: `pendingTaskLeft`, `planDropHere`.

### Tests

- Server: `events.controller.spec.ts` 129 (new: pause into Pendentes,
  Para depois, a pending drop and back, a pending drop refused off the
  backlog, the piece, a piece refused); `artifacts.controller.spec.ts` 22
  (new: the whole is the larger).
- App `test/plan/home_page_test.dart` 11 (new: the loose pending task,
  urgent and the corner, the piece sheet, the next-task sheet, drags to
  Agora, into Pendentes and to Para depois).
- `packages/timeline` 181 + `guard_sheet_test.dart` (three answers, text
  only); `packages/artifacts` 62 (new `dueLabel` cases, urgency updated:
  behind pace is no longer urgent).
- `.tool/check`: see the last line of this section.

### Where the build differs from the mockup

- **Scene 4** is a real drag: the card under the finger is a plain card
  with the task's name, not the full `PendingCard` the mockup drew (the
  feedback layer has none of the page's blocs).
- **The loose pending card** has no bar: the work done before a pause is
  not kept (the paused block's hour is removed, as pausing always did),
  so it says what it still owes.
- **Em seguida** is a target only when it is drawn (something comes
  next).

### Decided unattended

- Q1 and Q2 above, as answered there.
- A delivery's task carried into Pendentes goes back to its delivery's
  backlog; its delivery is begun if it was not (its day asked first when
  it has none, `showStartSheet`).
- Pausing (the guard or a drop) puts the task at the **top** of the
  backlog, so it is the first one Para depois or its delivery shows.
- `postpone_current` kept on the server for older apps.

`.tool/check` passes: `app-analyze`, every touched package under both brands (agent, analytics, api_client, app_ui, artifacts, cycle, notifications, timeline), the server's eslint, tsc and tests. The first run failed only on prettier in the files this build wrote; `eslint --fix` fixed it.

## 4. How to turn it on

Nothing to set. The migration (`0020`, one nullable column) runs on the
server's boot. An app older than this build never sends the new answers
or bodies and keeps working; a pending task drawn by an old app is simply
in Para depois.

## 5. Cost and time

Measured by the queue: see the pull request. No spend outside Claude: no
model was called (no agent eval).
