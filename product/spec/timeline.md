# The timeline: Lista and Calendário

`TimelineList` draws the day two ways. **Since #77 the app shows only
Calendário** (Ver calendário, `DayPage`): Plano is the list. Lista below is
still what `TimelineList(mode: list)` and the landing's demo draw
(`TimelineModeCubit`):

- **Lista**: the tasks alone, each as tall as it needs, in three stages
  that are always drawn, each headed like a day of the calendar: **Agora**
  (the running task, the break, or `DayOverTile` outside the working day),
  **one day** of tasks with an hour, **Ainda hoje** while the working day is
  open and has tasks left (or nothing is queued at all), otherwise
  **Amanhã** (`_listDay`), and **Para depois** (the backlog, the loose
  tasks only: a delivery's backlog is drawn on its page, not here, and a
  drop still counts it, `_wholeOf`). Tasks queued
  after that day are not drawn: one line counts them, "Mais N tarefas
  adiante · Ver no calendário", which switches to Calendário. The days of
  routines are drawn on the calendar only, and come into the list once
  their hour has come or they are running (`inList`, which is also what a
  drop's `index` counts). A drag moves a task within either or across the
  line; the move carries `backlog: true` when it lands below it. A running
  task dropped in the backlog stops. The day and the backlog each end in a
  **+** that writes something down at its end.

  **The delivery is the card.** Tasks of one delivery that follow each
  other (`deliveryRuns`) are one `DeliveryTile`: the delivery's name, the
  run's hours, and under it only the **next** task. A tap opens the
  **delivery** (`onDeliveryTap`, on Pendentes); to a drag the card is that
  next task, and a drop under it lands after the whole run. Agora's run
  keeps the running task's controls and ends in `RunBar`, a piece per task
  of the run. A task with no delivery keeps its `EventTile` and opens its
  own page. A delivery's own Pendentes (`only:`) has Tempo's stages, a card
  per task: Agora when one of its tasks runs, the one day, a line counting
  the later ones ("Ver os próximos dias", which draws them there under
  their dates), and its Para depois.
- **Calendário**: everything, to scale, day after day. Scrolling near the
  end asks for another week (`TimelineExtended`), up to 120 days. **Agora**
  is always drawn, the break with its line whenever nothing runs, and a
  task let go on it is begun. Its task plays and pauses from the round
  button before the title, as on Plano (a waiting task begins from it);
  the quiet row keeps −10, +10 and ✓. Play on the calendar is the app's
  (`TimelineList.onPlay`), so a task over an hour asks how much. A card tall enough for a second line (72 px
  drawn) shows its delivery and the start of its notes under the title
  (`notesPreview`, up to 3 lines); a shorter one shows no notes at all and
  marks a delivery's task with the stack. A card is never taller for it.
  Tasks of one delivery that follow each other with no room drawn between
  them are **one block** as tall as theirs together, each task a line at
  its hour when there is a line's room for each (else the next task alone),
  and each line is its task to a drag, a nudge or a swap; a run's seam is
  not pulled. A tap on any line, or on a delivery's lone task, opens the
  delivery, as in Lista. Agora's run draws every line, with the running
  one's controls. A delivery's lone task is the card it always was. Every free
  stretch carries a small **+**
  and its hours, both stuck to the top of the part of it in sight (placed
  while painting, so they never lag the scroll); the hours run from the
  first one in sight, which is where the + writes.

  A drag on the calendar starts as a **nudge**: under 30 minutes of travel
  a task keeps its place and slides in time, five minutes at a time, and
  the run snapped to its end slides with it (`POST /tasks/:id/shift`).
  Past 30 minutes it is looking for somewhere else, and stays so: let go
  on another task that has not begun, the two **swap** (`POST
  /tasks/:id/swap { with }`): each takes the other's turn in the queue or
  its hour, so only what is between them moves, by the difference in
  length; on a heading or in the gap between two cards it takes that
  place; in free room, that hour. Held on its bottom
  edge, a card's **seam** comes up: the block above takes the new length,
  the snapped run below slides along keeping its own, and a block that is
  not snapped is left alone (`POST /tasks|events/:id/resize`). A drop at
  the top of a day asks for that day's first hour (`after`), since a place
  in the queue would pack the task back into what is left of the day
  before. While the running task is carried off Agora, Agora draws the
  break ("Agora fica livre") and the card says it is being paused. Outside
  the working day Agora is `DayOverTile`: nothing begins, a drop on it is
  refused, and it offers the Menu's hours.

In both, the heading of whatever is at the top stays pinned while it
scrolls, a chip brings Agora back once it is out of sight, and a card held
near the top or bottom edge scrolls the list, which is how a task goes to
another day. The `AppFab` writes wherever Tempo is looking (`TimelineAim`):
the first free hour in sight on the calendar, the end of the stage at the top
of the list.

There is one list per mode, in clock order, and the headings are cut out
of it by the clock rather than stored anywhere. `sectionOf` in
`events/event-sections.ts` is the whole filing system: `agora` for the hour
being lived through, `dia` for everything after it, under its `day`
(`YYYY-MM-DD` in the person's zone).

**An hour that has run out is not a section.** A block booked 11:20 to 11:25
is finished at 11:26 and is simply not drawn any more; the row stays,
because the hour happened. The app asks for the list again on each minute
boundary while it is in sight, and once at once when it is shown again
(`MinuteRefresh`); hidden, it asks nothing. Only finishing something *early* removes the row, since that frees
an hour still ahead.

Between cards the calendar draws the **free stretches** of the working day
(`TimelinePlan.freeSlots`). They are drop targets: a card lands where its
top edge is let go, on the five minutes nearest, sticking to the start of
the room or to the latest start that leaves a pause before the next block
when it is within ten minutes of either (`TimelineScale.landingIn`). A task
let go over one is posted as a move with `after` (that hour, its anchor)
and, when it had to be cut to fit, `minutes`; an event gets that hour
through `PATCH /api/events/:id`. A drop between two cards is a place in the
list of tasks, counting the tasks above it; right under a card that keeps
an hour (an event, or an anchored task) it is that card's end plus the
pause, as `after`, since a place in the queue says nothing about where such
a card is. Tapping empty room, or a +, opens the creation sheet on that
hour: flexible, as everything is, unless switched to Fixo. Between two
blocks, when the room left from that hour is 45 minutes or less, the sheet
opens on all of it (`FreeStretch.placementAt`).
