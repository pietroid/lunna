# One kind of task: deliveries become tasks, and Plano is the home

> Issue [#77](https://github.com/pietroid/lunna/issues/77), **mockup track**
> (it changes the home, the tabs, every card, the creation sheet and the
> task's page). Designed unattended; this is the draft for approval on
> the issue. The build starts from the **Build brief** at the end.

## 1. The prompt

From the issue, verbatim:

> **Unify tasks and deliverables, restructure feed**
>
> The major goal of this task is to unify deliverables and tasks. Both are useful for different context, but there is such an amount of overlap between them that we can just consider they the same. What this means:
>
> 1. A deliverable has x amount of time, such as a task
> 2. A task of a deliverable can be in progress. That is the same to say that a deliverable can be in progress as well
> 3. Deliverables contain tasks. Nothing says that tasks could also contain tasks? The name can be confusing, but in nature they should be the same.
> 4. Tasks can be fixed and deliverables are associated with products. Thats where our cut goes: tasks are fundamentally different from fixed events (so it is a different entity). Deliverables and tasks being associated to certain product or value? No problem at all.
>
> Also, the app will be reorganized to solve this merge, those are the things we gonna need to change:
>
> 1. There is no feed, plan and menu. There is a plan, goals, and menu. Goals are separated now again
> 2. The feed is the same just changed names. We will make the following modifications: 1 remove the clock with greeting, suggestion as it is, then "now" section with indication of period/time off by the side of it. The "ver dia" button leads to a new page that is just for a calendar, reflecting the same thing we have for calendar view today, the next task remain the same thing. 3 next is the "pending" section, which replaces the entregas em andamento. They are basically all tasks that have started but havent finished yet. 4 next is the "Para depois" which are programmed things to do that are on a queue. We can have four of them and a "open the list" that leads to a page.
>
> 3. The card for deliverables and tasks should have the same style, only the "pending" section that will have the bar, para depois remains the same
>
> 4. The title of the now card should be of that task, not its subtask. The subtask can appear as subtitle
>
> 5. Play pause: now all tasks should have the play button to the left of it, including the now one )when it is being played, show a pause). Tapping play is the same effect as dragging to the now area
>
> 6. Make the pending tasks look very much like the agora one, that way we can fit the +10 -10, the done button to the side and the bar should be below (following the same style and thickness)
>
> About the creation, lets preserve the bottom sheet, and when creating a task it will ask if it's event or not (instead of fixed and flexible), and have a small chip to select the product. We will improve that later but for now thats it.
>
> About task, when opening it, it will have the same behavior of deliverable (notes, pending done). The only thing is that we have "now" and "later" sections only, and the play buttons will also should all be available.
>
> The question is: should a task support infinte recursion of subtasking? No, only the first level. Because it is not going to be used.
>
> Why not keeping deliverable and task? Because both are conceptually the same. So this separation doesnt make sense

## 2. The design

![The board](img/mockup-board.png)

The screens one by one, for a phone: [1](img/mockup-1.png) ·
[2](img/mockup-2.png) · [3](img/mockup-3.png) · [4](img/mockup-4.png) ·
[5](img/mockup-5.png) · [6](img/mockup-6.png). The pins are in
[board.json](board.json). The real app (Lunna) draws them through
`app/lib/unify_preview.dart`: the new widgets on canned data, the calendar
on the demo's day, at 10:00 on a light day (day 2 of the cycle).

### The rule

**There is one kind of thing to do: a task.** A delivery is a task that
has tasks of its own. Anything a delivery had (a day it is owed by, a
product, a value, notes, begun, delivered) a task can have, and anything a
task had (a length, a place in the queue, play, pause, ±10, ✓) a
delivery has. **One level only**: a task of a task has no tasks. The cut
is between **tasks** and **events**: an event has an hour that is the point
of it, nothing moves it, and it has no product.

So the home has no separate Entregas: a task begun and not finished is
**Pendente**, whether it has tasks of its own or not; a task not begun is
in **Para depois**.

### The screens

| # | Screen | What it shows |
|---|--------|---------------|
| 1 | Plano, the top | The agent's offer as it is; **Agora** with the day's mark beside it and *Ver o dia*; the running task titled by the task (the subtask under it) with pause on the left; *Em seguida* with play. |
| 2 | Plano, scrolled | **Pendentes**: tasks begun and not finished, drawn like Agora (status, −10 +10 ✓, a 3 px bar under it). **Para depois**: the first four of the queue, then *Abrir a lista · mais 8*. |
| 3 | Ver o dia | The calendar as Tempo draws it today, on a page of its own. |
| 4 | Para depois | The whole queue, each with play. |
| 5 | Criar | The same sheet: **Tarefa \| Evento** instead of Flexível \| Fixo, and a **Produto** chip. |
| 6 | A task's page | Any task opens the delivery's page: Notas · Pendentes · Feitas, and Pendentes has only **Agora** and **Para depois**, play on each. |

