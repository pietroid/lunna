# Play by strict rules: when, how much, and the pause

> Issue [#89](https://github.com/pietroid/lunna/issues/89), **mockup
> track** (it changes the play sheets, the guard and what a drop asks).
> Designed unattended; this is the draft the person approves on the
> issue. The build (`/create build dialogs`) starts from the Build brief.

## 1. The prompt

From the issue, verbatim:

> Dialogs improvements
>
> Play button still has some inconsistencies and is not very smart. Those are the strict rules for it:
>
> ## First stage: when
>
> 1. When there is nothing in progress (now), it should ask anyways, with the following suggestions: start now, start in 15 minutes. This only works if its not already at least 15 minutes from now.
>
> 2. When there is something in progress, it also will ask: start now, start after the next one (if its already after the now task, it will not ask this of course). The time should be always the next available time, regarldess if that fits or not. So if the task is 4h, even if the space available doesnt have 4h, it will go through because the next step will precisely ask about how much of that you want to do.
>
> 3. Consider always at least 20 min of time available to fit something, if not, suggest always the next one available that meet this criterium, otherwise the user would be denied in the next asking
>
> ## Second stage: how much
>
> The measure time available used for the next rules should alawys consider when you have put the task on the queue.
>
> 1. If the task is greater than 1 hour, it should always ask about how much you want to do. It depends, so we break into smaller scenarios
>
> 1.1. It has all the time available: the task is 4h and there is 5h available, the options would be "30 min", "1h", "The entire task"
>
> 1.2 It has not all the time available: The task is 4h, and there is just 2h13 available. It will precisely ask "30 min", "1h", "2h13". If it has just 20 min available (under 1h), it will just suggest "20 min"
>
> 2. If the task is 1 hour or smaller, and fits, nothing gets asked. If it doesnt fit, then the available total time gets suggested
>
> ## Dragging
>
> By dragging, the effects are very similar. The only thing is that we already make our decision in regards to the first stage. When dragging for now section for example, we consider that we want that now, the only thing needs to be asked is about is how much (before the release takes effect). If we put in the queue, it will already know which part of the queue it will be.
>
> ## If there is already a task in progress
>
> We already have a dialog, lets just improve it:
>
> After the user already has confirmed that the new task he wants to play is for now (and not for later), there would be a conflict, so the user is confirmed if he wants to proceed (yes or no), and the task is moved for pending always, considering the amount of minutes he has already done (to avoid asking too much questions based on availability, etc)
>
> ## About subtasking and tasks
>
> We can play from inside the task, and the same would follow based on this mechanism. When, how much (but based on subtask timing, not on the whole task). If the subtask is too small and fits, it isnt even needed to ask as rule 2 of the second stage.
>
> If more of 1h of this subtask, it will ask the same thing and another duplicated subtask should be created that reflects the remainder based on how much time the user wants to invest. So if the subtask is 2 hours and there is 40 minutes to be used now (and the user confirms), there will be another duplicate subtask which will be created with 1h20 and is still todo.
>
> The same thing happens for tasks. If the user choose a path to go partial, there should be a subtask for it and a subtask for the remainder.
>
> If this task is interrupted via another task that started playing, also, there should be split, with the part already done as a subtask and the part to be done as another subtask.
>
> The reason for all of this is that the math for the pending tasks should be sound

## 2. The design

![The board](img/mockup-board.png)

The screens one by one, for a phone: [1](img/mockup-1.png) ·
[2](img/mockup-2.png) · [3](img/mockup-3.png) · [4](img/mockup-4.png) ·
[5](img/mockup-5.png). The pins are in [board.json](board.json). Drawn by
the real app (Lunna) through `app/lib/dialogs_preview.dart`: the new
sheets over the demo's day at 10:00 (*Fazendo a Lunna* runs until 10:33,
the Standup is at 12:00).

### The flow

```
play ─▶ 1. when? ──now──▶ (something runs?) 3. pause it? ──yes──▶ 2. how much? ─▶ begins
                └─later─────────────────────────────────────────▶ 2. how much? ─▶ queued
drop on Agora ─────────▶ (something runs?) 3. pause it? ──yes──▶ 2. how much? ─▶ begins
drop in Em seguida / on free room ──────────────────────────────▶ 2. how much? ─▶ placed
```

### The rules

