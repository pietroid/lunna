# Entregas (artifacts)

> Moved out of [AGENTS.md](../../AGENTS.md) to keep every session's context
> small. It is binding the same way: read it before changing this feature.
> Delivered in [product/delivery/2026-10-21-artifacts](../delivery/2026-10-21-artifacts/README.md);
> it replaced Projetos.

The person reads **Entregas** (one *entrega*); code says `Artifact`. Three
forces share the tab: the **goals** (*Metas*, what the market asks), the
**schedule** (the free working time the agenda has left) and the **queue**
of deliveries both are spent on.

## The model

- **Catalogue** (`catalog_category`, `catalog_type`): shelves (*Atendimentos*,
  *Conteúdo*) holding kinds (*Mapa astral*), each with a default length
  (`minutes`), an optional `price` (whole reais) and an optional
  `block_minutes`. **Everyone starts empty**: no seed. A kind is written down
  by `POST /catalog/types` with a shelf she has (`categoryId`) or a shelf's
  name (`category`), reused case-insensitively or made at the end.
- **Artifact** (`artifact`): a name, notes, an optional kind (`type_id`,
  null for a one-off), `minutes` (null: the sum of its tasks), `value` (whole
  reais), `block_minutes` (null: whole), a `deadline` day, a fractional
  `position` in the queue, `started_at` (begun: its clock runs from here;
  null while it waits in Não iniciadas) and `done_at` (delivered). Writing
  one of a kind copies the kind's time, price and blocks unless the
  request says otherwise
  (`blockMinutes: null` says whole). It enters the queue at the top or the
  end (`at: top|end`).
- **Its tasks are ordinary tasks** (`task.artifact_id`), exactly as a
  project's were: written down at the end of the backlog, moved, begun and
  finished by the day's own routes, through `EventLayoutService`. Removing a
  delivery removes what waits in the backlog for it and lets the rest belong
  to none. Its page is the old project page, under the bar Entregas draws
  (`PaceBars`) and a line with its kind, time and value and a ✓ that marks
  it delivered or open again; then three tabs, opening on the one last
  chosen there (from Tempo, on Pendentes):
  - **Notas**.
  - **Pendentes · n**: Tempo's Lista kept to it (`TimelineList(only:)`),
    in Tempo's stages: Agora when one of its tasks runs, the one day
    (Ainda hoje or Amanhã, `_listDay`), a line counting the later tasks
    ("Ver os próximos dias", which draws them there, each day under its
    date) and Para depois, which is where its backlog lives: Tempo's Para
    depois holds only tasks with no delivery. No card names the delivery.
  - **Feitas · n**: what was done, newest first under Hoje / Ontem / the
    date (`doneDayLabel`), each a `DoneArchiveTile`; a tap opens the
    finished task.
- **On Tempo a delivery's card is the delivery**: a tap on it, in Lista
  (Agora included) or on any line of its block or its lone task on the
  calendar, opens its page on Pendentes (`TimelineList(onDeliveryTap:)`).
  A drag, a nudge, a swap and the seam still take that line's task, and
  the running card's buttons act on the running task.
- **Goal** (`goal`): `kind` money (the `value` of deliveries delivered in the
  stretch) or count (deliveries of one `type_id`), a `target`, a `period`
  (week Monday–Sunday, or month), and `starts`, the first day of its first
  stretch (this one or the next, chosen when written down). A goal whose
  stretch has not come is a **future** goal, drawn quiet.

## The rules

- **Money counts on delivery**: a delivery counts towards the stretch its
  `done_at` falls in, in the person's zone. No paid date.
- A goal's **done** is what was delivered in the stretch; its **queued** is
  what is still open with a deadline before the stretch ends: overdue ones
  included while the stretch is being measured, only those inside it for a
  future goal.
- **Schedule**: `needMinutes` is the time still owed (`minutes − doneMinutes`)
  by open deliveries due by the end of this month; `freeMinutes` is the
  working time from now to the end of the month not taken by any event or
  laid-out task (`TimelineService.day`). Both are approximate on purpose: a
  delivery's queued tasks count in both.
- **Most used kinds** (`topTypes`): deliveries per kind, open and delivered,
  all time, at most three, the catalogue's order breaking ties; a kind never
  used is not among them. The filter line is *Todas*, those kinds, then
  every shelf (with a folder); one pick at a time, not remembered.
- **Begun is a fact** (`started_at`), never inferred from work done. A
  delivery is begun by being dragged into Em andamento, by being written
  down there (its +), or by a task of it being begun on the day
  (`EventLayoutService._begin`, when it was not begun); it stops being
  begun only when dragged back into Não iniciadas, whatever was done of
  it. **Nothing is begun without a deadline**: a clock needs an end, so a
  start with none is refused (*"Dê um prazo para começar a entrega."*) and
  the app asks for the day first (`StartSheet`: em 3 dias, em 1 semana,
  picked, em 2 semanas, outro dia; closing it begins nothing). Begun
  again, it keeps the hour it was first begun at. The migration
  `0013_artifact_started` set it, for each open delivery with work begun
  or done, to the earliest hour one of its tasks began or was ticked off.
