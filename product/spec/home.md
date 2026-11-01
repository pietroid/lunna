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
| Pendentes | every delivery begun and not delivered (`PendingCard`): its next task under the name, "1h30 de 3h · até ter, 3 nov" (danger ink when urgent), −10 +10 ✓, the pace bar at 3 px | `progressGroups(...).started`, minus the one running on Agora | not drawn |
| Para depois | the first four (`kLaterOnHome`) of everything not begun (`LaterCard`), then *Abrir a lista · mais N* | `PlanItems.later`: the loose backlog in its order, then the deliveries not begun in the queue's | "Nada esperando." |

- **Play** is a drop on Agora: a loose task posts `POST /tasks/:id/move
  { index: 0, start: true }`; a delivery posts `POST /tasks/of/:id/play`,
  which begins its next task (the first the queue reaches, else the first
  of its backlog, else a new task of its name for what it still owes).
  Both can raise the guard, drawn over the page (`GuardSheet`).
- **±10 on a pending delivery** changes its time (`PATCH /artifacts/:id
  { minutes }`, never under what is done or ten minutes); **✓** delivers it.
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