### Decisions (the pins)

| Pin | Decision | Chosen |
|-----|----------|--------|
| 1A | Header | Greeting, date and day clock removed; the offer is first. The account menu (Rotina, Sair) moves to Menu. |
| 1B | Period / time off | One tag after "Agora": `Dia 2 · dia leve` in the phase's colours; with no cycle, the day's own tag (Folga, Dia leve); nothing on a plain day. |
| 1C | Ver o dia | A pill on Agora's heading, opening a pushed page. |
| 1D | Agora's title | The task (ex-delivery); its subtask at work is the subtitle. A loose task has no subtitle. |
| 1E | Play / pause | A 32 px round button left of every task: play on `fillStrong`, pause on the accent while it runs. Play = a drop on Agora (`start: true`). |
| 1F | Agora's controls | −10 +10 ✓ and the 3 px accent bar, as today. |
| 1H, 2A | Pendentes | Same card as Agora without the glow. Status `1h30 de 3h · até ter, 3 nov` (red when behind, the old Urgente), −10 +10 ✓ beside it, bar under it at 3 px: red time gone, green work done. A loose task paused halfway is pending too; its bar is the accent. Agora's task is not repeated here. |
| 2B | Para depois | The same card, no bar, no controls: title, a subtitle that says what it is (`Post · 3 tarefas`, or its day), its length on the right. |
| 2D | Abrir a lista | A quiet row under the four, with the count of the rest. |
| 1I | Tabs | **Plano · Objetivos · Menu**. Icons: `plan`, `goal`, `menu`. |
| 3B, 3C | Calendar | `TimelineList(mode: calendar)` as it is, on a page with a back arrow, titled *Calendário*. Calendar cards get **no** play button: a 15-minute card has no room for it, and a drag to Agora still starts one. |
| 4A | The queue | Loose tasks and tasks with tasks in one order (the old backlog and Não iniciadas, merged). |
| 5A | Tarefa \| Evento | Segmented: Tarefa (check icon) or Evento (pin icon, the mark fixed cards already carry). |
| 5B | Produto | A pill with the catalogue icon after the length; tapping it lists the catalogue's kinds. Hidden for an Evento. |
| 6A–C | Task page | The delivery's page for any task: ✓ (deliver / tick off), trash, product · value tag, the pending bar, Notas · Pendentes · Feitas. |
| 6D, 6E | Its Pendentes | Two sections, Agora and Para depois; no day stages, no "Ver os próximos dias". Play on every subtask. |

### References

Drawn from known patterns, not browsed (no Mobbin session here):
**Things 3** (a project is a to-do with to-dos, one level of headings,
and the same row everywhere), **Todoist** (sub-tasks under a task, and
"Upcoming" as its own view, which is our *Ver o dia*), **Toggl Track /
Session** (a play button at the left of every row: starting is one tap,
and the running row turns it into stop).

### Decided unattended

- **Plano's icon** is `AppIcons.plan` (it was the crescent on Feed). The
  crescent stays the agent's, on the bar.
- **The account** (Rotina, Sair), which hung off the greeting, goes into
  Menu, which already opens Rotina.
- **"Para depois" is everything not begun, in one order**: loose tasks
  waiting in the backlog and tasks with tasks that were *Não iniciadas*.
  The day's hours for the queue are on *Ver o dia*.
- **Em seguida** still shows the next card with an hour (task or event);
  an event gets no play (events are never begun by hand).
- **Agora's task is left out of Pendentes**, so the same task is not
  drawn twice.
- **Lista mode is dropped**: Plano is the list, and *Ver o dia* the
  calendar. `TimelineModeCubit` and the switch go.
- **Entregas goes as a tab.** Its catalogue (shelves and kinds) moves
  under Menu, as *Produtos*, since the creation chip picks from it.
- **The task's own page** replaces both `EventPage` (for a task) and
  `ArtifactPage`; an event keeps `EventPage`.
- **A subtask's ✓ and its parent:** ticking off the last subtask does not
  deliver the parent (delivering, and its value, stay a deliberate ✓, as
  with a delivery now).
- **Play on a pending task with tasks** starts its next subtask.
- The product chip lists kinds by name only; the shelf is not shown.

### Open questions

1. **Products and value on a loose task.** The chip sets a product on any
   task; should a task with no subtasks but a product (one post) also
   carry value and count for Objetivos when ticked off? The design says
   yes (it is the same thing), which means goals count ticked-off tasks
   with a value, not only delivered deliveries.
