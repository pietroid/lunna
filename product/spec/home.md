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
cards on screen. From the top (the Offer sits under the Agora heading, before its card):

| Section | What it shows | Chosen by | Empty |
|---------|---------------|-----------|-------|
| Agora | heading with today's mark (`TodayTag`: "Dia 2 · dia leve", or the day's own tag); the running task as `NowTaskCard`: titled by its delivery, the task under it, pause, −10 +10 ✓, the 3 px bar. A fixed block, a task waiting to be begun and one in overtime keep `EventTile` | the card in section `agora` | the break (`AgoraIdleTile`) |
| Offer (inside Agora) | `SuggestionCard`, the agent's one offer (#120): a small gray card, a title and one line, **Aceitar** (applies the plan, a spinner meanwhile), **Agora não** (dismissed; the next comes within 4 h of the working day), **Ajustar** (the agent sheet on the prepared surface). See [agent.md](./agent.md) | `GET /agent/suggestion` | not drawn |
| Em seguida | a heading with **Ver calendário** beside it (`AppPillButton`, the calendar icon, pushes `DayPage`), and a queue with **no limit**: every card of the first day after Agora that has any (today, while it has some left), **its events too**, in clock order, then every task the queue puts on the days after it, under the day's name (*Amanhã*, *Sexta-feira, 30 de outubro*; `_DayOf`). Each row is its start and end as the server's layout gives them, re-read every minute and after every write, so a pause, a move or a task done early moves them all and an event never moves. A task is a `TaskCard` with play; an event is drawn as the calendar draws it (`fixedFill`, the pin in the play's room, its hours in `fixedInk`; a routine's day `routineFill` and the repeat), not carried. Later days' events stay on the calendar. Then **+ Adicionar** (`AppAddRow(dense: true)`), which writes a task right after the last task drawn (`queueEndOf`) | `PlanItems.next` | "Nada marcado daqui para a frente.", kept while a card is carried |
| Pendentes | every delivery begun and not delivered (`PendingCard`): its next task under the name, the day it is due in the corner (`dueLabel`: *hoje*, the weekday this week, *12/nov* beyond, *para ontem* once past), "1h30 de 6h15" (*Urgente ·* before it once past its day), −1d +1d ✓, the pace bar at 3 px; then the loose tasks paused off the day (`PendingTaskCard`: "Falta 40 min", −10 +10 ✓) | `PlanItems.pending`: `progressGroups(...).started` (the delivery whose piece runs on Agora stays, its piece drawn as a yellow run, `doing`, right after the green; `paceDoing`), then the backlog's cards with `pending`. The bar is always a pace bar: with no day it is the green alone | not drawn, unless a card is being carried |
| Para depois | **the whole** of everything not begun (`LaterCard`), then **+ Adicionar** (`AppAddRow(dense: true)`), which writes into the backlog (`writeTask`) | `PlanItems.later`: the loose backlog in its order, then the deliveries not begun in the queue's | "Nada esperando." |

