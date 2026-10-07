import { randomUUID } from 'crypto';
import { CalendarUser } from '../calendar/calendar.types';
import { NewTask, Task } from './task.types';

/**
 * Where the tasks are kept.
 *
 * An abstract class rather than an interface so Nest can inject it by type.
 * Postgres in production ([PgTaskStore]); memory in the tests that drive the
 * timeline end to end ([MemoryTaskStore]).
 */
export abstract class TaskStore {
  /** Every task still to do, the backlog's included, in position order. */
  abstract pending(user: CalendarUser): Promise<Task[]>;

  /** One task by id, done or not. */
  abstract get(user: CalendarUser, taskId: string): Promise<Task | undefined>;

  abstract insert(user: CalendarUser, task: NewTask): Promise<Task>;

  /** Writes [task] back whole: every field is the new truth. */
  abstract update(user: CalendarUser, task: Task): Promise<Task>;

  /** Forgets a task entirely. */
  abstract remove(user: CalendarUser, taskId: string): Promise<void>;
}

/** The tasks, in memory. Behaves like the Postgres store. */
export class MemoryTaskStore extends TaskStore {
  private readonly _tasks = new Map<string, Task & { userId: string }>();

  pending(user: CalendarUser): Promise<Task[]> {
    return Promise.resolve(
      [...this._tasks.values()]
        .filter((it) => it.userId === user.id && it.doneAt === undefined)
        .sort((a, b) => a.position - b.position)
        .map(toTask),
    );
  }

  get(user: CalendarUser, taskId: string): Promise<Task | undefined> {
    const stored = this._tasks.get(taskId);
    if (stored === undefined || stored.userId !== user.id) {
      return Promise.resolve(undefined);
    }

    return Promise.resolve(toTask(stored));
  }

  insert(user: CalendarUser, task: NewTask): Promise<Task> {
    const stored = {
      id: randomUUID(),
      userId: user.id,
      title: task.title,
      notes: '',
      minutes: task.minutes,
      position: task.position,
      backlog: task.backlog ?? false,
      ...(task.notBefore === undefined ? {} : { notBefore: task.notBefore }),
    };
    this._tasks.set(stored.id, stored);

    return Promise.resolve(toTask(stored));
  }

  update(user: CalendarUser, task: Task): Promise<Task> {
    const stored = this._tasks.get(task.id);
    if (stored === undefined || stored.userId !== user.id) {
      return Promise.reject(new Error(`No task "${task.id}"`));
    }

    const next = { ...task, userId: user.id };
    this._tasks.set(task.id, next);

    return Promise.resolve(toTask(next));
  }

  remove(user: CalendarUser, taskId: string): Promise<void> {
    if (this._tasks.get(taskId)?.userId === user.id) {
      this._tasks.delete(taskId);
    }

    return Promise.resolve();
  }
}

function toTask(stored: Task & { userId?: string }): Task {
  const task: Partial<Task & { userId: string }> = { ...stored };
  delete task.userId;
  for (const key of ['notBefore', 'doneAt'] as const) {
    if (task[key] === undefined) delete task[key];
  }

  return task as Task;
}
