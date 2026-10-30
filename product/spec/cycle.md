# Ciclo e folgas

The menstrual cycle and the days off, and what they do to the day.
Delivered in [#73](../delivery/2026-10-29-cycle/README.md).

## The rule

**Every date is one of three kinds: work, light or off.** The server works
it out (`server/src/time/day-kinds.ts`, `markOf`) from three sources:

| Source | Sets | Default |
|--------|------|---------|
| A date written down (Folgas, the calendar's rest row, the agent) | that date: `off` (a holiday, a trip), or `work` (a weekend day put back to work) | none |
| The weekend (Folgas) | every Saturday and every Sunday: `work`, `light` or `off` | **off** |
| The cycle (Ciclo) | every predicted day of the period | `light` |

**A date written down wins.** Otherwise the strictest of the weekend and
the period (off over light over work); between two as strict, the weekend
is named. A date put back to work undoes the weekend only: the period
still applies over it, so a worked Saturday in the period is light.

Only the period sets a kind. The other three phases are drawn and the
agent reads them, but they change nothing.

### What the kinds do

- **Off**: the queue (`relayout`, `time/scheduling.ts`) puts nothing
  there; a task that would land there hops to the next day that takes it.
  Fixed blocks, routines and **anchored tasks keep their hours**: what the
  person put on a day off by hand stays.
- **Light**: the queue puts on it at most `lightMinutes` (3 h unless
  changed) of **loose** tasks, counting the anchored ones already there. A
  delivery's task (`artifact_id`) hops over it. A task that hops leaves the
  queue's cursor where it was, so the loose tasks after it still fill the
  light day.
- **Time math counts working days** (`capacityShare`): a delivery's red
  bar (`timeGone`, from when it was begun to the end of its deadline's
  day), a goal's "what its days ask by now" (`GoalView.timeGone`), and the
  free minutes the month has for deliveries (`freeMinutes`, the agent's
  `fits`). Each working day counts its working hours; an off or light day
  counts nothing, since a delivery's tasks never go there. With no working
  time left at all the share is whole.

### The cycle

Kept as the starts written down (`cycle_start`, the last is `lastStart`)
and the settings (`rhythm`: `cycle_length` 21–45, `period_length` 1–10 and
shorter than the cycle, `period_kind`, `next_start`). The phases, for day
`d` of a cycle of length `L`:

| Phase | Days |
|-------|------|
| `menstrual` | 1 to the period's length |
| `follicular` | after it, to `L − 16` |
| `ovulatory` | `L − 15` to `L − 13` (ovulation is 14 days before the next period) |
| `luteal` | the rest |

**The prediction is the person's to correct.** `next_start` (a day after
today) is when the next period begins as they said: the cycle before it
runs from `lastStart` to it, and the cycles after count from it at the set
length. A start written down (`POST /rhythm/cycle/start`) always clears the
correction. The app's `Cycle` (`packages/cycle`) does the same arithmetic
to draw Ciclo's grid: a change to one is a change to both.

## Routes

All under `SessionGuard`; every one answers the whole rhythm:
`{ cycle: { lastStart, length, periodLength, periodKind, nextStart?,
predictedStart } | null, rest: { saturday, sunday, lightMinutes },
daysOff: [{ id, day, title, kind }] }` (dates from today on). None reads
the day, so none catches it up; the app asks for the timeline (and
Entregas) again after a write.

| Route | Does |
|-------|------|
| `GET /api/rhythm` | reads it |
| `PUT /api/rhythm/cycle` | the cycle whole: `lastStart` (today or before; a new one is a start written down), `length`, `periodLength`, `periodKind`, `nextStart` (after today, or null) |
| `POST /api/rhythm/cycle/start { day }` | a period began on `day` (today or before); starts after it are forgotten |
| `PATCH /api/rhythm/rest` | `saturday`, `sunday`, `lightMinutes` (0–480, by 5) |
| `POST /api/rhythm/days-off { day, kind, title }` | a date, today or ahead, `off` or `work`; a second write on the same date replaces it |
| `DELETE /api/rhythm/days-off/:id` | takes a date away (404 when it is not there) |

Refusals are in Portuguese. `GET /api/timeline` (and every write that
answers with it) carries `days`: a mark for every day drawn that is not a
plain working day or that has a cycle,
`{ day, kind, reason?, budgetMinutes?, cycle?: { day, length, phase } }`.

## The app

- `packages/cycle`: `Cycle`, `RestRules`, `DayOff`, `Rhythm`,
  `CycleRepository`, `CycleCubit` (one for the app, in `main.dart`; its
  writes re-read the timeline and Entregas), `CyclePage` (`/ciclo`),
  `DaysOffPage` (`/folgas`), `CycleDaySheet`, `DayOffSheet`,
  `RemoveDayOffSheet`. The pages read the rhythm again as they open.
- `packages/timeline`: `DayMark` (`TimelineState.marks`), `DayMarkTag` on
  the calendar's and Lista's day headings, `RestDayTile` (a day off with
  nothing on it is one row; a tap or a drop writes at its first hour; a
  weekend's offers **Trabalhar**, through the shell's `WorkOnDay`).
- The Feed tags today under its date (`_TodayMarks`); the Menu's **Ritmo**
  section opens Ciclo and Folgas.
- `Artifact.timeGone` and `Goal.timeGone` are the server's shares; a
  delivery changed on the phone since falls back to calendar time until
  the next read.

## The agent

The board's date table tells each day's kind, reason and cycle day; a line
says the weekend's rule, the light budget and the next period (never the
dates of past ones). The prompt says what light days and days off mean.
`at_hour` refuses a delivery's task on a light day or a day off unless
`rest_day` (the person confirmed it). The suggestion's turn is told when
today is not a working day. Four actions (`agent/actions/rhythm.ts`):
`period_started`, `predict_period`, `set_weekend`, `day_off`, each drawn
as a `set_rhythm` line; undo restores the rhythm whole (`Row` `rhythm`).
Eval: `light-day-delivery-task`.

## Health data

The cycle is health data. It stays in Postgres behind the session; the
analytics rows (`rhythm_changed`) carry the route only; nothing reads or
writes Apple Health.
