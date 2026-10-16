import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { EventLayoutService } from '../events/event-layout.service';
import { Day, TimelineService } from '../events/timeline.service';
import { TaskStore } from '../tasks/task.store';
import { Task } from '../tasks/task.types';
import { ProjectStore } from './project.store';
import {
  NewProject,
  Placement,
  Project,
  ProjectEdit,
  ProjectTaskView,
  ProjectView,
  TaskPlace,
} from './project.types';

/**
 * The projects, and where their tasks are.
 *
 * A project's task is an ordinary task with `projectId`. It starts parked in
 * the project, where the day never sees it. Letting it out puts it in the
 * backlog, the queue or at an hour, and from then on the day treats it like
 * any other: every change to it on the day goes through
 * [EventLayoutService], so the time rules hold.
 */
@Injectable()
export class ProjectsService {
  constructor(
    private readonly _projects: ProjectStore,
    private readonly _tasks: TaskStore,
    private readonly _timeline: TimelineService,
    private readonly _layout: EventLayoutService,
  ) {}

  /**
   * Every project with its tasks, each task with its place and, when it is
   * on the day, the hour this read lays it out at.
   */
  async list(user: CalendarUser, now = new Date()): Promise<ProjectView[]> {
    const [projects, tasks, day] = await Promise.all([
      this._projects.list(user),
      this._tasks.ofProjects(user),
      this._timeline.day(user, 1, now),
    ]);

    return projects.map((project) => ({
      id: project.id,
      title: project.title,
      notes: project.notes,
      deadline: project.deadline ?? null,
      createdAt: project.createdAt,
      doneAt: project.doneAt ?? null,
      tasks: tasks
        .filter((task) => task.projectId === project.id)
        .map((task) => viewOf(task, day)),
    }));
  }

  async create(user: CalendarUser, input: NewProject): Promise<void> {
    await this._projects.insert(user, input);
  }

  async edit(
    user: CalendarUser,
    id: string,
    edit: ProjectEdit,
    now = new Date(),
  ): Promise<void> {
    const project = await this._require(user, id);
    const next: Project = { ...project };
    if (edit.title !== undefined) next.title = edit.title;
    if (edit.notes !== undefined) next.notes = edit.notes;
    if (edit.deadline === null) delete next.deadline;
    if (typeof edit.deadline === 'string') next.deadline = edit.deadline;
    if (edit.done === true && project.doneAt === undefined) {
      next.doneAt = now.toISOString();
    }
    if (edit.done === false) delete next.doneAt;

    await this._projects.update(user, next);
  }

  /**
   * Removes a project.
   *
   * What only the project could see goes with it. Whatever was let out onto
   * the day, or was done, stays, and simply belongs to no project.
   */
  async remove(user: CalendarUser, id: string): Promise<void> {
    await this._require(user, id);

    for (const task of await this._tasks.ofProjects(user)) {
      if (task.projectId !== id) continue;
      if (task.parked === true) {
        await this._tasks.remove(user, task.id);
      } else {
        await this._tasks.update(user, { ...task, projectId: undefined });
      }
    }
    await this._projects.remove(user, id);
  }

  /** Writes a task down in a project, parked at the end of its tasks. */
  async addTask(
    user: CalendarUser,
    projectId: string,
    input: { title: string; minutes: number },
  ): Promise<void> {
    await this._require(user, projectId);
    const parked = await this._parkedIn(user, projectId);

    await this._tasks.insert(user, {
      title: input.title,
      minutes: input.minutes,
      position: (parked.at(-1)?.position ?? -1) + 1,
      projectId,
      parked: true,
    });
  }

