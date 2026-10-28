# Objetivos: a goals tab, money first

> Draft from the design session (issue
> [#52](https://github.com/pietroid/lunna/issues/52)), mockup track. Sections
> 1 and 2 and the Build brief; the build replaces the brief with sections 3–5.

## 1. The prompt

From the issue, verbatim:

> **Create goals tab (objetivos)**
>
> Goals are long term engagements that measure if a certain metric will reach
> a certain value at a certain time.
>
> We already have goals but it was not done in the best shape possible. So
> reuse and adapt it in the way that it is good for a single tab.
>
> Prioritize simplicity on the creation of it. Lets start with just financial
> goals for now, for that we need to introduce $money to deliverables.
>
> A goal must also have the dual bar approach: one saying how much was
> achieved and how much is needed up to this date considering the last goal
> we have.
>
> Also, for simplicity, a goal must always suggest "by next month", "by next
> week" (last day of next month), the user can simply change the date
> manually if the want.

## 2. The design

![The board](img/mockup-board.png)

The screens one by one, for a phone: [1](img/mockup-1.png) ·
[2](img/mockup-2.png) · [3](img/mockup-3.png) · [4](img/mockup-4.png) ·
[5](img/mockup-5.png). Pins in [board.json](board.json). Drawn by the real
app (Lunna) through `app/lib/goals_preview.dart`, on the demo's deliveries,
with the clock fixed at Wed 28 Oct 2026, 10:00.

**The flow.** A fourth tab, **Objetivos**, takes the goals out of Entregas
(where they were hidden behind a flag). A goal is now **an amount of money to
bill by a day**: no kind, no week/month period, no "now or next". It is
written in two choices: how much, and by when, with the end of next week and
the end of next month offered and next month picked. On the tab the running
goal gets the same two-fill bar as a delivery: green is what was billed
(deliveries delivered since it began, their `value`), red is what its days ask
for by today. The goals after it wait under Próximos; the ones gone by are
listed under Anteriores. For money to count, every delivery now carries an
editable **Valor**, which a kind's price only fills in.

### References

Drawn from known patterns. Mobbin wasn't browsed: no signed-in browser in
this run.

- **YNAB, savings targets ("Save R$ X by date")**: one amount and one date,
  plus a line saying what that asks per week. That is the sheet and its
  readback.
- **Monzo / Nubank "Caixinhas" with a target date**: the next-month date
  offered as the default.
- **Lunna's own `PaceBars`** (Entregas): the green and red bars and the 15 %
  slack, so a goal reads the way a delivery already does.

### Decisions

| Pin | Decision | Chosen |
|-----|----------|--------|
| A | Where | A 4th tab between Entregas and Menu, `AppIcons.goal` (Phosphor `target`, already in the app). No new icon. |
| B, C | First goal | An empty card that says what a goal is, with + Novo objetivo. The FAB writes a goal on this tab. |
| D | What it measures | Money only, whole reais. The `count` kind stays in the model, unused by the app. |
| E | By when | Segmented: *Próxima semana* (that week's Sunday), *Próximo mês* (that month's last day, picked when the sheet opens), *Outra data* (the wheel). |
| F | The day | Always shown as a row, and a tap opens the wheel, so the suggestion is changed by hand. |
| G | Readback | "Faturar R$ 10.000 até 30 nov." plus where it starts and the pace per week ("uns R$ 2.059 por semana"). |
| H | Dual bar | Green: `done / target`. Red: `timeAt(now)`, the share of calendar time from its start to the end of its last day. `PaceBar` is shared with deliveries. |
| I | Key | Green "R$ 2.850 faturados", red "R$ 4.495 até hoje" (= target × time gone); the red text uses the danger ink when behind. |
| J | Pace tag | *R$ X abaixo do ritmo* (danger) when the red leads by more than 15 % of the target (`paceSlack`), otherwise *No ritmo*, or *R$ X acima do ritmo* when ahead. |
| K | Queue | One line: the value of the open deliveries due by its day, and how many there are. This is what could still count. |
| L | Next goals | Under Próximos: no bar, the day it starts. |
| M | Past goals | Under Anteriores, newest first: *Alcançado*, or the amount reached. A long press removes a goal (any section). |
| N, O | Money on a delivery | The Valor row in the delivery sheet is always editable, filled in with the kind's price ("do tipo Mapa astral"). *Conta para* names the goal. |
| P | Delivery page | Valor gets its own row under Tipo (it was appended to the kind line). With no value it reads "Adicionar valor". |

### Decided unattended

- **"Considering the last goal we have"** is read as **goals follow each
  other**. A goal counts the money delivered from its start to its last day.
  Its start is the day after the last goal ends, or today if no goal is
  running. So two goals never count the same money, and the red line of the
  running goal starts at its own beginning, not at zero in some earlier
  month. A goal written while one is running goes under Próximos.
- **"By next week (last day of next month)"** is read as two suggestions:
  next week's Sunday, and next month's last day. Both are counted from the
  day the goal starts (today unless one is running). *Próximo mês* is
  preselected.
- **The pace is linear in calendar time** (nights and weekends count), the
  same as a delivery's red bar. No weighting by working days.
- **The money is billed money**: the `value` of deliveries **delivered**
  (`done_at`) between the start and the last day. Nothing changes here from
  today's rule ("money counts on delivery").
- **One tab, goals out of Entregas**: `ArtifactsPage(showGoals:)` and its
  goal strip go. The goals stay in `GET /artifacts` and in `ArtifactsCubit`,
  so there is no new repository.
- **Wording**: *Objetivo* everywhere a person reads it ("Novo objetivo",
  "Criar objetivo"). The code keeps `Goal`.

## Build brief

**Files the design session wrote or changed** (uncommitted, kept for the
build; the preview is deleted after Phase 4):

- `app/lib/goals_preview.dart`: the preview, scenes 1–5.
- `app/packages/artifacts/lib/src/view/goals_page.dart` (new):
  `GoalsPage`, the tab.
- `.../view/goal_card.dart`: rewritten as `GoalCard` (dual bar, pace tag,
  queue line), `GoalRow` (past goals), `goalQueue`.
- `.../view/goal_sheet.dart`: rewritten as amount + by when, with
  `goalStartAfter` and `goalSuggestions`. **`_save` still calls the old
  `addGoal(period:)`**: the build posts `{ target, deadline }`.
- `.../view/pace_bars.dart`: `PaceBar` (the bar alone) and `PaceKey` made
  public; `PaceBars` uses them.
- `.../view/artifact_sheet.dart`: Valor editable for every delivery,
  filled in with the kind's price, and always sent.
- `.../view/artifact_page.dart`: a Valor row of its own. **It has no tap
  yet.**
- `.../models/models.dart`: `Goal.isOverAt`, `lastDay`, `timeAt`,
  `expectedAt`.
- `.../format.dart`: `shortDay`; `goalLabel` is now "R$ 10.000 até 30 nov".
- `.../view/view.dart`: exports `goals_page.dart`.
- `app/lib/shell/view/shell_page.dart`: the 4th tab and the FAB on it.
- `app/packages/l10n/lib/arb/app_pt.arb` + `gen/`: the new strings.

**Server** (`server/src/artifacts/`, read `product/spec/artifacts.md` first):

- `goal` gets a `deadline` day (its last day). A migration fills it for
  existing goals from their current stretch. `period`, `starts` and
  `type_id` stay in the table but the money goal no longer reads them.
- `POST /goals { target, deadline }` (kind money is implied). The start is
  the day after the latest goal's deadline when that is still ahead,
  otherwise today. Refuse, in Portuguese, a deadline that is not after the
  start ("Escolha um dia depois de …") or a target ≤ 0.
- `GoalView`: `{ id, kind, target, start, end (day after deadline), done,
  queued }`. `done` is the value delivered in [start, end). `queued` is the
  value of open deliveries due by the deadline. Past goals are kept and
  measured too (Anteriores needs them).
- `PATCH /goals/:id { target?, deadline? }` so a goal can be edited (a
  tap on the card opens the sheet filled in). `DELETE` as today.
- `PATCH /artifacts/:id { value }` already exists. Check that `null`
  clears it.
- The agent's goal action (`agent/actions/`) follows the new args
  `{ target, deadline }`. Update its schema and its eval case.
- A row in `analytics/events.ts` for the PATCH.

**App:**

- `ArtifactsRepository.addGoal({ target, deadline })` and
  `updateGoal`; `update(id, value:)`; the cubit's `addGoal`, `editGoal`
  and `setValue`; the fakes in tests and `lib/demo/data/demo_artifacts.dart`.
- The delivery page's Valor row: a tap opens a money prompt (reuse
  `MoneyField` in an `AppPromptSheet` or a small sheet) → `setValue`.
- A tap on the running goal's card opens `GoalSheet` filled in to edit it.
- Remove `showGoals` and the goal strip from `ArtifactsPage`. The landing
  page's chapter (`lib/landing/widgets/chapters.dart`) still draws
  `GoalCard(goal:, now:)`; give it the demo's queue.
- `DemoShell` (`lib/demo/view/demo_app.dart`) gets the fourth tab like the
  real shell, or keeps three on purpose. The landing has three chapters, so
  **keep three** and say so.
- Tests: `artifacts_page_test.dart` opens `showGoalSheet(kind: count)`,
  which no longer exists. Replace it with goals-page tests: the empty state,
  the suggestions on a fixed clock (Wed 28 Oct → dom 8 nov / seg 30 nov),
  the start after a running goal, the pace tag at the 15 % edge, and a
  delivery's value from its kind. Run under several `TZ`s.
- Spec: rewrite "Goal" and the goal rules in `product/spec/artifacts.md`
  (or a new `product/spec/goals.md`), and add the fourth tab to AGENTS.md's
  shell paragraph.

**Open questions** (also on the issue):

1. Is "considering the last goal we have" meant as above (each goal starts
   where the last ended), or should the red line be a **cumulative** ramp
   from the last goal's target (e.g. R$ 8.000 at 30 set → R$ 10.000 at
   30 nov)?
2. Should the goals that have already passed stay listed (Anteriores), or
   should only the running and next ones show?

**Cost of the design session:** not measured here. The queue measures each
run and writes the figures in the PR.
