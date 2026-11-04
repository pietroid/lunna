# Plano consistent: a skeleton, Em seguida with every hour, play asks when

> Issue [#87](https://github.com/pietroid/lunna/issues/87), **mockup
> track** (it changes what Plano draws while loading, Em seguida, Para
> depois, the play sheet and a drop in Em seguida). Designed unattended;
> the person approves on the issue. The build is a new session:
> `/create build home-consistent`.

## 1. The prompt

From the issue, verbatim:

> Make the home consistent
>
> - Loading should be a skeleton on home instead of an empty screen
> - Review the calendar logic: when pausing a task, it should move the events (not the fixed one) to their proper scheduled times
> - "em seguida" events must have a concrete time and they are subject to changes based on any change on the schedule
> - Show all events of the day on "em seguida" and the next tasks that have a concrete time in the schedule too
> - When moving anything to "em seguida", we should have the same logic for tasks greater than 1 hour (to ask if we want to split or not). Also applies to moving to "agora"
> - When tapping play on any task we should ask if we want to move to the next available time on em seguida or if we want to start playing now, always for all of them. If there is an in progress task we are asked if the in progress is done or moved to later (as we have today)
> - Pending is working great, no complaints
> - Para depois should be a continuous list, without limiting. We should also have a + adicionar button to the end of it, similar to em seguida.
> - Em seguida should also have no limit.
> - change the "ver o dia" to "ver calendario" and move it to be on the side of "em seguida"

## 2. The design

![The board](img/mockup-board.png)

The screens one by one, for a phone: [1](img/mockup-1.png) ·
[2](img/mockup-2.png) · [3](img/mockup-3.png) · [4](img/mockup-4.png) ·
[5](img/mockup-5.png). The pins are in [board.json](board.json). The
real app (Lunna) draws them through `app/lib/home_consistent_preview.dart`:
the real `HomePage` on the demo's day at 10:00, seeded with a fuller day
(a standup, lunch, a call, two tasks tomorrow, four in Para depois).

### The rules

- **Loading is a skeleton.** Until the day first arrives
  (`TimelineStatus.initial`, or `isInitialLoad`), Plano draws its headings
  and, under each, its cards' skeletons (`PlanSkeletonCard`: the card's
  fill, the play's round room, a name line, the hours; Agora's a line
  taller). A reload keeps the cards on screen, as the calendar does.
- **Em seguida is everything with an hour, with no limit.** Every card of
  the first day that has any (today, while it has some left) after Agora,
  **its events too**, in clock order, then **every task the queue puts on
  the days after it**, under the day's name (*Amanhã*, *Sexta, 6 de
  nov.*). Each row is its start and end as the server's layout gives
  them, so they are never stale: any change to the day (a pause, a move,
  a task done early, a play) moves every task on the next read, and
  events never move. It ends in **+ Adicionar**, as now.
- **Ver calendário** (was *Ver o dia*) sits beside Em seguida's heading.
  Agora keeps the day's mark. Em seguida is always drawn, with *Nada
  marcado daqui para a frente.* when it is empty.
- **Para depois is the whole list**, no *Abrir a lista*, and ends in **+
  Adicionar** (`AppAddRow(dense: true)`), which writes at the end of the
  backlog.
- **Play asks when, always** (`PlayWhenSheet`), for every task that
  waits, wherever its play is (Plano, Pendentes, Para depois, the
  calendar): ***Começar agora*** (the accent), which is today's play, the
  guard and all when something runs; or ***Em seguida · 15:50***, the
  first place in the queue, after what runs, at the first room that fits
  it. **Over an hour it asks how much too**, in the same sheet: *30 min |
  1 h | Tudo · 2h*, Tudo chosen; the hour on *Em seguida* follows the
  piece (2 h hops lunch and the call to 15:50; 30 min is 10:38). A piece
  begun leaves the rest in Pendentes (as #85); a piece queued leaves the
  rest where it was.
- **A drop in Em seguida of a task over an hour asks how much goes
  there** (`PlaceSheet`, titled with that place's hour): 30 min (the
  accent), 1 h, *Tudo*; the rest stays where it was. A drop on Agora
  keeps asking as play over an hour does today (`PlaySheet.task`).
- **Pendentes is unchanged.**

### Decisions (the pins)

| Pin | Decision | Chosen |
|-----|----------|--------|
| 1A | Skeleton shape | the card itself, its parts as pulsing bars (`AppSkeleton(onFill)`), Agora's taller |
| 1B | What waits | only the cards; headings and Ver calendário are drawn at once |
| 1C | Pendentes while loading | not drawn, as when it is empty |
| 2A | Ver calendário | same pill and calendar icon, beside Em seguida's heading |
| 2B | Hours | the server's layout, re-read every minute and after every write |
| 2C | Events | every event of the day, sand fill and pin, between the tasks |
| 2D | Later days | the queue's tasks, under a day caption; later days' events stay on the calendar |
| 2E | Em seguida's end | + Adicionar, no cap |
| 3B | Para depois | the whole list, loose tasks then deliveries not begun |
| 3C | Para depois's end | + Adicionar, writing into the backlog |
| 4A | Play | always asks, every task that waits, every surface |
| 4B | How much | a segmented row in the same sheet, over an hour only, Tudo chosen |
| 4C | Começar agora | the accent; the guard as today when something runs |
| 4D | Em seguida | first place after what runs; the hour of the first room that fits the piece |
| 5A–B | Drop in Em seguida | asks how much over an hour; 30 min the accent; the rest stays |

The icon: none new. Ver calendário keeps `AppIcons.calendar`; events keep
`AppIcons.pin` and `AppIcons.repeat`.

### References

Drawn from known patterns, not browsed: **Structured**'s day list (every
item, timed, events and tasks in one stream, the next days under their
date), **Sunsama**'s "Start now / Add to today" choice when a task is
picked up, and **Things**' skeleton-free but instant headings (the
headings come first, the rows fill in).

