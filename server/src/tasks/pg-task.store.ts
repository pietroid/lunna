import { Inject, Injectable } from '@nestjs/common';
import { and, asc, eq, gt, isNotNull, isNull, notInArray } from 'drizzle-orm';
import { CalendarUser } from '../calendar/calendar.types';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { task, TaskRow } from '../db/schema';
import { TaskStore } from './task.store';
import { NewTask, RoutineTask, Task } from './task.types';

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
      .where(
        and(
          eq(task.userId, user.id),
          isNull(task.doneAt),
          eq(task.cancelled, false),
        ),
      )
      // The days of a routine all sit at position zero, which only means
      // something to the queue: their hours order them.
      .orderBy(asc(task.position), asc(task.notBefore), asc(task.createdAt));

    return rows.map(toTask);
  }

  async ofProjects(user: CalendarUser): Promise<Task[]> {
    const rows = await this._db
      .select()
      .from(task)
      .where(
        and(
          eq(task.userId, user.id),
          isNotNull(task.projectId),
          eq(task.cancelled, false),
        ),
      )
      .orderBy(asc(task.position), asc(task.createdAt));

    return rows.map(toTask);
  }

  async materialize(user: CalendarUser, days: RoutineTask[]): Promise<number> {
    if (days.length === 0) return 0;

    const rows = await this._db
      .insert(task)
      .values(
        days.map((day) => ({
          userId: user.id,
          title: day.title,
          minutes: day.minutes,
          position: 0,
          notBefore: new Date(day.occurrence),
          routineId: day.routineId,
          occurrence: new Date(day.occurrence),
        })),
      )
      .onConflictDoNothing({ target: [task.routineId, task.occurrence] })
      .returning({ id: task.id });

    return rows.length;
  }

  async dropRoutineAhead(
    user: CalendarUser,
    routineId: string,
    now: Date,
    keep: Set<string>,
  ): Promise<void> {
    if (!isUuid(routineId)) return;

    await this._db
      .delete(task)
      .where(
        and(
          eq(task.userId, user.id),
          eq(task.routineId, routineId),
          isNull(task.doneAt),
          gt(task.occurrence, now),
          ...(keep.size === 0 ? [] : [notInArray(task.id, [...keep])]),
        ),
      );
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
        projectId: input.projectId ?? null,
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
        cancelled: next.cancelled === true,
        projectId: next.projectId ?? null,
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
    ...(row.routineId === null ? {} : { routineId: row.routineId }),
    ...(row.occurrence === null
      ? {}
      : { occurrence: row.occurrence.toISOString() }),
    ...(row.cancelled ? { cancelled: true } : {}),
    ...(row.projectId === null ? {} : { projectId: row.projectId }),
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
