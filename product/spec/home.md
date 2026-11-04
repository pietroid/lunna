# The home: Plano

Delivered in [2026-11-01-unify-tasks](../delivery/2026-11-01-unify-tasks/README.md)
(issue #77), which replaced Feed and the old Plano of
[2026-10-28-lunna-home](../delivery/2026-10-28-lunna-home/README.md), and
made consistent in
[2026-11-04-home-consistent](../delivery/2026-11-04-home-consistent/README.md)
(#87: the skeleton, Em seguida with every hour, play asks when). The
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

No greeting, date or clock. **Until the day first arrives** (status
`initial`, or `isInitialLoad`) each section is drawn as its headings and
its cards' skeletons (`PlanSkeletonCard`, pulsing bars on the card's
fill; Agora's a line taller; Pendentes not drawn); a reload keeps the
cards on screen. From the top:

| Section | What it shows | Chosen by | Empty |
|---------|---------------|-----------|-------|
| Offer | `SuggestionCard`, the agent's one offer | `GET /agent/suggestion` | not drawn |
| Agora | heading with today's mark (`TodayTag`: "Dia 2 · dia leve", or the day's own tag); the running task as `NowTaskCard`: titled by its delivery, the task under it, pause, −10 +10 ✓, the 3 px bar. A fixed block, a task waiting to be begun and one in overtime keep `EventTile` | the card in section `agora` | the break (`AgoraIdleTile`) |
| Em seguida | a heading with **Ver calendário** beside it (`AppPillButton`, the calendar icon, pushes `DayPage`), and a queue with **no limit**: every card of the first day after Agora that has any (today, while it has some left), **its events too**, in clock order, then every task the queue puts on the days after it, under the day's name (*Amanhã*, *Sexta-feira, 30 de outubro*; `_DayOf`). Each row is its start and end as the server's layout gives them, re-read every minute and after every write, so a pause, a move or a task done early moves them all and an event never moves. A task is a `TaskCard` with play; an event is drawn as the calendar draws it (`fixedFill`, the pin in the play's room, its hours in `fixedInk`; a routine's day `routineFill` and the repeat), not carried. Later days' events stay on the calendar. Then **+ Adicionar** (`AppAddRow(dense: true)`), which writes a task right after the last task drawn (`queueEndOf`) | `PlanItems.next` | "Nada marcado daqui para a frente.", kept while a card is carried |
| Pendentes | every delivery begun and not delivered (`PendingCard`): its next task under the name, the day it is due in the corner (`dueLabel`: *hoje*, the weekday this week, *12/nov* beyond, *para ontem* once past), "1h30 de 6h15" (*Urgente ·* before it once past its day), −1d +1d ✓, the pace bar at 3 px; then the loose tasks paused off the day (`PendingTaskCard`: "Falta 40 min", −10 +10 ✓) | `PlanItems.pending`: `progressGroups(...).started` minus the one running on Agora, then the backlog's cards with `pending` | not drawn, unless a card is being carried |
| Para depois | **the whole** of everything not begun (`LaterCard`), then **+ Adicionar** (`AppAddRow(dense: true)`), which writes into the backlog (`writeTask`) | `PlanItems.later`: the loose backlog in its order, then the deliveries not begun in the queue's | "Nada esperando." |

- **Play asks when, always** (#87, `askPlay`), on every task that
  waits, wherever its play is (Em seguida, Pendentes, Para depois, the
  calendar). **First sheet, when** (`PlayWhenSheet`): *Quando fazer
  Roteiro?*, what it owes under it, and only two answers:
  - ***Começar agora*** (the accent): a drop on Agora, `POST
    /tasks/:id/move { index: 0, start: true }` (`playCard`); for a
    delivery `POST /tasks/of/:id/play`, which begins its next task (the
    first the queue reaches, else the first of its backlog, else a new
    task of its name for what it still owes). Both can raise the guard,
    drawn over the page (`GuardSheet`).
  - ***Em seguida · 10:40***: the first place in the queue, right after
    what runs (`nextIndexOf`: 1 while a task runs, else 0), `move {
    index }` (`queueFirst`), at the hour of the first room after what runs
    and its pause long enough for the whole (`nextSlotOf`; the server's
    layout has the last word). For a delivery it queues its next task;
    with no task left there is nothing to queue, and the first sheet is
    skipped.

  **Second sheet, over an hour** (`kPlayAsksOver`), **how much**: after
  *Começar agora*, `PlaySheet` (*Quanto você vai fazer agora?*: *30 min*
  the accent, *1 h*, *Tudo · 2h*, and *Falar com a Lunna*); after *Em
  seguida*, `PlaceSheet` (*Quanto vai para as 10:40?*, the same pieces).
  A piece **begun** posts `move { index: 0, start: true, minutes }`: the
  server splits the task, the piece begins and **the rest is a task of
  the same name and notes at the top of Pendentes** (`pending_at`; a
  delivery's stays in it). A piece **queued** posts `move { index,
  minutes, split: true }`: the piece takes the place and **the rest stays
  where the task was** (its turn in the queue, right after the piece when
  that is the same place; its hour; the backlog; Pendentes). A piece at
  or over the task's length is the whole; outside 5–480 minutes it is
  refused in Portuguese; a task already begun is not split (400). The
  guard carries a begun piece (`guard.minutes`) and its answer posts it
  back. A delivery's next task begun in a piece goes through `move {
  start, minutes }` too; with no task, `play { minutes }` writes a piece
  into it.
- **A task already waiting on Agora begins**, without asking when
  (`beginCard`; over an hour `PlaySheet.task` asks how much): it is next
  already. Plano's Agora begins it from its own card (`EventStarted`).
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
  Let go on **Agora** is begun (`beginCard`: a loose task over an hour
  asks how much with `PlaySheet.task`; `playPending` for a delivery),
  guard and all. **Em seguida** is a queue (`PlanQueue`, a slot before
  each card and one at the end): a drop is that place in the list of
  tasks (`move { index }`), counted as a move counts, with the carried
  task taken out and the running one counted; before an event it is
  right after the last task above it (a delivery's next task, for a
  delivery). **A task over an hour not begun asks how much goes there**
  (`PlaceSheet`, *Quanto vai para as 11:25?*: 30 min the accent, 1 h,
  *Tudo*), and a piece posts `move { index, minutes, split: true }`. **Pendentes**: a
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

- **Ver calendário** (`DayPage`, `app/lib/tempo/`): the calendar
  (`TimelineList(mode: calendar)`), a back arrow, *Calendário*, the undo
  chip, the composer's +. Its play is Plano's (`TimelineList.onPlay`, so it
  asks when, and how much over an hour), and **Agora plays as Plano does**: the round
  play/pause before the title (`EventTile`, `DeliveryTile`), a waiting
  task begun from it, and the quiet row keeps −10, +10 and ✓; an event
  and a task in overtime keep the row alone. Lista mode is gone
  from the app (`TimelineModeCubit` survives only in the landing's demo).
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
  `Calendário` (`Para depois` went with its page, #87).
