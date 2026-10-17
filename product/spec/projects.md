# Projects

> Moved out of [AGENTS.md](../../AGENTS.md) to keep every session's context
> small. It is binding the same way: read it before changing this feature.

A project (`project` table) is a subject that outlives a day: a name,
notes, an optional **deadline** (a day, `YYYY-MM-DD`, due by its end) and
`done_at`. Its bar is time, from `created_at` to the deadline, never tasks.

**A project's task is an ordinary task** with `project_id`, and it starts
**parked** (`task.parked`): `TaskStore.pending` leaves it out, so the queue,
the backlog, the layout, reminders and the agent never see it. A project
with twenty tasks does not drop twenty on the backlog. Letting one out puts
it at the end of the backlog, then, for the queue or an hour, moves it
through `EventLayoutService` as a drag would; from there it is a task like
any other. Back into the project takes it off the day, except one that has
begun (refused, in Portuguese). Removing a project removes what only it
could see and lets the rest belong to no project.

The app files a project's tasks the way Lista files the day, in the same
cards: *Só no projeto*, *Fazer em breve* (with the hours the timeline gives
them on the same read), *Depois eu priorizo*, *N feitas*. Tapping a card
asks where it goes (`PlaceSheet`, an hour included); dragging it into
another stage moves it there, and dropping it on a parked card takes that
card's place. A move tells the timeline to read itself again
(`ProjectsCubit.onDayChanged`). Projetos reads itself again whenever it comes
to the front.

| Route | What it does |
|-------|--------------|
| `GET /projects` | `{ projects }`: each with `tasks: [{ id, title, minutes, place, at?, doneAt? }]` |
| `POST /projects` | `{ title, deadline? }` |
| `PATCH /projects/:id` | `{ title?, notes?, deadline? (day or null), done? }` |
| `DELETE /projects/:id` | parked tasks go with it; the rest stay |
| `POST /projects/:id/tasks` | `{ title, minutes }`, parked at the end |
| `POST /projects/:id/tasks/:taskId/place` | `{ place: project\|backlog\|queue\|scheduled\|done, at?, index? }` |

Every route answers with every project.
