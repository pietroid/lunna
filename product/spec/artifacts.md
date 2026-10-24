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
  `position` in the queue, and `done_at` (delivered). Writing one of a kind
  copies the kind's time, price and blocks unless the request says otherwise
  (`blockMinutes: null` says whole). It enters the queue at the top or the
  end (`at: top|end`).
- **Its tasks are ordinary tasks** (`task.artifact_id`), exactly as a
  project's were: written down at the end of the backlog, moved, begun and
  finished by the day's own routes, through `EventLayoutService`. Removing a
  delivery removes what waits in the backlog for it and lets the rest belong
  to none. Its page is the old project page: Notas, and Tarefas as Tempo's
  Lista kept to it (`TimelineList(only:, done:)`), plus a line with its kind,
  time and value and a ✓ that marks it delivered or open again.
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
- **Entregas is ordered by deadline** (`byDue`): the soonest first, those
  with none last, the queue's own order breaking ties, under due-day
  headings set as the timeline sets its days (`dueOf`: Hoje, today or
  overdue; Amanhã; Nos próximos 7 dias; Mais adiante; Sem prazo). There is
  no "Fila" heading. The page no longer drags; `POST /artifacts/:id/move
  { index }` stays for the agent, counting the open deliveries as the queue
  will be. A delivered one cannot be moved.
- **One bar, two fills** (`PaceBars`): red (`AppColors.paceTime`) to the
  share of the time from creation to the end of the deadline day, and over
  it green (`AppColors.paceDone`) to the share of tasks done, or of minutes
  with no tasks (`workDone`). Green covering the red is on pace; red showing
  past it is lagging. Under it a key in the two colours ("3 de 5 etapas",
  "faltam 6 dias", in the danger ink once late), and the subtitle ends in
  "no ritmo" or "atrás do ritmo" (`isBehind`: the time more than
  `paceSlack`, 15 points, ahead of the work). No deadline, no red.
- **The goals are hidden** (`ArtifactsPage(showGoals: false)`, the
  default): no goal cards and no "Nova meta". The model, the routes and the
  agent's goal verbs are untouched, and the schedule line stays.

## Routes

Every route answers the whole `ArtifactsAnswer`:
`{ artifacts (open in order, then delivered newest first; each with tasks),
catalog: [{ id, name, types }], goals: [{ …, start, end, done, queued }],
schedule: { needMinutes, freeMinutes, until }, topTypes: [typeId] }`.

| Route | What it does |
|-------|--------------|
| `GET /artifacts` | everything |
| `POST /artifacts` | `{ title, typeId?, minutes?, value?, blockMinutes?, deadline?, at? }` |
| `PATCH /artifacts/:id` | `{ title?, notes?, deadline?, minutes?, value?, blockMinutes?, done? }` |
| `DELETE /artifacts/:id` | backlog tasks go with it; the rest stay |
| `POST /artifacts/:id/move` | `{ index }` in the queue |
| `POST /artifacts/:id/tasks` | `{ title, minutes }`, at the end of the backlog |
| `POST /catalog/types` | `{ name, minutes, price?, blockMinutes?, categoryId \| category }` |
| `POST /goals` | `{ kind, target, period, typeId? (count), start: now\|next }` |
| `DELETE /goals/:id` | the deliveries stay |
| `POST /tasks` | the day's write, with `artifactId` |

Refusals a person can cause are in Portuguese ("Esse tipo não existe mais.",
"Essa entrega já foi entregue.", "Uma meta de quantidade conta um tipo.").

## The app

`app/packages/artifacts`: `ArtifactsCubit` over `ArtifactsRepository`;
`ArtifactsPage` (the tab), `AllArtifactsPage` (search by name, kind or
shelf, the same filter line), `ArtifactSheet` (catalogue → details; a
one-off is timed and priced by hand), `TypeSheet` (the least that fills the
catalogue), `GoalSheet`, `ArtifactPage`. A long press on a goal card removes
the goal. Entregas reads itself again whenever it comes to the front, and
the delivery page whenever the day's tasks change.

## Not yet

How the timeline cuts a delivery into blocks (`block_minutes` is only
stored), the catalogue's own page (editing, ordering, removing kinds),
keeping a one-off as a kind, paging the delivered list, and cycles.
