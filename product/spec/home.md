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
| Agora | heading with today's mark (`TodayTag`: "Dia 2 · dia leve", or the day's own tag) and *Ver o dia*; the running task as `NowTaskCard`: titled by its delivery, the task under it, pause, −10 +10 ✓, the 3 px bar. A fixed block, a task waiting to be begun and one in overtime keep `EventTile` | the card in section `agora` | "Nada em andamento" |
| Em seguida | the first card in section `dia`, play for a task, none for an event | `TimelineState.cards` | not drawn |
| Pendentes | every delivery begun and not delivered (`PendingCard`): its next task under the name, the day it is due in the corner (`dueLabel`: *hoje*, the weekday this week, *12/nov* beyond, *para ontem* once past), "1h30 de 6h15" (*Urgente ·* before it once past its day), −1d +1d ✓, the pace bar at 3 px; then the loose tasks paused off the day (`PendingTaskCard`: "Falta 40 min", −10 +10 ✓) | `PlanItems.pending`: `progressGroups(...).started` minus the one running on Agora, then the backlog's cards with `pending` | not drawn, unless a card is being carried |
| Para depois | the first four (`kLaterOnHome`) of everything not begun (`LaterCard`), then *Abrir a lista · mais N* | `PlanItems.later`: the loose backlog in its order, then the deliveries not begun in the queue's | "Nada esperando." |

- **Play** is a drop on Agora: a loose task posts `POST /tasks/:id/move
  { index: 0, start: true }`; a delivery posts `POST /tasks/of/:id/play`,
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
  A loose task begins whole. Every button of the sheet is text only.
- **A delivery's time is the larger of its own and its tasks' together**
  (the server's `minutes`); the green is its tasks done over that.
- **Urgent is past its day** (`isUrgent`): `urgentFill`, *para ontem* in
  the danger ink, and the red runs the whole bar (`TaskBar.late`), the
  green over it. Behind pace alone tints nothing.
- **−1d +1d on a pending delivery** move its day (`shiftDeadline`; −1d is
  faded with no day); **✓** delivers it.
- **One drag between Agora, Em seguida, Pendentes and Para depois**
  (`plan_drag.dart`): any task card but a fixed block is held
  (`LongPressDraggable`) and leaves a gap; Agora draws `NowDropZone`, the
  others a gap at their top (`PlanDropGap`); its own section takes
  nothing. Let go on **Agora** is play (`move { start: true }`, or
  `playPending` for a delivery), guard and all. **Em seguida**: a move to
  the place under what runs (a delivery's next task). **Pendentes**: a
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
  chip, its + writing at the first free hour in sight. Lista mode is gone
  from the app (`TimelineModeCubit` survives only in the landing's demo).
- **Para depois** (`LaterPage`): the whole of `PlanItems.later`, each with
  play. Not reorderable yet.
- **A delivery's page** (`ArtifactPage`): Pendentes is two sections,
  **Agora** (its task running, `NowTaskCard` titled by the task) and
  **Para depois** (the rest, the queue's first first, then its backlog),
  each with play; the guard is drawn over it.

## Writing a task

The + opens the creation sheet (`writeTask`, `app/lib/plan/`): **Tarefa |
Evento** (was Flexível | Fixo) and, on a task, a **Produto** chip listing
the catalogue's kinds. A task with no product goes into Para depois (the
backlog) or where the calendar is looking; one with a product is written as
a delivery of that kind (`POST /artifacts`, its minutes from the sheet) at
the end of the queue, so it waits in Para depois too.

## The shell (`app/lib/shell/`)

- Tabs: Plano (`AppIcons.plan`), Objetivos (`AppIcons.goal`), Menu.
- The + writes a goal on Objetivos and a task anywhere else (from Menu it
  brings Plano forward first).
- Menu holds what hung off the greeting (**Sair**) and the catalogue:
  **Produtos** (every delivery, searched and filtered by product,
  `AllArtifactsPage`) and **Novo produto** (`TypeSheet`).
- Screens reported to analytics: `Plano`, `Objetivos`, `Menu`,
  `Calendário`, `Para depois`.
