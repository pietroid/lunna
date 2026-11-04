# The home: Plano

Delivered in [2026-11-01-unify-tasks](../delivery/2026-11-01-unify-tasks/README.md)
(issue #77), which replaced Feed and the old Plano of
[2026-10-28-lunna-home](../delivery/2026-10-28-lunna-home/README.md). The
app has three tabs: **Plano**, **Objetivos**, **Menu**. It opens on Plano.

## One kind of task

To the person there is one kind of thing to do: a **task**. A task with
tasks of its own is what the code still calls a delivery (`Artifact`);
the cut is between tasks and **events** (fixed blocks). Every task is drawn
by the same card (`TaskCard`, `packages/timeline`): a play button on its
left (pause while it runs; none for an event), its name, what it is under
it, its hours or length on the right. **The task's name is the title**: a
delivery's task at work is the subtitle. **One level**: a delivery's task
has no tasks.

Storage is unchanged: a delivery is still an `artifact` row and its tasks
`task.artifact_id`. Merging the two tables is the next step (see the
delivery's section 3).

## Plano (`app/lib/plan/`, `HomePage`)

No greeting, date or clock. From the top:

| Section | What it shows | Chosen by | Empty |
|---------|---------------|-----------|-------|
| Offer | `SuggestionCard`, the agent's one offer | `GET /agent/suggestion` | not drawn |
| Agora | heading with today's mark (`TodayTag`: "Dia 2 · dia leve", or the day's own tag) and *Ver o dia*; the running task as `NowTaskCard`: titled by its delivery, the task under it, pause, −10 +10 ✓, the 3 px bar. A fixed block, a task waiting to be begun and one in overtime keep `EventTile` | the card in section `agora` | the break (`AgoraIdleTile`) |
| Em seguida | a section headed as Agora is, and a queue: the cards of the first day after Agora that has any, up to four (`kNextOnHome`), each a `TaskCard` with play; an event drawn as the calendar draws it (`fixedFill`, the pin in the play's room, its hours in `fixedInk`; a routine's day `routineFill` and the repeat), not carried. Then **+ Adicionar** (`AppAddRow(dense: true)`), which writes a task right after the last task drawn (`queueEndOf`) | `PlanItems.next` | not drawn, unless a card is being carried |
| Pendentes | every delivery begun and not delivered (`PendingCard`): its next task under the name, the day it is due in the corner (`dueLabel`: *hoje*, the weekday this week, *12/nov* beyond, *para ontem* once past), "1h30 de 6h15" (*Urgente ·* before it once past its day), −1d +1d ✓, the pace bar at 3 px; then the loose tasks paused off the day (`PendingTaskCard`: "Falta 40 min", −10 +10 ✓) | `PlanItems.pending`: `progressGroups(...).started` minus the one running on Agora, then the backlog's cards with `pending` | not drawn, unless a card is being carried |
| Para depois | the first four (`kLaterOnHome`) of everything not begun (`LaterCard`), then *Abrir a lista · mais N* | `PlanItems.later`: the loose backlog in its order, then the deliveries not begun in the queue's | "Nada esperando." |

- **Play** is a drop on Agora: a loose task posts `POST /tasks/:id/move
  { index: 0, start: true }` (through `playCard`, the one play of a loose
  task: Em seguida, Pendentes, Para depois, `LaterPage`, the calendar and
  a drop on Agora); a delivery posts `POST /tasks/of/:id/play`,
  which begins its next task (the first the queue reaches, else the first
  of its backlog, else a new task of its name for what it still owes).
  Both can raise the guard, drawn over the page (`GuardSheet`).
- **Play on a delivery asks first when what would begin is over an hour**
  (`playPending`, `kPlayAsksOver`), wherever it is drawn: with no task
  left, `PlaySheet` offers *30 min* (the accent), *1 h*, *Tudo · 2h30* and
  *Falar com a Lunna*; a piece posts `{ minutes }` with the play, which
  writes a task of that length into it, titled with its name, and begins
  it. With tasks, it names the next (*Começar Roteiro?*), *Começar* or
  *Falar com a Lunna*. Talk opens the conversation about the delivery.
  Every button of the sheet is text only.
- **Play on a loose task over an hour asks too** (`playCardAsks`,
  `PlaySheet.task`), wherever it is pressed: 30 min, 1 h, *Tudo · 2h*,
  *Falar com a Lunna*. A piece posts `move { index: 0, start: true,
  minutes }`: the server splits the task, the piece begins and **the rest
  is a loose task of the same name and notes at the top of Pendentes**
  (`pending_at`), owing what is left. A piece at or over the task's
  length is the whole; outside 5–480 minutes it is refused in
  Portuguese. The guard carries the piece (`guard.minutes`) and its
  answer posts it back.
- **A delivery's time is the larger of its own and its tasks' together**
  (the server's `minutes`); the green is its tasks done over that.
- **Urgent is past its day** (`isUrgent`): `urgentFill`, *para ontem* in
  the danger ink, and the red runs the whole bar (`TaskBar.late`), the
  green over it. Behind pace alone tints nothing.
- **−1d +1d on a pending delivery** move its day (`shiftDeadline`; −1d is
  faded with no day); **✓** delivers it.
- **One drag between Agora, Em seguida, Pendentes and Para depois**
  (`plan_drag.dart`): any task card but a fixed block is held
  (`LongPressDraggable`) and its place closes. **A drop shows where the
  card lands, and nothing else**: no outline and no words, only the
  carried card's own copy at 40 % ink (`PlanDropGhost`, its name and
  length) opening at the place it would take, the cards under it making
  room; on Agora (`NowDropZone`) the copy takes the place of what runs.
  Let go on **Agora** is play (`playCard`, or `playPending` for a
  delivery), guard and all. **Em seguida** is a queue (`PlanQueue`, a slot
  before each card and one at the end): a drop is that place in the list
  of tasks (`move { index }`), counted as a move counts, with the carried
  task taken out and the running one counted; before an event it is
  right after the last task above it (a delivery's next task, for a
  delivery). **Pendentes**: a
  loose task `move { backlog: true, pending: true }` (it stops, owing
  what it had left); a delivery's task goes to its backlog and its
  delivery is begun (its day asked when it has none); a delivery not
  begun is begun. **Para depois**: `move { backlog: true }`, or a begun
  delivery stopped (`ArtifactsCubit.stop`). Out of Agora never asks.
- **The guard's answers** (`GuardSheet`, here and on the calendar):
  *Concluir o atual* (`solve_current`), *Pausar em Pendentes*
  (`pause_current`), *Mandar para Para depois* (`later_current`).
- A tap on a delivery opens its page on Pendentes; on a loose task its
  `EventPage`.
- The offer is asked for when the tab comes forward, at midnight, and on
  coming back on another day. The day is asked for on every minute while
  Plano is in front (`MinuteRefresh`), and the deliveries whenever the
  day's tasks change.

## Pages over Plano

- **Ver o dia** (`DayPage`, `app/lib/tempo/`): the calendar
  (`TimelineList(mode: calendar)`), a back arrow, *Calendário*, the undo
  chip, the composer's +. Its play is Plano's (`TimelineList.onPlay`, so a
  task over an hour asks), and **Agora plays as Plano does**: the round
  play/pause before the title (`EventTile`, `DeliveryTile`), a waiting
  task begun from it, and the quiet row keeps −10, +10 and ✓; an event
  and a task in overtime keep the row alone. Lista mode is gone
  from the app (`TimelineModeCubit` survives only in the landing's demo).
- **Para depois** (`LaterPage`): the whole of `PlanItems.later`, each with
  play. Not reorderable yet.
- **A delivery's page** (`ArtifactPage`): Pendentes is two sections,
  **Agora** (its task running, `NowTaskCard` titled by the task) and
  **Para depois** (the rest, the queue's first first, then its backlog),
  each with play; the guard is drawn over it.

## Writing a task

**The + opens the composer** (#81, `openComposer` in
`app/lib/plan/view/compose.dart`): one field, typed or spoken, read once
into one summary over the sheet (see "The composer" in
[agent.md](agent.md)), and nothing written until Adicionar. *Ajustar*
opens the creation sheet below, filled with what was read; a tap on the
calendar's empty room, its +, Em seguida's + Adicionar and the break
still open the creation sheet at that place.

The creation sheet (`writeTask`, `app/lib/plan/`): **Tarefa |
Evento** (was Flexível | Fixo) and, on a task, a **Produto** chip listing
the catalogue's kinds. A task with no product goes into Para depois (the
backlog) or where the calendar is looking; one with a product is written as
a delivery of that kind (`POST /artifacts`, its minutes from the sheet) at
the end of the queue, so it waits in Para depois too.

## The shell (`app/lib/shell/`)

- Tabs: Plano (`AppIcons.plan`), Objetivos (`AppIcons.goal`), Menu.
- **No agent bar.** One button at the foot of every tab and page, the +
  where it always was (`AskDock` at `AppFab.location`): the composer's,
  about the page it is on (a task's, a delivery's). A screen with a button
  of its own keeps it (Nova rotina on Rotina, a delivery on Produtos), and
  the notes put their dictation microphone beside it.
- **+ Subtarefa** on a loose task's page (`EventPage.onAddSubtask`) gives
  it a subtask: `POST /tasks/:id/subtasks`, the first one making it a task
  with tasks (see [artifacts.md](artifacts.md)).
- Menu holds what hung off the greeting (**Sair**) and the catalogue:
  **Produtos** (every delivery, searched and filtered by product,
  `AllArtifactsPage`) and **Novo produto** (`TypeSheet`).
- Screens reported to analytics: `Plano`, `Objetivos`, `Menu`,
  `Calendário`, `Para depois`.
