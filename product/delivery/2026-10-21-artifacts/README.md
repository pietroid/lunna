# Entregas: deliveries, goals and the catalogue replace Projetos

Status: **design, waiting for approval** (issue #12). Sections 3–5 come with
the build.

## 1. The prompt

From [issue #12](https://github.com/pietroid/lunna/issues/12):

> New structure for organization: artifacts.
>
> Lunna was always meant to be an _Artifact Management System_ built for women.
>
> The main goal of Lunna is help women organizing what they need to do, when they need to do, given the ability to do based on their cycles and calendar.
>
> Conceptually we have those three "forces":
>
> - Planned artifacts: a queue of products, services or deliverables she has to do
> - Goals: hard or soft goals - primarily financial - involving how much she should earn or delivery in a given timeframe
> - Schedule: in the future will consider periods, but also consider other tasks such as wellbeing, the day to day routine (time to sleep, time to wakeup, weekends).
>
> Schedule and goals compete by the planned artifacts, goals are capitalistic and market demands and schedule is the realistic operation a women can do in a healthy way.
>
> # Challenges
>
> This seems conceptually sound, but put this in a nice simple design is harder than it seems.
>
> ## The term
>
> First of all, there is no clear word for "artifact" that seems universal but at the same time good for user to understand. "Product" or "Service" can be a good term, but still depends. For example, post on Instagram is a measurable artifact but is neither a product nor service.
>
> ## Visualization
>
> My initial idea is to have a separate tab for those "artifacts" with a queue of them. Probably we will need to separate between categories or types, as an Instagram post is different from a client that you will talk to.
>
> ## Catalogue
>
> For an astrologer (the use case im working on), there are a catalogue of products, and an artifact is simply something from that catalogue. The instagram post can be a catalogue as well. There seems to be two dimensions: category, and inside that category, types.
>
> ## Goals
>
> The hardest are goals, because goals can be really fuzzy, and I think AI will help us a lot with this. But we still need a substrate. The simplest goal we can start is by having $X amount in this month. Or another is to post X posts per week.
>
> We can tie a goal with a certain metric per certain amount of time for now. And there are active goals and future goals.
>
> ## Where goals vs artifacts live
>
> I was thinking of a proposition that we have this unified tab for goals/artifacts and goals are at the top, with the queue of artifacts coming up later, kind of organized by priority. We can expand and see all artifacts for example, or search by them.
>
> ## And Projects?
>
> We should extinguish the concept of project and turn it into plain artifacts only. And here is the catch: artifacts almost map 1:1 into small projects, or even big projects if we think. Let's consider I should work 2 weeks on some project to deliver something, thats an artifact. It contains multiple subtasks, internal notes, etc. But there can be simpler artifacts that just take 1 hour. Or take 4 hours, but I can split them into multiple times of my day. That's the whole idea.
>
> ## Artifacts can be split in the timeline
>
> For tasks more than 2 hours is pretty boring that it's moved to tomorrow if I need for today. I just maybe get a bit of it (can be a subtask of it or just a literal bit of it).
>
> Artifacts thus have some sort of total time, that can be either totalized at the beginning of definition or by computing the subtasks.
>
> ## Final considerations
>
> This seems a big delivery. You have just 5 screens to show. I want you to focus on the main features and on the top level screens (the tabs, creation of an artifact). We can later focus on the impact on the timeline and the internal pages of catalogue, etc.

## 2. The design

![The board](img/mockup-board.png)

Pins in [board.json](board.json). Drawn by the real app (Lunna), new
`artifacts` package. One screen per image, for a phone:
[1](img/mockup-1.png) · [2](img/mockup-2.png) · [3](img/mockup-3.png) ·
[4](img/mockup-4.png) · [5](img/mockup-5.png).

### The term: **Entrega**

*Entrega* (plural *Entregas*) is what Brazilian freelancers already call
the thing they owe: "minhas entregas da semana". It covers all three cases
in the issue: a natal chart for a client, an Instagram post, a two-week
course. *Produto* and *Serviço* each leave one of them out. In code the
model stays `Artifact`, in the `artifacts` package. Goals are **Metas**,
the catalogue is **Catálogo**, its two levels are a **category** (the
shelf: Atendimentos, Conteúdo, Produtos) and a **type** (Mapa astral,
Reels).

### The flow

1. **Entregas** takes Projetos's tab. On top, the **Metas** scroll sideways
   (active, then future). Under them, one line puts the **schedule** against
   them: the time the queue has due this month against the free hours left
   on the agenda. Then the **Fila**, in priority order, filtered by category.
   The example shows the three forces pulling against each other: even if
   the whole queue is delivered, October misses its goal by R$ 1.870, and
   the agenda has 26h free for 11h15 of work, so there is room for more
   clients.
2. **Todas as entregas**: search by name, type or category; the queue's matches,
   then what was delivered.
3. **Nova entrega** opens on the **catalogue**: pick a type and its time,
   price and splitting come with it. A one-off delivery with no type is
   the last row.
4. Then only the name and the deadline are left to write. **No dia:
   Inteira / Blocos de 1h** is how a long delivery gets split on the
   timeline. **Conta para** is worked out from the type and the deadline,
   not picked.
5. **Nova meta**: Faturamento or Quantidade (of one type), how much, per week
   or month, now or from next month.

### Decisions (the pins)

| Pin | Decision |
|-----|----------|
| 1A | Entregas replaces Projetos in the same tab. Still three tabs: Tempo · Entregas · Menu. Icon: Phosphor `stack`. |
| 1B | Search sits in the header and opens screen 2. |
| 1C | Goal card: label · month, days left, amount "de" target, a two-part bar (delivered in accent, queued and due in the stretch in the accent wash), and what is still missing. |
| 1D | "Nova meta" is a quiet pill; the accent stays on the +. |
| 1E | The schedule line: hours the queue has due by the end of the month against the free hours on the agenda until then. |
| 1F | Categories filter the queue (`AppSegmented`, scrolls sideways). |
| 1G | A row shows the name and value, then the type, the time (or time worked of the total, or steps done) and the deadline. The bar appears once work has started. Order is priority; drag to reorder, as in Lista. |
| 1H | The + writes a delivery. Same spot as on every tab. |
| 1I | Future goals are drawn quiet, with the day they start. |
| 2A–D | Search covers name, type and category. Results come in two sections: Na fila (priority order), then Feitas (newest first). |
| 3A | One field both searches the catalogue and names a one-off delivery. |
| 3B | "Editar" opens the catalogue's page (a later delivery). |
| 3C | Each type has a default time, an optional price and an optional block length. |
| 3D | "Uma entrega avulsa": no type, time given by hand. |
| 3E | Two levels: category, then type. |
| 4A | A tag shows the category · type; "Trocar" goes back to the catalogue. |
| 4B | The name is prefilled with the type; she adds who it is for. |
| 4C | Total time comes from the type. Later it can be the sum of the subtasks. |
| 4D | **Splitting**: Inteira, or Blocos de N. The timeline takes one block at a time instead of pushing the whole thing to tomorrow. |
| 4E | Value comes from the price and counts towards the money goal. |
| 4F | "Conta para" is derived: the money goal of the deadline's month if it has a value, or the count goal of its type. |
| 4G | It enters the queue at the top or the end. |
| 4H | "Pôr na fila" is the one accent action. |
| 5A–E | A goal is a metric (money or count of a type) × an amount × a period (week or month) × a start (now or next month), read back as a sentence. |

New icons (Phosphor, wired in `AppIcons`): `artifacts` (stack), `goal`
(target), `search` (magnifyingGlass), `catalog` (bookOpen), `value`
(coins), `split` (rows). No sparkles, no new brand SVG.

**References** (drawn from known patterns, not browsed):

- Linear's issue list: one priority-ordered queue with filter chips over it.
- Nubank's and Mobills' *Metas* cards: an amount "de" a target, with one bar.
- Notion's database templates: a new item starts from a type that brings its own fields.

### Decided unattended

Nobody was at the keyboard, so these were taken as I would recommend.
Say otherwise on the issue.

1. **The term is *Entrega*** (code: `Artifact`).
2. **Projetos is gone as a tab.** Each existing project becomes a one-off
   delivery: same name, notes and tasks (as its subtasks), and its deadline.
   Its page becomes the delivery's page (not drawn: "internal pages later").
3. **Goals measure only two things for now**: money from deliveries done in
   the stretch (their value), and a count of one type. Both repeat per week
   or per month. A future goal is one whose stretch hasn't started.
4. **"Na fila" on a goal counts only queued deliveries due inside the
   stretch.** Anything later can't help this month.
5. **The schedule line is one sentence, not a chart**, and counts only
   deliveries due by the end of the month.
6. **Splitting is a property of the delivery** (default from its type).
   How the timeline cuts blocks is the next delivery; this one only stores
   it.
7. **The tab shows the first 5 of the queue**, then "Ver todas as N".
8. Screens show Lunna only; Focus gets the same tokens.

### Open questions

- Does a delivery's money count when it is **delivered** or when it is
  **paid**? The design counts it when it is delivered (`doneAt`); paid would
  need a second date.
- Should the catalogue be seeded (an astrologer starter set) or start empty
  for everyone?

## Build brief

Phase 3 starts here; Phase 4 replaces this section with sections 3–5.

**Files Phase 1 wrote or changed (uncommitted in the worktree, except as the
queue commits them):**

- `app/lib/artifacts_preview.dart`: preview entry point, scenes 1–5,
  fake catalogue, queue, delivered list and goals (2026-10-21).
- `app/packages/artifacts/` is a new package. `models/models.dart` holds `CatalogType`,
  `CatalogCategory`, `Artifact`, `Goal`, `GoalKind` and `GoalPeriod`.
  `format.dart` holds money, durations, month and goal labels. The views
  are `artifacts_page.dart` (the tab), `goal_card.dart`, `artifact_row.dart`,
  `all_artifacts_page.dart`, `artifact_sheet.dart` (catalogue →
  details), `goal_sheet.dart` and `sheet_frame.dart`. They take their data
  as constructor arguments: the build puts a cubit and a repository behind
  them.
- `app/packages/app_ui/lib/src/app_icons/app_icons.dart`: six icons.
- `app/packages/l10n/lib/arb/app_pt.arb` (+ `gen/`): `shellArtifactsTab`,
  `monthsLong`, `artifacts*`, `artifact*`, `goal*`, `catalog*`.
- `app/pubspec.yaml`: depends on `artifacts`.

**Server**

- Tables: `catalog_category`, `catalog_type` (minutes, price, block
  minutes), `artifact` (title, notes, type, minutes, value, deadline,
  block minutes, position, done_at), `goal` (kind, period, target, type,
  starts). A task gets `artifact_id` in place of `project_id`.
- Migration: each project becomes a one-off artifact with its tasks;
  then drop `project`.
- Routes: CRUD for the catalogue, artifacts (with move/reorder) and goals.
  `GET /api/artifacts` answers `{ goals (with done/queued), queue, schedule:
  { needMinutes, freeMinutes, until } }`. The free minutes come from the
  timeline's free stretches up to the end of the month.
- The agent: projects in the board become artifacts (`product/spec/agent.md`).

**App**

- `ArtifactsCubit` + repository. The tab replaces `ProjectsPage` in
  `ShellPage`. The FAB on it opens `showArtifactSheet`.
- The artifact page replaces `ProjectPage` (notes, subtasks,
  `TimelineList(only:)`), drawn as today's project page for now.
- Remove the `projects` package once nothing uses it.
- Tests under both brands. Update `product/spec/projects.md` → `artifacts.md` and
  AGENTS.md.

**Out of this delivery** (from the issue): how the timeline cuts a delivery
into blocks, the catalogue's own page, the artifact's inner page redesign,
and cycles.

Cost: the queue measures this run and writes the figures into the PR.