  /**
   * Moves a project's task to [placement].
   *
   * Out of the project it goes in at the end of the backlog first, and then,
   * for the queue or an hour, the day moves it as a drag would. Back into
   * the project it leaves the day, which a begun task cannot do: its hour
   * is already a fact.
   */
  async placeTask(
    user: CalendarUser,
    projectId: string,
    taskId: string,
    placement: Placement,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    await this._require(user, projectId);
    let task = await this._tasks.get(user, taskId);
    if (
      task === undefined ||
      task.projectId !== projectId ||
      task.cancelled === true
    ) {
      throw new NotFoundException(`No task "${taskId}"`);
    }
    const { place } = placement;
    trace.log('project.place', { projectId, taskId, place });

    // A done task taken back is parked again first, and goes on from there.
    if (task.doneAt !== undefined) {
      if (place === 'done') return;
      task = await this._park(user, { ...task, doneAt: undefined }, undefined);
    }

    if (place === 'project') {
      if (task.parked !== true) {
        const day = await this._timeline.day(user, 1, now);
        if (day.live.has(task.id)) {
          throw new BadRequestException(
            'Esta tarefa já começou. Pare ou termine antes de devolvê-la ao projeto.',
          );
        }
      }
      await this._park(user, task, placement.index);
      return;
    }

    if (place === 'done') {
      if (task.parked === true) {
        await this._tasks.update(user, {
          ...task,
          parked: false,
          doneAt: now.toISOString(),
        });
      } else {
        await this._layout.doneTask(user, task.id, trace, now);
      }
      return;
    }

    if (task.parked === true) task = await this._unpark(user, task, now);

    if (place === 'backlog') {
      if (task.backlog) return;
      const day = await this._timeline.day(user, 1, now);
      await this._layout.moveTask(
        user,
        { taskId: task.id, index: day.backlog.length, backlog: true },
        trace,
        now,
      );
      return;
    }

    if (place === 'scheduled') {
      await this._layout.editTask(
        user,
        task.id,
        { startTime: placement.at },
        trace,
        now,
      );
      return;
    }

    // The queue: at its end, as a task added there would be. One already
    // in it, or begun, is on the day already and stays where it is.
    if (task.backlog || task.notBefore !== undefined) {
      await this._layout.moveTask(
        user,
        { taskId: task.id, index: Number.MAX_SAFE_INTEGER },
        trace,
        now,
      );
    }
  }

  private async _require(user: CalendarUser, id: string): Promise<Project> {
    const project = await this._projects.get(user, id);
    if (project === undefined) {
      throw new NotFoundException(`No project "${id}"`);
    }
    return project;
  }

  /** The tasks parked in [projectId], in their order. */
  private async _parkedIn(
    user: CalendarUser,
    projectId: string,
  ): Promise<Task[]> {
    return (await this._tasks.ofProjects(user)).filter(
      (it) =>
        it.projectId === projectId &&
        it.parked === true &&
        it.doneAt === undefined,
    );
  }

  /**
   * Parks [task] in its project: at [index] among the tasks parked there,
   * where it already is when it was parked and no index is given, or at the
   * end.
   */
  private async _park(
    user: CalendarUser,
    task: Task,
    index: number | undefined,
  ): Promise<Task> {
    const others = (await this._parkedIn(user, task.projectId!)).filter(
      (it) => it.id !== task.id,
    );
    let position = task.position;
    if (index !== undefined || task.parked !== true) {
      const at = Math.min(index ?? others.length, others.length);
      const before = others[at - 1]?.position;
      const after = others[at]?.position;
      position =
        before === undefined && after === undefined
          ? 0
          : before === undefined
            ? after - 1
            : after === undefined
              ? before + 1
              : (before + after) / 2;
    }

    return this._tasks.update(user, {
      ...task,
      parked: true,
      backlog: false,
      notBefore: undefined,
      position,
    });
  }

  /** Lets [task] out of its project, at the end of the backlog. */
  private async _unpark(
    user: CalendarUser,
    task: Task,
    now: Date,
  ): Promise<Task> {
    const day = await this._timeline.day(user, 1, now);

    return this._tasks.update(user, {
      ...task,
      parked: false,
      backlog: true,
      notBefore: undefined,
      position: (day.backlog.at(-1)?.position ?? -1) + 1,
    });
  }
}

/** Where [task] is, and its hour when it is on [day]. */
function viewOf(task: Task, day: Day): ProjectTaskView {
  const place: TaskPlace =
    task.doneAt !== undefined
      ? 'done'
      : task.parked === true
        ? 'project'
        : task.backlog
          ? 'backlog'
          : task.notBefore !== undefined
            ? 'scheduled'
            : 'queue';
  const live = day.live.get(task.id);
  const at =
    place === 'queue' || place === 'scheduled'
      ? (live?.startTime ?? day.placed.get(task.id)?.start.toISOString())
      : undefined;

  return {
    id: task.id,
    title: task.title,
    minutes: task.minutes,
    place,
    ...(at === undefined ? {} : { at }),
    ...(task.doneAt === undefined ? {} : { doneAt: task.doneAt }),
  };
}