- **Play by strict rules** (#89, `timeline`'s `play.dart`: `playTask`,
  `beginTask`, `askHowMuch`), on every task that waits, wherever its
  play is (Em seguida, Pendentes, Para depois, the calendar, a
  delivery's page on a subtask). **The room** of an hour is the minutes
  from it to the next thing that does not move (an event, a task that
  keeps its hour, a begun task) or the working day's end, less the
  5-minute pause (`playRoomAt`); queued tasks take none of it. **An hour
  with under 20 minutes of room is never offered** (`kPlayMinRoom`): the
  first one that has is (`playFirstRoom`). Three questions, one sheet
  each, and the move posted once, after the last:
  1. **When** (`PlayWhenQuestion`, `playWhenOf`): *Quando fazer
     Roteiro?*, under it *Nada rodando agora · 4h* or *Fazendo a Lunna
     roda até 10:33 · 4h*. ***Começar agora*** (the accent; not offered
     when now has under 20 minutes of room, as inside a fixed block)
     and one later hour: nothing running, ***Daqui a 15 min · 10:15***
     (an anchor, `move { index, after }`), or ***Às 13:00*** when 15
     minutes from now has no room; something running, ***Depois de
     Fazendo a Lunna · 10:38***, the first hour after it with room,
     whether or not the whole fits (`move { index: 1 }`, plus `after`
     when that is not where the queue would put it), not offered when
     the task is next already.
  2. **The pause** (`PauseQuestion`), after *Começar agora* while a task
     runs: *Pausar Fazendo a Lunna?*, *Fazendo a Lunna vai para
     Pendentes.*, *Sim, pausar e começar* or *Não* (nothing changes). The
     answer rides on the move, `move { start: true, decision:
     'pause_current' }`, so the server raises no guard.
  3. **How much** (`PlayMuchQuestion`), measured at the hour chosen
     (now with what runs paused, the later hour, or where a card was
     dropped), on the task, or the subtask when play is a subtask's
     (`playPieces`):

     | Task | Room | Asks |
     |------|------|------|
     | over 1 h | ≥ the task | *30 min* · *1h* · *Tudo · 4h* |
     | over 1 h | 1 h to less than the task | *30 min* · *1h* · *2h13* |
     | over 1 h | under 1 h | only the room, *Fazer 40 min* |
     | 1 h or less | ≥ the task | nothing |
     | 1 h or less | less | only the room, *Fazer 20 min* |

     A piece begun posts `move { index: 0, start: true, minutes }`; a
     piece put at an hour or a place, `move { index, after?, minutes,
     split: true }`.

  **A piece splits into subtasks** (the server, `_withSubtasks`): a
  loose task becomes a task with subtasks (a delivery in storage, its
  title, length and notes, at the end of the open ones; begun when the
  piece is, or when the task waited in Pendentes), its row the piece, a
  new subtask of the same name the rest: at the top of its Para
  depois and the delivery begun, so it waits in Pendentes (#92: a queued
  piece does not leave its rest on the day either). A subtask is cut to the piece and its rest written in the same
  task. A piece at or over the length is the whole; outside 5–480
  minutes it is refused in Portuguese; a task already begun is not split
  (400).

  **The pause splits too** (`_pauseSplit`): a task that ran 5 minutes or
  more is closed at this minute and ticked off as a subtask of the
  minutes it ran, and what it owed is a new subtask at the top of its
  Para depois; under 5 minutes it is paused whole into Pendentes (as
  before). So a task's Pendentes is the sum of its subtasks still to
  do.

  A delivery's play is its next task's (`playPending`); with no task, it
  asks only how much at now and posts `POST /tasks/of/:id/play {
  minutes }`, which can still raise the guard.
- **A task already waiting on Agora begins**, without asking when
  (`beginTask`: the pause and how much still ask). Plano's Agora begins
  it from its own card (`EventStarted`).
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
  Let go on **Agora** is begun (`beginTask`: the pause while a task
  runs, then how much at now; `playPending` for a delivery). A drop
  has answered *when* by where it was let go. **Em seguida** is a queue (`PlanQueue`, a slot before
  each card and one at the end): a drop is that place in the list of
  tasks (`move { index }`), counted as a move counts, with the carried
  task taken out and the running one counted; before an event it is
  right after the last task above it (a delivery's next task, for a
  delivery). **A task not begun asks how much goes there**, by the
  table above at that place's hour (`askHowMuch`, *Quanto vai para as
  11:25?*), and a piece posts `move { index, minutes, split: true }`;
  so does a drop on the calendar's free room (`after` that hour). **Pendentes**: a
  loose task `move { backlog: true, pending: true }` (it stops, owing
  what it had left); a delivery's task goes to its backlog and its
  delivery is begun (its day asked when it has none); a delivery not
  begun is begun. **Para depois** is a queue too (`PlanQueue<Later>`, a slot
  before each card and one at the end): a loose task posts
  `move { backlog: true, pending: false, index }` (also from Pendentes), its place among the loose tasks
  (`_backlogPlace`); a delivery `ArtifactsCubit.move(id, index)`, or
  `stop(id, index)` if begun, its place among the open deliveries
  (`_deliveryPlace`). Loose tasks are drawn first, deliveries after
  (two orders), so a loose task let go among deliveries goes after the
  last loose one, and a delivery among loose tasks before the first
  delivery. A delivery's task goes to index 0 of its delivery's backlog.
  Let go on the heading, it goes first. Out of Agora never asks.
