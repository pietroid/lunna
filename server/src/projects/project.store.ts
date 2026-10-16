import { randomUUID } from 'crypto';
import { CalendarUser } from '../calendar/calendar.types';
import { NewProject, Project } from './project.types';

/**
 * Where the projects are kept.
 *
 * Postgres in production ([PgProjectStore]); memory in the end-to-end tests
 * ([MemoryProjectStore]).
 */
export abstract class ProjectStore {
  /** Every project of [user], the oldest first. */
  abstract list(user: CalendarUser): Promise<Project[]>;

  abstract get(user: CalendarUser, id: string): Promise<Project | undefined>;

  abstract insert(user: CalendarUser, project: NewProject): Promise<Project>;

  /** Writes [project] back whole: every field is the new truth. */
  abstract update(user: CalendarUser, project: Project): Promise<Project>;

  abstract remove(user: CalendarUser, id: string): Promise<void>;
}

/** The projects, in memory. Behaves like the Postgres store. */
export class MemoryProjectStore extends ProjectStore {
  private readonly _projects = new Map<string, Project & { userId: string }>();

  list(user: CalendarUser): Promise<Project[]> {
    return Promise.resolve(
      [...this._projects.values()]
        .filter((it) => it.userId === user.id)
        .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
        .map(toProject),
    );
  }

  get(user: CalendarUser, id: string): Promise<Project | undefined> {
    const stored = this._projects.get(id);
    return Promise.resolve(
      stored === undefined || stored.userId !== user.id
        ? undefined
        : toProject(stored),
    );
  }

  insert(user: CalendarUser, project: NewProject): Promise<Project> {
    const stored = {
      id: randomUUID(),
      userId: user.id,
      title: project.title,
      notes: '',
      createdAt: new Date().toISOString(),
      ...(project.deadline === undefined ? {} : { deadline: project.deadline }),
    };
    this._projects.set(stored.id, stored);

    return Promise.resolve(toProject(stored));
  }

  update(user: CalendarUser, project: Project): Promise<Project> {
    if (this._projects.get(project.id)?.userId !== user.id) {
      return Promise.reject(new Error(`No project "${project.id}"`));
    }
    const next = { ...project, userId: user.id };
    this._projects.set(project.id, next);

    return Promise.resolve(toProject(next));
  }

  remove(user: CalendarUser, id: string): Promise<void> {
    if (this._projects.get(id)?.userId === user.id) this._projects.delete(id);
    return Promise.resolve();
  }
}

function toProject(stored: Project & { userId?: string }): Project {
  const project: Partial<Project & { userId: string }> = { ...stored };
  delete project.userId;
  if (project.deadline === undefined) delete project.deadline;
  if (project.doneAt === undefined) delete project.doneAt;

  return project as Project;
}
