import { Injectable, NotFoundException } from '@nestjs/common';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { EventLayoutService } from '../events/event-layout.service';
import { Day, TimelineService } from '../events/timeline.service';
import { TaskStore } from '../tasks/task.store';
import { Task } from '../tasks/task.types';
import { ProjectStore } from './project.store';
import {
  NewProject,
  Project,
  ProjectEdit,
  ProjectTaskView,
  ProjectView,
  TaskPlace,
} from './project.types';

/**
 * The projects, and where their tasks are.
 *
 * A project's task is an ordinary task with `projectId`, on the day like any
 * other: written down at the end of the backlog, and from there moved,
 * begun and finished by the day itself, through [EventLayoutService], so
 * the time rules hold. A project only reads where its tasks are.
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
   * What was waiting in the backlog for it goes with it: nobody had given
   * it a turn yet. Whatever is on the day, or was done, stays, and simply
   * belongs to no project.
   */
  async remove(user: CalendarUser, id: string): Promise<void> {
    await this._require(user, id);

    for (const task of await this._tasks.ofProjects(user)) {
      if (task.projectId !== id) continue;
      if (task.backlog && task.doneAt === undefined) {
        await this._tasks.remove(user, task.id);
      } else {
        await this._tasks.update(user, { ...task, projectId: undefined });
      }
    }
    await this._projects.remove(user, id);
  }

  /** Writes a task down in a project, at the end of the backlog. */
  async addTask(
    user: CalendarUser,
    projectId: string,
    input: { title: string; minutes: number },
    trace: Trace,
  ): Promise<void> {
    await this._require(user, projectId);
    await this._layout.createTask(
      user,
      { ...input, backlog: true, projectId },
      trace,
    );
  }

  private async _require(user: CalendarUser, id: string): Promise<Project> {
    const project = await this._projects.get(user, id);
    if (project === undefined) {
      throw new NotFoundException(`No project "${id}"`);
    }
    return project;
  }
}

/** Where [task] is, and its hour when it is on [day]. */
function viewOf(task: Task, day: Day): ProjectTaskView {
  const place: TaskPlace =
    task.doneAt !== undefined
      ? 'done'
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
    notes: task.notes,
    minutes: task.minutes,
    place,
    ...(at === undefined ? {} : { at }),
    ...(task.doneAt === undefined ? {} : { doneAt: task.doneAt }),
  };
}