**The room** of an hour is the minutes from it to the next thing that
does not move (an event, an anchored task, a begun task's hour) or the
end of the working day, less the 5-minute pause. It is the server's
(`TimelinePlan`), measured where the task would go. **An hour with under
20 minutes of room is never offered** (`kPlayMinRoom`): the next one with
20 is.

**1. When** (`PlayWhenQuestion`), on every task that waits, from every
play (Plano, Pendentes, Para depois, the calendar, a delivery's page):

| Agora | Offered |
|-------|---------|
| nothing runs | ***Começar agora*** · ***Daqui a 15 min · 10:15*** (that hour anchored); when 15 min from now has under 20 min of room, ***Às 13:00***, the first hour that has |
| something runs | ***Começar agora*** · ***Depois de Fazendo a Lunna · 10:38*** (first in Em seguida, at the first hour after it with 20 min of room, **whether or not the whole fits**); not offered when the task is already next |
| now has under 20 min of room | *Começar agora* is not offered; the later hour is the accent |

**3. The pause** (`PauseQuestion`, replacing `GuardSheet`'s three
answers): after *Começar agora* (or a drop on Agora) while something
runs, one question, ***Pausar Fazendo a Lunna?*** — *Sim, pausar e
começar* / *Não*. Yes always pauses into **Pendentes** and **splits** what
ran: the minutes done become a subtask ticked off, the minutes left
another subtask, not done. No question about where the rest goes.

**2. How much** (`PlayMuchQuestion`), measured at the hour chosen (now,
the later hour, or where it was dropped), on the task, or on **the
subtask** when play is a subtask's:

| Task | Room | Asks |
|------|------|------|
| over 1 h | ≥ the task | *30 min* · *1h* · *Tudo · 4h* |
| over 1 h | 1 h to less than the task | *30 min* · *1h* · *2h13* (all the room) |
| over 1 h | under 1 h | only the room, *Fazer 40 min* |
| 1 h or less | ≥ the task | **nothing** |
| 1 h or less | less | only the room, *Fazer 20 min* |

**A piece splits.** Choosing less than the whole makes two subtasks: the
piece (begun, or placed at its hour) and the rest, not done.

- A loose task becomes a task with subtasks (`addSubtask`'s road: its row
  is the first subtask, cut to the piece; the rest is a new subtask). A
  piece begun leaves the rest in Pendentes; a piece queued leaves it where
  the task was.
- A subtask over the piece is cut to the piece and a **duplicate** with
  the rest is written right after it in its task (2 h, 40 min now → a
  copy of 1h20, still to do).
- So every task's Pendentes sum is the sum of its subtasks still to do,
  and what was done is a subtask ticked off with its real minutes.

**Dragging** answers *when* by where the card is let go: on Agora it
asks the pause (if something runs) and how much at now; in Em seguida or
on free room, how much at that place's hour. The card is not posted
until the last answer; a dismissed sheet leaves the day as it was.

### Decisions (the pins)

| Pin | Decision | Chosen |
|-----|----------|--------|
| 1A, 2A | The line under the title | *Nada rodando agora · 4h*, or *Fazendo a Lunna roda até 10:33 · 4h* |
| 1B | Começar agora | always the accent; hidden when now has under 20 min of room |
| 1C | The later hour, idle | *Daqui a 15 min · 10:15*, an anchor; *Às 13:00* when 15 min from now has no 20 min of room |
| 2C | The later hour, busy | *Depois de … · 10:38*: first in Em seguida, the first hour with 20 min of room; hidden when already next |
| 3A | The guard | one yes/no, *Pausar …?*; *Concluir o atual* and *Para depois* go |
| 3B | What a pause does | the running task splits into done + left subtasks, the rest in Pendentes |
| 3C | Não | changes nothing (no Cancelar under it) |
| 4A | The room | from the chosen hour to the next fixed thing or the day's end, named in the body |
| 4B | Pieces | 30 min (the accent) and 1 h, always over an hour |
| 4C | The most | *Tudo · 4h* when it fits, else the room (*1h55*); only the room under 1 h |
| 5A–B | Short | one button, *Fazer 20 min*; an hour or less that fits asks nothing |

The icon: none new. The sheets keep `_SheetFrame` (the page's ground,
the card radius) and `AppButton`.

### References

Drawn from known patterns, not browsed: **Sunsama**'s "Start now / Add
to today" when a task is picked up, **Structured**'s "how long" chips
sized to the gap before the next item, and **Motion**'s split of a task
into chunks that fit the free blocks, each its own row.

### Decided unattended

- **"This only works if it's not already at least 15 minutes from now"**
  read as rule 3 for the soon hour: *Daqui a 15 min* is offered when that
  hour has 20 min of room; otherwise the first hour that has, *Às hh:mm*.
  See the open question.
- **Now with under 20 min of room** (10 min before a meeting): *Começar
  agora* is not offered, by rule 3, rather than offering a piece under 20.
- **Order of the sheets after *Começar agora*** while something runs:
  when → pause → how much, so the room is measured with the running task
  already out of the way.
- **The guard's other answers go** (*Concluir o atual*, *Mandar para Para
  depois*): the issue says the running task is "moved for pending
  always". Finishing it stays Agora's ✓. `solve_current` and
  `later_current` stay on the server for older apps.
- **A piece of a loose task makes it a task with subtasks** (a delivery,
  in storage), as `+ Subtarefa` does: the piece is the first subtask (its
  row, cut), the rest a new one with the same title.
- **The rest keeps the title** (no "(resto)" suffix): two subtasks with
  one name, one done or begun, one not.
- **The accent stays on 30 min**, as #87 had it; the single-option sheet
  has its one button as the accent.
- **A drop of a task over an hour on free room** now asks how much there
  too (the issue's "very similar"); today only Em seguida and Agora ask.
- **Falar com a Lunna leaves the how-much sheet**: the issue lists the
  options exactly. The composer's + stays the way to talk.

### Open questions

- *Daqui a 15 min*: is it also hidden when the task is **already** queued
  15 minutes or more from now (it would pull it earlier), or is it
  offered then too? The design offers it always (with the 20 min rule).
- When a pause splits a running task that had done **under 5 minutes**,
  should the done subtask still be written, or the task simply paused
  whole? The design writes nothing under 5 minutes (no 2-minute rows).

## Build brief

Phase 3 starts here and Phase 4 removes this section.

### Files from the design (uncommitted)

- `app/lib/dialogs_preview.dart`: the preview, five scenes (`?s=1..5`).
- `app/lib/plan/view/play_sheet.dart`: appended `kPlayMinRoom`,
  `playPieces` (the how-much table), `PlayLater`, `PlayWhenQuestion`,
  `PlayMuchQuestion`, `PauseQuestion`; `_SheetFrame(cancel:)`. The old
  `PlayWhenSheet`, `PlaySheet`, `PlaceSheet`, `askPlay` are still there:
  the build replaces them with these.
- `app/packages/l10n/lib/arb/app_pt.arb` (+ gen): `playWhenIdle`,
  `playWhenBusy`, `playWhenSoon`, `playWhenAt`, `playWhenAfter`,
  `playMuchNowTitle`, `playMuchAtTitle`, `playMuchRoomUntil`,
  `playMuchRestNow`, `playMuchRestStays`, `playMuchShortTitle`,
  `playMuchShortBody`, `playMuchDo`, `playMuchUntil`, `playMuchDayEnd`,
  `guardPauseTitle`, `guardPauseBody`, `guardPauseYes`, `guardPauseNo`.
  The strings the old sheets used go when they do.

### Server

- **The room**: the timeline answers, for the hours play may offer, the
  room at each (or a route `GET /timeline/room?taskId=&at=`): now, the
  soon hour, the first hour after the running block, each moved to the
  first hour with ≥ 20 min of room, plus what bounds it (title and hour,
  or the day's end). One place, `TimelinePlan`, so the app does no
  layout of its own.
- **Split on a piece** (`move { start | index | after, minutes }` with a
  piece under the whole): a loose task becomes a task with subtasks
  (`ArtifactsService.addSubtask`'s road) — its row cut to the piece, a new
  row for the rest (same title), at its old place (begun: the top of
  Pendentes). A subtask is cut and duplicated in its delivery right after
  itself. Replaces `split: true` and the begun piece's rest in Pendentes.
- **Pause splits** (`timing { decision: pause_current }`): the running
  task's begun hour closes as a subtask done with the minutes it ran; the
  owed minutes are a new subtask, pending. Under 5 minutes run, it pauses
  whole (open question).
- **Soon** is an anchor (`move { after: now + 15 }`); *Depois de* is
  `index` 1 with `after` the offered hour when that hour is not the
  queue's own.
- End-to-end specs with the frozen clock: each row of the how-much table,
  the 20 min rule (a gap of 15 skipped), the two splits (sums of the
  parent's owed minutes before and after are equal), a subtask's
  duplicate.

### App

- Replace `askPlay` with the flow above (when → pause → how much), used by
  `playPending`, Plano's play, the calendar's `onPlay` and a delivery's
  page play on a subtask.
- `GuardSheet` becomes `PauseQuestion` (move it to `timeline`, which
  draws the guard), posting `pause_current` on yes.
- Drops: Agora → pause (if running) → how much at now; Em seguida and
  free room → how much at that hour. Post once, after the last answer.
- Widget tests: `playPieces` table, the when sheet's three shapes, the
  pause's yes/no, a drop over an hour asking how much.

### Cost

The queue measures this run and writes the figures in the PR
(`.tool/cost` skipped, as the queue asks).
