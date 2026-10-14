import { randomUUID } from 'crypto';
import { CalendarUser } from '../calendar/calendar.types';
import { NewTask, RoutineTask, Task } from './task.types';

/**
 * Where the tasks are kept.
 *
 * An abstract class rather than an interface so Nest can inject it by type.
 * Postgres in production ([PgTaskStore]); memory in the tests that drive the
 * timeline end to end ([MemoryTaskStore]).
 */
export abstract class TaskStore {
  /**
   * Every task still to do, the backlog's included, in position order.
   *
   * A day of a routine that was taken off is not one.
   */
  abstract pending(user: CalendarUser): Promise<Task[]>;

  /**
   * Writes down each day of a flexible routine that is not there yet, as a
   * task anchored at the routine's hour that day. A day already written,
   * done, begun or taken off is left exactly as it is. Answers with how many
   * were written.
   */
  abstract materialize(
    user: CalendarUser,
    days: RoutineTask[],
  ): Promise<number>;

  /**
   * Forgets every day of [routineId] still ahead of [now] that is not done,
   * apart from the tasks in [keep], which were begun. The next read writes
   * them again as the routine now says.
   */
  abstract dropRoutineAhead(
    user: CalendarUser,
    routineId: string,
    now: Date,
    keep: Set<string>,
  ): Promise<void>;

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
        .filter(
          (it) =>
            it.userId === user.id &&
            it.doneAt === undefined &&
            it.cancelled !== true,
        )
        .sort((a, b) => a.position - b.position)
        .map(toTask),
    );
  }

  materialize(user: CalendarUser, days: RoutineTask[]): Promise<number> {
    let written = 0;

    for (const day of days) {
      const exists = [...this._tasks.values()].some(
        (it) =>
          it.routineId === day.routineId && it.occurrence === day.occurrence,
      );
      if (exists) continue;

      const id = randomUUID();
      this._tasks.set(id, {
        id,
        userId: user.id,
        title: day.title,
        notes: '',
        minutes: day.minutes,
        position: 0,
        backlog: false,
        notBefore: day.occurrence,
        routineId: day.routineId,
        occurrence: day.occurrence,
      });
      written++;
    }

    return Promise.resolve(written);
  }

  dropRoutineAhead(
    user: CalendarUser,
    routineId: string,
    now: Date,
    keep: Set<string>,
  ): Promise<void> {
    for (const [id, task] of this._tasks) {
      if (
        task.userId === user.id &&
        task.routineId === routineId &&
        task.doneAt === undefined &&
        !keep.has(id) &&
        Date.parse(task.occurrence ?? '') > now.getTime()
      ) {
        this._tasks.delete(id);
      }
    }

    return Promise.resolve();
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
  if (task.cancelled !== true) delete task.cancelled;
  for (const key of [
    'notBefore',
    'doneAt',
    'routineId',
    'occurrence',
  ] as const) {
    if (task[key] === undefined) delete task[key];
  }

  return task as Task;
}
