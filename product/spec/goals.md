# Objetivos (goals)

> Binding for `server/src/artifacts/` (the goal half) and the Objetivos tab
> in `app/packages/artifacts/`. Delivered in
> [product/delivery/2026-10-28-goals](../delivery/2026-10-28-goals/README.md).
> The deliveries themselves are in [artifacts.md](./artifacts.md).

The person reads **Objetivos** (one *objetivo*); code says `Goal`. A goal is
**an amount of money to bill by a day**: R$ 10.000 by 30 November. It is
the fourth tab, between Entregas and Menu (`AppIcons.goal`), and the `+`
on it writes one.

## The model

`goal`: `kind` (`money`; `count`, of one `type_id`, stays in the table and
the measuring, unused by the app), `target` (whole reais), `starts` (its
first day) and `deadline` (its last day, both `YYYY-MM-DD`, both counted).
`period` is what goals written before 2026-10-28 repeated over; migration
`0014` turned each into the stretch it was in then, and nothing reads it.

**Goals follow each other.** A new one starts the day after the latest
goal's deadline when that is today or later, otherwise today. So two goals
never count the same day, and the red of the running one starts at its
own beginning.

**No delivery names a goal.** A goal finds what counts towards it by
dates alone.

## The rules

- **Done** is the `value` of the deliveries delivered (`done_at`, in the
  person's zone) from `starts` to `deadline`. Money counts on delivery, as
  in Entregas.
- **Queued** (with **queuedCount**) is the value of the open deliveries
  worth something and due by its deadline: for the goal running today,
  overdue ones too (delivering them now counts now); for one ahead, only
  those due inside it; for one gone by, nothing. Each open delivery is
  queued for one goal at most. The whole value counts, however much of
  its work is done.
- **The bar** is a delivery's (`PaceBar`): green is `done / target`, red is
  the share of calendar time gone from the start of its first day to the
  end of its last (`Goal.timeAt`, nights count). The key says
  "R$ X faturados" and "R$ Y até hoje" (`target × time gone`).
- **The tag**: *R$ X abaixo do ritmo* (danger) when what the days ask leads
  what is in by more than 15 % of the target (`paceSlack`, the same slack
  as a delivery's); *R$ X acima do ritmo* when ahead; else *No ritmo*.
- **The forecast** line, on the running goal only and only when something
  is queued: "Com 3 entregas até 30 nov, chega a R$ 3.900", or "…, alcança
  o objetivo" when done + queued reaches the target.
- **Writing one** asks two things: how much, and by when. *Próximo mês*
  (the last day of the month after the one it starts in) is picked; *Próxima
  semana* is the Sunday of the week after its start's; *Outra data* opens
  the wheel, as does the day's row. A last day not after the first is
  refused (*"Escolha um dia depois de 01/12."*).
- **Changing one** (a tap on a goal not gone by): the same sheet, with its
  amount and its day; the day may not reach the next goal's first
  (*"O próximo objetivo começa em 01/12: escolha um dia antes."*).
- **The tab**: the running goal whole; *Próximos*, quiet, with the day each
  starts; *Anteriores*, newest first, *Alcançado* or what was reached. A long
  press removes any goal; the deliveries stay.
- **Money on a delivery**: every delivery has an editable **Valor** (the
  kind's price fills it in, on the sheet). On its page Valor is a row of its
  own; a tap opens `ValueSheet` (`PATCH /artifacts/:id { value }`, `null`
  takes it away).

## Routes

Every one answers the whole `ArtifactsAnswer`, whose `goals` are
`[{ id, kind, typeId, target, start, end (the day after its deadline), done,
queued, queuedCount }]`, by start.

| Route | What it does |
|-------|--------------|
| `POST /goals` | `{ target, deadline }`: a money goal, starting where the last ends or today |
| `PATCH /goals/:id` | `{ target?, deadline? }` |
| `DELETE /goals/:id` | the deliveries stay |

The agent writes one with `new_goal { target, deadline }` (a day word or
`YYYY-MM-DD`; it asks when either is missing) and removes one with
`remove_goal`; it has no verb to change one yet.

## The app

`GoalsPage` (the tab), `GoalCard` (the running and next goals),
`GoalRow` (past ones), `GoalSheet` (`goalStartAfter`, `goalSuggestions`;
with `goal:` it edits), `ValueSheet`, all over `ArtifactsCubit` (`addGoal`,
`editGoal`, `deleteGoal`, `setValue`). The landing's demo draws the
running goal on Entregas' chapter; the demo's shell keeps three tabs, as
the landing has three chapters.
