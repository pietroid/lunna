# Projects

> Moved out of [AGENTS.md](../../AGENTS.md) to keep every session's context
> small. It is binding the same way: read it before changing this feature.

A project (`project` table) is a subject that outlives a day: a name,
notes, an optional **deadline** (a day, `YYYY-MM-DD`, due by its end) and
`done_at`. Its bar is time, from `created_at` to the deadline, never tasks.

**A project's task is an ordinary task** with `project_id`, on the day like
any other. It is written down at the end of the backlog (*Depois eu
priorizo*), or wherever the day's own write puts it (`POST /tasks` with
`projectId`, checked against the person's projects and refused in
Portuguese otherwise), and from there it is moved, begun, finished and
deleted by the day's own routes, through `EventLayoutService`. There is no
parking any more: a project with twenty tasks puts twenty in the backlog
(migration `0007_drop_parked` moved every parked task to the end of its
person's backlog and dropped `task.parked`). Removing a project removes
what waits in the backlog for it and lets the rest (queued, anchored, done)
belong to no project.

The project page's **Tarefas** is Tempo's Lista itself (`TimelineList`
with `only`, the project's task ids, and `done`), so every gesture is
Tempo's: hold to move, carry right to finish, carry left to delete, tap to
open `EventPage`. Its stages are Tempo's, in Tempo's order: *Fazer em
breve*, *Depois eu priorizo*, then *N feitas* (newest first; tapping one
opens `EventPage` with `finished`, where only the name and notes change,
through `PATCH /tasks/:id`). A drop's place counts only the project's
cards, so `TimelineList._wholeOf` turns it into a place in the whole queue
or backlog (right under the card drawn above, or over the first one), and
the server keeps one meaning of `index`. A drop at the top of a filtered
list begins the task only when that is also the top of the whole day.
The page's + and the stages' + write into the project
(`writeDownOnTimeline(projectId:)`), without the Fixo switch, since an
event belongs to no project. Tempo's `AskDock` sits on Tarefas; nothing
floats over Notas. The page reads the projects again whenever the
timeline's tasks or backlog change. Notas/Tarefas is remembered per project
on the device (`project.tab.<id>`). Projetos reads itself again whenever it
comes to the front.

| Route | What it does |
|-------|--------------|
| `GET /projects` | `{ projects }`: each with `tasks: [{ id, title, notes, minutes, place: backlog\|queue\|scheduled\|done, at?, doneAt? }]` |
| `POST /projects` | `{ title, deadline? }` |
| `PATCH /projects/:id` | `{ title?, notes?, deadline? (day or null), done? }` |
| `DELETE /projects/:id` | backlog tasks go with it; the rest stay |
| `POST /projects/:id/tasks` | `{ title, minutes }`, at the end of the backlog |
| `POST /tasks` | the day's write, with `projectId` |

Every route under `/projects` answers with every project.
