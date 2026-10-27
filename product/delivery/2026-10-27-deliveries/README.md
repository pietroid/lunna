# Entregas, simplified: the day it is due, what is late first, both sections dragged

Issue [#48](https://github.com/pietroid/lunna/issues/48), **mockup track**,
designed unattended by the queue. This is the draft: sections 1 and 2 and
the Build brief. The person approves (or answers) on the issue; the build
is a fresh session, `/create build deliveries`.

## 1. The prompt

From [issue #48](https://github.com/pietroid/lunna/issues/48), verbatim:

> Improve deliveries experience
>
> Deliveries is too messy yet. A couple of simplifications:
>
> - Nobody reads the subtitles, just remove it.
> - When can move the not started to started, and it will define a deadline, if there isn't such already
> - The in progerss should have the due date showing
> - If a task is delayed, it should be at the first item, and the card should be a bit red, with the label "urgent"
> - We can drag nao iniciadas para em andamento and vice versa, but the ordering depends on the logic that we already have
> - We should have adicionar buttons also to the last part of each section, as we do in the timeline
> - Review if the proportions are right: consider the total time vs completed ratio on one side and total delivery delta vs already passed since beginning

## 2. The design

![The board](img/mockup-board.png)

Each screen alone: [1](img/mockup-1.png) · [2](img/mockup-2.png) ·
[3](img/mockup-3.png). Pins in [board.json](board.json). Drawn by the real
app (Lunna) on Tuesday 27 October at 10:00, from
`app/lib/deliveries_preview.dart`.

The flow: Entregas is the name of each delivery and how it is going,
nothing else (1). What is under way shows the day it is due, and the one
that is late comes first, tinted red and tagged Urgente (1). A delivery
not begun is dragged up into Em andamento; with no day yet, it asks for
one before its clock starts (2). Begun, it takes its place by the rule
Em andamento already has (3).

### The proportions, reviewed

The bar compares two shares. Both were measured against the wrong thing:

| | Today | Proposed |
|---|---|---|
| **Green** (work) | tasks done ÷ tasks (`stepsDone / steps`): a 15-minute task weighs as much as a 3-hour one | **minutes of the tasks done ÷ the delivery's whole time** (`doneMinutes / minutes`, both already on the wire) |
| **Red** (time) | from **creation** to the end of the deadline day: a delivery written down a month before it was begun reads late the moment it starts | from **when it was begun** (`startedAt`, new) to the end of the deadline day |
| Not begun | red runs from creation | **no red**: no clock runs until it is begun, so a not-begun row has no bar at all |

Same arithmetic otherwise: calendar time (nights count, as the deadline
is a day), `paceSlack` 15 points. Example from screen 1: *Mapa astral da
Renata*, 1 h of 3 h done (33%), begun Tuesday 21 at 09:00, due by the end
of Wednesday 28: 145 h of 183 h gone (79%), so 46 points of red show past
the green and it is urgent. Under the old rule, measured from its creation
on the 14th, the red would have read 87% the day it was begun.

### References

Drawn from known patterns, not browsed (no Mobbin session here):

- **Linear** (project list): one line per project, a progress ring and a
  target date at the end, *At risk* / *Off track* as a coloured label; no
  description under the name.
- **Things 3**: a project's deadline is a small flag-and-date at the end
  of its row, red once it has passed; an item dragged from *Anytime* into
  *Today* changes what it is.
- **Todoist** boards: a card is dragged across columns, and a column ends
  in *+ Add task*, as Tempo's stages end in *+ Adicionar*.

### Decisions (the pins)

| Pin | Decision |
|-----|----------|
| 1A | **No subtitle.** The row's second line (kind · time · blocks · no ritmo / atrás do ritmo) is gone, and so is the value on the name's line (it stays on the delivery's page). A row is its name and how it is going. |
| 1B | **Urgente** = under way and either its day has passed or its time is more than 15 points ahead of its work (`isUrgent`: overdue or `isBehind`). The card is `AppColors.urgentFill` (new token: `#FDEDEF` Lunna, `#2A1418` Focus) and carries an `AppTag` *Urgente* with `AppIcons.warning` in `dangerInk` on `danger`. Urgent ones are **always first** in Em andamento, then the existing rule (`lagOf`, most behind first). |
| 1C | **The day it is due**, on every row under way, in the red key of the bar: *até amanhã*, *até sex., 6 nov*; once past, *atrasada 2 dias*. In `dangerInk` when urgent. It replaces *faltam N dias*. |
| 1D | **Green key is time**: *1 h de 3 h* (`artifactTimeDone`), the same minutes the green bar is drawn from. |
| 1E | **Not begun has no bar**: the name, then at the end of the line its time and, if it has one, its day (*3 h · até ter., 3 nov*), the day in `dangerInk` once passed. |
| 1F | **+ Adicionar** ends each section, Tempo's add row (plus, `ink3`, *Adicionar*). In Em andamento it writes a delivery that is begun at once (the sheet asks its day); in Não iniciadas, at the end of the queue. The `AppFab` stays and keeps writing to the queue as today. |
| 1G | **Both headings are always drawn** once there is any open delivery, so an empty Em andamento is still a place to drop on (its add row alone). |
| 2A | **Drag across.** One long press drags a row in either section. Dropped in **Em andamento**, it is begun (`startedAt` = now); its place there is the rule's, not where it was let go. Dropped in **Não iniciadas**, it is no longer begun, at the place it was let go (queue order, as today). |
| 2B | **Begun with no day asks for one**: *Começar Sinastria Ana e Leo*, the line *Ela vai para Em andamento e o tempo dela passa a correr até o prazo. Até quando?*, and four choices: *Em 3 dias*, *Em 1 semana* (picked), *Em 2 semanas*, *Outro dia* (the wheel picker). **Começar** is the one accent. A delivery that has a day starts at once, no sheet. |
| 2C | **Closing the sheet cancels**: the row goes back to Não iniciadas where it was. A clock needs an end, so nothing is begun without a day. |
| 3A | **Begun, it lands by the rule**: just begun, it has no red and no green (lag 0), so it sits under the urgent one and above *Curso de tarô* only because the rule says so. |
| 3B | Its bar starts empty; its key reads *0 min de 2 h* and *até ter., 3 nov*. |

### Decided unattended

- **"Subtitles" means the row's second line.** The schedule line under the
  title (*A fila pede 14h30 · você tem 31h livres até sáb, 31 out*) stays: it is not a
  delivery's subtitle, and it is the one place the month's load meets the
  agenda. Open question below.
- **The value leaves the row** (it is on the page). Fewer things per row
  was the ask.
- **Urgent is only for what is under way.** A delivery not begun has no
  clock, so it is never "behind"; its row shows its day in `dangerInk` once
  passed, and it stays where the queue put it.
- **"Started" becomes a fact, not a guess.** Today it is inferred from work
  done; dragging back to Não iniciadas must stick even with work done, so
  it is stored (`artifact.started_at`). Beginning any task of a delivery on
  Tempo begins the delivery (sets it if null). The migration sets it, for
  each delivery with work done, to its first task's start.
- **Begun with no day: a week by default.** The same default the page's
  deadline picker already uses.
- **Time is calendar time** (nights and weekends count), as the deadline is
  a calendar day; working hours would make the bar jump at 22:00.
- The "Ver todas" cap (`shown`, 5) stays and counts both sections.

### Open questions

1. Should the schedule line (*A fila pede … · você tem … livres até …*) go too?
   Kept for now.
2. Should an overdue delivery that was **never begun** be pulled into Em
   andamento as urgent? Proposed: no, it stays in the queue with its day
   in red.

## Build brief

Starts with `/create build deliveries`. Read this, then
`product/spec/artifacts.md`, then the files below.

### Files the design session wrote (uncommitted, kept for the build)

- `app/lib/deliveries_preview.dart`: the preview entry point, scenes 1–3
  (fixed clock, Tue 27 Oct 10:00). Delete after the build's prints.
- `app/packages/artifacts/lib/src/models/models.dart`: `Artifact.startedAt`
  (from `startedAt` on the wire, in `copyWith` and `props`); `progressAt`
  now runs from `startedAt` and is null when not begun.
- `app/packages/artifacts/lib/src/view/pace_bars.dart`: `workDone` by
  minutes; `isStarted` = `startedAt != null`; `isUrgent`; `progressGroups`
  puts urgent first; the key (time done; the due day or *atrasada*).
- `app/packages/artifacts/lib/src/view/artifact_row.dart`: rewritten (no
  subtitle, urgent tint and tag, not-begun rows with no bar).
- `app/packages/artifacts/lib/src/view/start_sheet.dart` (new) and its
  export in `view.dart`: `showStartSheet(context, artifact) → DateTime?`.
- `app/packages/artifacts/lib/src/view/artifacts_page.dart`: both headings
  always drawn, an `_AddRow` ending each section (both open
  `showArtifactSheet` for now).
- `app/packages/app_ui/lib/src/theme/app_colors.dart`: `urgentFill`.
- `app/packages/l10n/lib/arb/app_pt.arb` (+ `gen/`): `artifactUrgent`,
  `artifactStartTitle`, `artifactStartBody`, `artifactStartInDays`,
  `artifactStartInWeeks`, `artifactStartOtherDay`,
  `artifactStartOtherDayHint`, `artifactStart`. The add row reuses
  `timelineAdd`.

The existing `pace_test.dart` and `artifacts_page_test.dart` were not run
in the design session and expect the old rules (steps, `isStarted` by work
done, the subtitle): they will fail until the build updates them.

### Server

- `artifact.started_at timestamptz null` (schema + `npm run db:generate`);
  the migration backfills it, for open deliveries with a done task, with
  that delivery's earliest task `event` start (or `done_at`).
- `ArtifactView.startedAt` on the wire.
- `PATCH /artifacts/:id { started: true|false, deadline? }`: `true` sets
  `started_at` = now if null, and **refuses** without a deadline on the row
  or in the request (*"Dê um prazo para começar a entrega."*); `false`
  clears it. A delivered one is refused as today. Combine with
  `POST /artifacts/:id/move { index }` for a drop into Não iniciadas (one
  call: accept `started: false` on the move, or two calls; pick one and
  write it in the spec).
- `POST /artifacts { …, started: true }` begins it on creation (needs a
  deadline, same refusal).
- Beginning a task of a delivery (`POST /tasks/:id/start`, a drop with
  `start: true`, the guard's answers) sets its `started_at` when null.
- The agent: `actions/` gets the start/stop verb only if cheap (one
  `Action`); otherwise note it in the spec's *Not yet*.
- Analytics: the new write gets its row in `server/src/analytics/events.ts`
  if it is a new route.
- Specs: the PATCH (start with/without a deadline, stop, refusal on a
  delivered one), the backfill (PGlite), a task start beginning its
  delivery.

### App

- `ArtifactsRepository.update(..., started:)` / `create(..., started:)`,
  cubit `start(id, {DateTime? deadline})`, `stop(id, index)`, optimistic
  like `move`. `DemoArtifactsRepository` follows (landing demo).
- **The drag across** (`artifacts_page.dart`): one `SliverReorderableList`
  over `[...started, divider, ...waiting]`, where the divider item is Em
  andamento's add row plus the Não iniciadas heading, not draggable. A drop
  above the divider: begin (sheet first if no deadline; closing it
  cancels, the cubit restores the row); index ignored, the rule sorts.
  Below: stop when it was begun, then the queue index (`queueIndexOf`
  over `waiting`). Drag stays off under a shelf filter. Em andamento rows
  drag too now.
- `_AddRow`: promote to `app_ui` as `AppAddRow` and use it in
  `timeline_list.dart` too (one widget, two places).
- Em andamento's add opens `ArtifactSheet(started: true)`: the deadline
  row is required, the "Entra na fila" row hidden.
- The delivery's page uses `PaceBars` too: check its header reads well
  with the new key (time, due day).
- Tests: `pace_test.dart` (minutes share, from `startedAt`, urgent first,
  overdue counts, not begun has no time), `artifacts_page_test.dart`
  (no subtitle, urgent tag, due day, both add rows, both headings with an
  empty Em andamento, a drop across begins / stops, the sheet's cancel),
  `models_test.dart` (`startedAt` read). Under both brands.
- Spec: rewrite "Entregas is two groups" and "One bar, two fills" in
  `product/spec/artifacts.md`, and the Entregas paragraph in `AGENTS.md`
  (Em andamento by `started_at`, urgent first, minutes over time from the
  start).

### Cost and time of the design session

Measured by the queue, which writes the figures in the PR.