- **Entregas is two groups** (`progressGroups`), headed as the timeline
  heads its days, both always drawn once there is an open delivery (so an
  empty Em andamento is still a place to drop on): **Em andamento**, every
  open delivery begun (`isStarted`), the **urgent** ones first and then
  the one most behind first (`lagOf`: the share of time gone less the
  share of work done, so the most red showing past the green leads; no
  deadline counts as no time gone; the queue's order breaks ties); then
  **Não iniciadas**, the rest, in the queue's order. Each group ends in
  **+ Adicionar** (`AppAddRow`, Tempo's): Em andamento's writes a
  delivery begun at once (`ArtifactSheet(started: true)`, a day required,
  a week out unless picked, no place in the queue), Não iniciadas' one at
  the end of the queue. The `AppFab` still writes to the queue.
- **Urgent** (`isUrgent`): begun, and either its day has gone by or its
  time is more than `paceSlack` (15 points) ahead of its work
  (`isBehind`). Its card is `AppColors.urgentFill` and carries an `AppTag`
  *Urgente* (`AppIcons.warning`, `dangerInk` on `danger`). A delivery not
  begun is never urgent: its row writes its day in the danger ink once
  passed, and it stays where the queue put it.
- **The drag** (when no shelf filter is on): one list,
  `[...started, the line, ...waiting]`, the line being Em andamento's + and
  Não iniciadas' heading, never moved itself. Every row drags. Let go above
  the line, a delivery not begun is begun (`PATCH /artifacts/:id
  { started: true, deadline? }`), asking its day first when it has none;
  its place there is the rule's, not where it was let go. Let go below,
  it lands just before the row it was let go above, or after the last one
  (`queueIndexOf`), posted as `POST /artifacts/:id/move { index }` counted
  in the whole open queue, the same route the agent uses, with
  `started: false` when it came from Em andamento. A delivered one cannot
  be moved, begun or stopped. There is no "Fila" heading.
- **A row is its name and how it is going**, nothing under the name (no
  kind, time, value or "no ritmo"; those are on its page). Begun, the bar;
  not begun, no bar (no clock runs), and at the end of the name's line its
  time and its day (*3h · até ter, 3 nov*). Delivered, the day it was.
- **One bar, two fills** (`PaceBars`): red (`AppColors.paceTime`) to the
  share of the time from **when it was begun** to the end of the deadline
  day (calendar time: nights count, as the deadline is a day), and over it
  green (`AppColors.paceDone`) to the share of its **minutes** done
  (`workDone`: `doneMinutes / minutes`, so a three-hour task weighs twelve
  fifteen-minute ones). Green covering the red is on pace; red showing
  past it is lagging. Under it a key in the two colours: the time done
  ("1h de 3h") and the day it is due ("até qua, 28 out", or "atrasada 2
  dias" once past), the latter in the danger ink when urgent. No deadline,
  or not begun, no red.
- **The goals are hidden** (`ArtifactsPage(showGoals: false)`, the
  default): no goal cards and no "Nova meta". The model, the routes and the
  agent's goal verbs are untouched.
- **No schedule line**: the line that set what the queue owes this month
  against the agenda's free hours (*A fila pede … · você tem … livres
  até …*) is not drawn. `schedule` is still in `GET /artifacts`.

## Routes

Every route answers the whole `ArtifactsAnswer`:
`{ artifacts (open in order, then delivered newest first; each with tasks),
catalog: [{ id, name, types }], goals: [{ …, start, end, done, queued }],
schedule: { needMinutes, freeMinutes, until }, topTypes: [typeId] }`.

| Route | What it does |
|-------|--------------|
| `GET /artifacts` | everything |
| `POST /artifacts` | `{ title, typeId?, minutes?, value?, blockMinutes?, deadline?, at?, started? }`; `started: true` needs a deadline |
| `PATCH /artifacts/:id` | `{ title?, notes?, deadline?, minutes?, value?, blockMinutes?, done?, started? }`; `started: true` needs a deadline (on the row or in the request) |
| `DELETE /artifacts/:id` | backlog tasks go with it; the rest stay |
| `POST /artifacts/:id/move` | `{ index, started?: false }` in the queue; `started: false` stops it (one call for a drop into Não iniciadas) |
| `POST /artifacts/:id/tasks` | `{ title, minutes }`, at the end of the backlog |
| `POST /catalog/types` | `{ name, minutes, price?, blockMinutes?, categoryId \| category }` |
| `POST /goals` | `{ kind, target, period, typeId? (count), start: now\|next }` |
| `DELETE /goals/:id` | the deliveries stay |
| `POST /tasks` | the day's write, with `artifactId` |

Refusals a person can cause are in Portuguese ("Esse tipo não existe mais.",
"Essa entrega já foi entregue.", "Uma meta de quantidade conta um tipo.",
"Dê um prazo para começar a entrega.").

## The app

`app/packages/artifacts`: `ArtifactsCubit` over `ArtifactsRepository` (`start` and `stop` draw the
row in its new group before the server answers, and put it back on a
refusal);
`ArtifactsPage` (the tab), `AllArtifactsPage` (search by name, kind or
shelf, the same filter line), `ArtifactSheet` (catalogue → details; a
one-off is timed and priced by hand), `TypeSheet` (the least that fills the
catalogue), `GoalSheet`, `ArtifactPage`. A long press on a goal card removes
the goal. Entregas reads itself again whenever it comes to the front, and
the delivery page whenever the day's tasks change.

## Not yet

How the timeline cuts a delivery into blocks (`block_minutes` is only
stored), the catalogue's own page (editing, ordering, removing kinds),
keeping a one-off as a kind, paging the delivered list, and cycles. The
agent cannot begin or stop a delivery yet (no `Action` for `started`), and
the delivery's page has no control for it: both go through Entregas' drag.
