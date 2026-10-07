import { Inject, Injectable } from '@nestjs/common';
import { and, asc, eq, isNull } from 'drizzle-orm';
import { CalendarUser } from '../calendar/calendar.types';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { task, TaskRow } from '../db/schema';
import { TaskStore } from './task.store';
import { NewTask, Task } from './task.types';

/** The tasks, in Postgres. */
@Injectable()
export class PgTaskStore extends TaskStore {
  constructor(@Inject(DB) private readonly _db: Database) {
    super();
  }

  async pending(user: CalendarUser): Promise<Task[]> {
    const rows = await this._db
      .select()
      .from(task)
      .where(and(eq(task.userId, user.id), isNull(task.doneAt)))
      .orderBy(asc(task.position));

    return rows.map(toTask);
  }

  async get(user: CalendarUser, taskId: string): Promise<Task | undefined> {
    if (!isUuid(taskId)) return undefined;

    const [row] = await this._db
      .select()
      .from(task)
      .where(and(eq(task.id, taskId), eq(task.userId, user.id)));

    return row === undefined ? undefined : toTask(row);
  }

  async insert(user: CalendarUser, input: NewTask): Promise<Task> {
    const [row] = await this._db
      .insert(task)
      .values({
        userId: user.id,
        title: input.title,
        minutes: input.minutes,
        position: input.position,
        notBefore: dateOf(input.notBefore),
        backlog: input.backlog ?? false,
      })
      .returning();

    return toTask(row);
  }

  async update(user: CalendarUser, next: Task): Promise<Task> {
    const [row] = await this._db
      .update(task)
      .set({
        title: next.title,
        notes: next.notes,
        minutes: next.minutes,
        position: next.position,
        notBefore: dateOf(next.notBefore),
        backlog: next.backlog,
        doneAt: dateOf(next.doneAt),
      })
      .where(and(eq(task.id, next.id), eq(task.userId, user.id)))
      .returning();

    if (row === undefined) throw new Error(`No task "${next.id}"`);

    return toTask(row);
  }

  async remove(user: CalendarUser, taskId: string): Promise<void> {
    if (!isUuid(taskId)) return;

    await this._db
      .delete(task)
      .where(and(eq(task.id, taskId), eq(task.userId, user.id)));
  }
}

function toTask(row: TaskRow): Task {
  return {
    id: row.id,
    title: row.title,
    notes: row.notes,
    minutes: row.minutes,
    position: row.position,
    backlog: row.backlog,
    ...(row.notBefore === null
      ? {}
      : { notBefore: row.notBefore.toISOString() }),
    ...(row.doneAt === null ? {} : { doneAt: row.doneAt.toISOString() }),
  };
}

function dateOf(value: string | undefined): Date | null {
  return value === undefined ? null : new Date(value);
}

/** Whether [value] can be an id at all, so a stray one is a 404, not a 500. */
function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    value,
  );
}