### Decided unattended

- **Pausing (the server).** Today a paused block's end is dragged with
  the clock (`catchUp`) and the queue after it follows; nothing caps that
  drag at the next fixed block, so a long pause can run the paused block
  into an event. The build reviews it with an end-to-end spec: a running
  task paused before an event, the clock moved past the event; expected:
  the event keeps its hour, the paused block's owed work and every queued
  and anchored task after it land after the event, each at its proper
  hour. The board states the rule (2B); the fix, if the spec shows one, is
  server-only.
- **"Next tasks that have a concrete time"** read as: every task the queue
  places on the days after the first one drawn (`TimelineState.tasks`),
  under their day. Events of those days are left to the calendar, so Em
  seguida does not become the calendar.
- **"Next available time on Em seguida"** read as the first place in the
  queue (right after what runs, `index: 1`, else 0), whose hour is the
  first room that fits. Not the end of the queue.
- **The rest of a queued piece stays where the task was** (Para depois,
  Pendentes, or its place in the queue); only a piece *begun* sends the
  rest to Pendentes, as today.
- **Tudo is chosen by default** in the play sheet: the commonest tap
  (start the whole) stays one tap; a split is a choice.
- **Talk stays** in the play sheet as a text button (*Falar com a Lunna*);
  the drop sheet has none (arranging, not starting).
- **`LaterPage` and *Abrir a lista* go**: Plano draws the whole list.

### Open questions

- When the working day is over, Em seguida draws tomorrow's cards
  (the first day that has any), events included. Fine, or only tasks?

## Build brief

### Files the design wrote or changed (uncommitted, kept for the build)

- `app/lib/home_consistent_preview.dart`: the preview, scenes 1–5. Delete
  after Phase 4's prints.
- `app/lib/plan/view/plan_skeleton.dart` (new): `PlanSkeletonCard`.
- `app/lib/plan/view/home_page.dart`: the skeleton, Ver calendário on Em
  seguida, Em seguida always drawn and uncapped with `_DayOf` captions,
  Para depois whole with its + Adicionar; `kLaterOnHome` and `_OpenRow`
  removed (`onOpenLater` still a parameter: remove it with `LaterPage`).
- `app/lib/plan/view/plan_items.dart`: `next` uncapped (the day's cards,
  then later days' tasks), `kNextOnHome` removed; `playCard` asks when
  (`PlayWhenSheet`); the old play is `beginCard`; `nextIndexOf`,
  `nextSlotOf`; `PlanItems.sameDay`.
- `app/lib/plan/view/play_sheet.dart`: `PlayNow`, `PlayNext`,
  `PlayWhenSheet`, `PlaceSheet`, `_SheetFrame`.
- `app/lib/plan/view/plan_drag.dart`: a drop on Agora is `beginCard`; a
  drop in Em seguida over an hour asks (`PlaceSheet`); `slotHourOf`.
- `app/lib/plan/plan.dart` (export), `app_pt.arb` and `gen/`:
  `homeSeeCalendar`, `homeNextEmpty`, `playWhen*`, `playRestWaits`,
  `placePiece*`.

### What the build must do

Server:

1. **Split on a move that does not start.** `move { index, minutes }`
   today *cuts* the task to fit; add `split: true` (or a new route) so a
   piece takes the place and the rest stays where the task was (backlog
   keeps `backlog`/`pending`; a queued task keeps its turn). Refuse
   outside 5–480 in Portuguese, as play's piece is.
2. **The pause review** (Decided unattended): the end-to-end spec in
   `events/`, and the fix if it fails (likely: cap the paused drag at the
   next fixed block and lay the owed rest out after it, as overtime is
   capped).
3. Analytics: a new route or flag gets its row in `analytics/events.ts`.

App:

1. `PlayNext` and the Em seguida drop post the split (`EventMoved` gains
   `split`; the repository and `DemoTimelineRepository` carry it).
2. **A delivery's play asks when too**: `playPending` through
   `PlayWhenSheet` (title its next task, subtitle the delivery); Em
   seguida for a delivery queues its next task first (or a new piece of
   its name, as `ArtifactPlayed { minutes }` does, but not started).
3. The calendar's `TimelineList.onPlay` already calls `playCard`: check it
   asks on the calendar too, and that Agora's own play on a waiting task
   there does.
4. Remove `LaterPage`, its route and `onOpenLater`, and the screen
   `Para depois` from analytics' screens.
5. Tests (6 in `test/plan/home_page_test.dart` now fail, all asserting
   the old behaviour): *draws Em seguida from its start to its end*, *Em
   seguida queues four…*, *draws four of Para depois…*, *carries a pending
   delivery to Para depois*, *Em seguida play on a task over an hour asks
   how much first*, *Em seguida its + writes right after the last task*.
   Rewrite them for: the skeleton on the first read, no cap in either
   list, later days' captions, Ver calendário, play always asking (both
   choices, pieces), the drop sheet, Para depois's +.
6. Spec: update `product/spec/home.md` (Plano's table, Play, the drag)
   and AGENTS.md's shell paragraph (*Ver o dia* → *Ver calendário*, the
   caps gone, play asks when).

### Cost

Not run: the queue measures every run and writes the figures in the PR.