- **Swipe** (`plan_swipe.dart`, `PlanSwipe`): a `Dismissible` on every
  task card (Agora, Em seguida, Pendentes, Para depois) and every
  delivery card (Pendentes, Para depois). Right is done, left is delete,
  **each asked first** by a bottom sheet, one per gesture and kind: task
  *Concluir “x”?* (`confirmDone`, `EventFinished`) and *Excluir “x”?*
  (`EventDeleted`); delivery *Entregar “x”?* (`ArtifactsCubit.setDone`)
  and *Excluir “x”?* (`ArtifactsCubit.delete`). Cancel puts the card
  back; once confirmed it draws as nothing until the list drops it, and
  a delivery the server refused comes back. A delivery's card in Em
  seguida is its next task: the swipe acts on that task. Fixed blocks
  do not swipe.
- **The guard** (`GuardSheet`, here and on the calendar), raised by a
  road that did not ask first (a delivery's play, a fixed block
  running): the same yes or no as the pause (`pause_current`, else
  dismissed); over a fixed block, *Começar depois de Reunião?*, the
  task waiting for it. *Concluir o atual* and *Para depois* are gone
  (#89); `solve_current` and `later_current` stay on the server for
  older apps.
- A tap on a delivery opens its page on Pendentes; on a loose task its
  `TaskPage`: Notas, Pendentes and Feitas always, under the task's own
  summary (#118).
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
  each with play; the guard is drawn over it. Its subtasks drag and swipe
  (see [artifacts.md](./artifacts.md), "The task page's Pendentes").

## Writing a task

**The + opens the composer** (#81, `openComposer` in
`app/lib/plan/view/compose.dart`): one field, typed or spoken, read once
into one summary over the sheet (see "The composer" in
[agent.md](agent.md)), and nothing written until Adicionar. *Ajustar*
opens the creation sheet below, filled with what was read; *Conversar*
opens the agent sheet with the sent line and the understood plan in its
history and a blank field; a tap on the
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
- **A loose task's page** (`TaskPage`, `/evento/:id`) has the delivery's
  three tabs. Pendentes is empty with *Adicionar* (prompt sheet, then
  `POST /tasks/:id/subtasks`); the first subtask makes the task a delivery
  and the page becomes the delivery's, on Pendentes (see
  [artifacts.md](artifacts.md)). A fixed block and a finished task get
  `EventPage` alone. Pendentes' drag keeps the order it leaves until the
  delivery is read again.
- Menu holds what hung off the greeting (**Sair**) and the catalogue:
  **Produtos** (every delivery, searched and filtered by product,
  `AllArtifactsPage`) and **Novo produto** (`TypeSheet`).
- Screens reported to analytics: `Plano`, `Objetivos`, `Menu`,
  `Calendário` (`Para depois` went with its page, #87).


## The app shell (moved from AGENTS.md)

**One kind of task.** To the person a delivery is a task with tasks of
its own (one level: its tasks have none); the cut is between tasks and
events. Every task is one card (`TaskCard`): play on its left (pause while
it runs, none for an event), the task's name as the title (a delivery's
task at work under it). Play is a drop on Agora (`move { start: true }`;
a delivery's `POST /tasks/of/:id/play` begins its next task). Storage is
still `artifact` and `task.artifact_id`.

Three tabs: **Plano** (`HomePage`, the home, drawn as skeletons until
the day first arrives: the agent's one offer; Agora with today's mark,
the running task; **Em seguida**, with *Ver calendário* beside its
heading, and a queue **with no limit**: every card of the first day
after Agora, events too, then the queue's tasks on the following days
under their day, each at the hour the server's layout gives it; play on
every task, an event in `fixedFill` with the pin, then *+ Adicionar*; a
card carried to a place in it is `move { index }`, asking how much goes
there by play's rules (`move { index, minutes, split: true }`: the rest
waits in Pendentes); **Pendentes**, the deliveries
begun (their day in the corner, −1d +1d ✓ and their bar; urgent once
past their day) and the loose tasks paused off the day; **Para depois**,
the whole of everything not begun, then *+ Adicionar*; a card is carried
between the four, a drop showing only the card's quiet copy where it
lands; **play on any task that waits goes by strict rules** (#89,
`timeline`'s `play.dart`): **when** (*Começar agora*, or one later hour:
*Daqui a 15 min*, *Às 13:00*, *Depois de X · 10:38*; never an hour with
under 20 minutes of room before the next thing that keeps its hour),
**the pause** while a task runs (yes or no), **how much** (`playPieces`:
over an hour 30 min, 1h and the whole or the room; an hour or less that
fits asks nothing), then one move; **a piece splits the task into two
subtasks** on the server, and so does pausing one that ran; a task
already waiting on Agora skips *when*; see
[product/spec/home.md](./home.md)),
**Objetivos** (`GoalsPage`) and **Menu**, which opens Rotina,
**Feitas**, **Produtos** (the catalogue), sets when the day starts and
ends, and signs out. *Ver calendário* pushes `DayPage` (the calendar).
The app opens on Plano,
which asks for the offer again each time it comes forward and when a new
day begins. **The + opens the composer** (#81, `openComposer`): one
field, typed or spoken, read by `POST /agent/compose` into one summary
(a task, a task under a delivery or with subtasks, an event, a goal, or
the agent's plan), and nothing written until Adicionar; *Ajustar* opens
the creation sheet (`writeTask`: Tarefa | Evento, and a Produto chip),
which a tap on the calendar's room still opens directly. A loose task's
page has the three tabs and *Adicionar* (`POST /tasks/:id/subtasks`). See
[product/spec/home.md](./home.md).
The landing's demo shell keeps
its old three tabs (Tempo, Entregas, Menu), as the landing has three chapters. It sits in the same spot on
every tab and never animates between them (`noAnimation`).
**There is no agent bar; one round button is on every screen, in the
same place**: one `AskDock` for the tabs and one per page, floated at
`AskDock.location` (`AppFab.location`) with `AskDock.animator`, a
`DockHero` held still while pages slide under it. It is the composer's +
(found through `ComposeLauncher`, above the router), about the page it is
on, unless the screen has a button of its own (Nova rotina on Rotina, a
delivery on Produtos); the notes put the dictation microphone beside it.
A new page floats an `AskDock` too and leaves `kNotesDockClearance` under its
last row (plus `MediaQuery.paddingOf(context).bottom` on a tab, whose body
runs under the bottom bar); see "The agent" in [product/spec/agent.md](./agent.md).

**Feitas** (`/feitas`, `DoneArchivePage` over `DoneArchiveCubit`) is every
task ticked off, newest first under the calendar's day headings, searched
on the server: `GET /api/tasks/done?q=&limit=&before=&beforeId=` answers
`{ done: [card] }`, each card's `startTime` being its `doneAt`, paged by
the last one's `doneAt` and id. A tap opens `EventPage(finished:)`. A task
is ticked off only from the day (Agora's ✓, or the calendar's running
card); its page has no done control.