2. **A deadline on a plain task.** The data allows it (the same columns);
   the creation sheet has no field for it yet ("we will improve that
   later"). Fine to leave it to the task's page for now?

## Build brief

Starts from here; Phase 4 replaces this section with sections 3–5.

**Files Phase 1 wrote or changed** (uncommitted on the branch, kept for
the build):

- `app/lib/unify_preview.dart`: the preview entry point, six scenes
  (`?s=1..6`) on fakes. Bring it up to the real cubits for Phase 4's
  prints, then delete it.
- `app/packages/timeline/lib/src/widgets/task_card.dart`: `TaskCard`,
  `TaskPlayButton`, `TaskCardBar`, `TaskBar`: the one card. Its ±10/✓
  are stubs (`_Steps`); wire them as `EventControls` does.
- `app/lib/plan/view/home_page.dart`: `HomePage` (Plano), `TodayTag`,
  `HomeData`/`TaskView` (preview view models: replace with the real
  state from `TimelineBloc`).
- `app/lib/plan/view/task_pages.dart`: `TaskPage` and `LaterPage`
  (sketched on view models; the real `TaskPage` grows out of
  `ArtifactPage`, keeping Notas and its dock).
- `app/packages/app_ui/lib/src/widgets/app_prompt_sheet.dart`: Tarefa |
  Evento, `products`/`initialProduct`, `AppPromptResult.product`.
- `app/packages/l10n/lib/arb/app_pt.arb` (+ `gen/`): `homePending`,
  `homeLaterOpen`, `homeCycleTag`, `dayPageTitle`, `promptTask`,
  `promptEvent`, `promptProduct`, `taskTasksCount`. `promptFlexible` and
  `promptFixed` become unused.
- `app/packages/timeline/lib/src/widgets/widgets.dart`: exports
  `task_card.dart`.

**Server** (`server/src/`):

- **Schema**: `task` gains the delivery's columns (`parent_id` → task,
  `type_id`, `value`, `deadline`, `block_minutes`, `started_at`; `done_at`
  and `notes` exist). A check (or the store) refuses a parent that has a
  parent: **one level**. Migration: each `artifact` row becomes a `task`
  row (same id, `backlog` true while not begun), and `task.artifact_id`
  becomes `parent_id`; then drop `artifact`. Drizzle migration committed.
- **A task with tasks** is never laid out itself: the queue holds its
  subtasks, as it holds a delivery's tasks today. Its minutes, done
  minutes, time gone and pace are worked out as `ArtifactStore` does now.
- **Routes**: `/api/artifacts/*` folds into `/api/tasks/*`
  (`GET /api/tasks/:id` with its tasks; create with `parentId`, `typeId`,
  `value`, `deadline`); the timeline answers `pending` (begun, not
  finished, top-level) and `later` (not begun, in order) beside what it
  has. Keep `artifact` in the wire for one release, or move the app in
  the same PR (recommended: the same PR, one app).
- **Play** on any task is `POST /tasks/:id/move { start: true }` (the
  guard still asks when something runs); on a task with tasks it starts
  its next subtask.
- **±10 on a pending task** not running changes its length (the next
  subtask's, for a task with tasks).
- **Goals** count `value` of top-level tasks ticked off in their window.
- **The agent**: the artifact actions (`agent/actions/`) and the board's
  artifacts become task actions; Work Quality's levels that read
  deliveries read tasks with tasks. Update `evals/` fixtures.
- **Analytics**: rename the artifact rows in `analytics/events.ts`.

**App**:

- Shell: three tabs, **Plano** (`HomePage`), **Objetivos**
  (`GoalsPage`), **Menu** (adds Sair and *Produtos*, the catalogue).
  `FeedPage`, `PlanPage`, `AppTitleTabs` use, Tempo's Lista and the mode
  switch go. `AppFab` on Plano writes a task; on Objetivos a goal.
- `/dia`: the calendar page (`TimelineList(mode: calendar)`, back arrow,
  dock).
- `/depois`: `LaterPage`, reorderable by drag (a move with `index`).
- `/tarefa/:id`: `TaskPage` from `ArtifactPage` (Notas with dictation,
  Pendentes = Agora + Para depois via `TaskCard`, Feitas).
- `DeliveryTile` and `ArtifactRow` go; Lista's runs (`deliveryRuns`) are
  not needed on Plano. The calendar keeps its runs (one block per
  parent).
- The creation sheet passes the catalogue's kinds as `products`, and the
  result's `product` as `typeId`.
- The landing's demo (`app/lib/demo/`) follows: its Entregas chapter
  becomes Plano's Pendentes.

**Specs to update**: `product/spec/artifacts.md` (becomes tasks),
`home.md`, `goals.md`, `agent.md`; `AGENTS.md`'s *Tasks and events*,
*The app shell*, *Entregas*, and the Layout block.

**Cost of the design session**: not recorded here; the queue measures
every run and writes the figures in the PR.
