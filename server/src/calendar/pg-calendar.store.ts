import { Inject, Injectable } from '@nestjs/common';
import { and, asc, eq, gt, lt } from 'drizzle-orm';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { event, EventRow, routine, RoutineRow } from '../db/schema';
import { occurrencesBetween } from '../routines/routine-dates';
import { Zone } from '../time/zone';
import { CalendarStore, NewEvent, RoutinePatch } from './calendar.store';
import {
  CalendarEvent,
  CalendarRoutine,
  CalendarUser,
  routineDaysOf,
} from './calendar.types';

/** The calendar, in Postgres. */
@Injectable()
export class PgCalendarStore extends CalendarStore {
  constructor(@Inject(DB) private readonly _db: Database) {
    super();
  }

  async window(
    user: CalendarUser,
    from: Date,
    to: Date,
    zone: Zone,
  ): Promise<CalendarEvent[]> {
    await this._expand(user, from, to, zone);

    const rows = await this._db
      .select({ event, days: routine.days })
      .from(event)
      .leftJoin(routine, eq(event.routineId, routine.id))
      .where(
        and(
          eq(event.userId, user.id),
          eq(event.cancelled, false),
          lt(event.startTime, to),
          gt(event.endTime, from),
        ),
      )
      .orderBy(asc(event.startTime));

    return rows.map((row) => toEvent(row.event, row.days));
  }

  async get(
    user: CalendarUser,
    eventId: string,
  ): Promise<CalendarEvent | undefined> {
    if (!isUuid(eventId)) return undefined;

    const [row] = await this._db
      .select({ event, days: routine.days })
      .from(event)
      .leftJoin(routine, eq(event.routineId, routine.id))
      .where(
        and(
          eq(event.id, eventId),
          eq(event.userId, user.id),
          eq(event.cancelled, false),
        ),
      );

    return row === undefined ? undefined : toEvent(row.event, row.days);
  }

  async insert(user: CalendarUser, input: NewEvent): Promise<CalendarEvent> {
    const [row] = await this._db
      .insert(event)
      .values({
        userId: user.id,
        title: input.title,
        startTime: new Date(input.startTime),
        endTime: new Date(input.endTime),
        fixed: input.fixed,
        managed: input.managed ?? true,
        notBefore: dateOf(input.notBefore),
      })
      .returning();

    return toEvent(row, null);
  }

  async update(
    user: CalendarUser,
    next: CalendarEvent,
  ): Promise<CalendarEvent> {
    const [row] = await this._db
      .update(event)
      .set({
        title: next.title,
        startTime: new Date(next.startTime),
        endTime: new Date(next.endTime),
        fixed: next.fixed,
        started: next.started === true,
        pausedAt: dateOf(next.pausedAt),
        remainingSeconds:
          next.pausedAt === undefined || next.remainingSeconds === undefined
            ? null
            : Math.round(next.remainingSeconds),
        pausedSeconds: Math.round(next.pausedSeconds ?? 0),
        notBefore: dateOf(next.notBefore),
        notes: next.notes,
      })
      .where(and(eq(event.id, next.id), eq(event.userId, user.id)))
      .returning();

    if (row === undefined) throw new Error(`No event "${next.id}"`);

    return toEvent(row, next.routine ?? null);
  }

  async remove(user: CalendarUser, target: CalendarEvent): Promise<void> {
    const where = and(eq(event.id, target.id), eq(event.userId, user.id));

    if (target.routineId !== undefined) {
      await this._db.update(event).set({ cancelled: true }).where(where);
    } else {
      await this._db.delete(event).where(where);
    }
  }

  async routines(user: CalendarUser): Promise<CalendarRoutine[]> {
    const rows = await this._db
      .select()
      .from(routine)
      .where(eq(routine.userId, user.id));

    return rows.flatMap((row) => toRoutine(row) ?? []);
  }

  async insertRoutine(
    user: CalendarUser,
    input: Required<RoutinePatch> & { title: string },
  ): Promise<CalendarRoutine> {
    const [row] = await this._db
      .insert(routine)
      .values({
        userId: user.id,
        title: input.title,
        startTime: new Date(input.startTime),
        endTime: new Date(input.endTime),
        days: input.days,
      })
      .returning();

    return toRoutine(row)!;
  }

  async updateRoutine(
    user: CalendarUser,
    routineId: string,
    patch: RoutinePatch,
    now: Date,
  ): Promise<CalendarRoutine | undefined> {
    if (!isUuid(routineId)) return undefined;

    return this._db.transaction(async (tx) => {
      const [row] = await tx
        .update(routine)
        .set({
          ...(patch.title === undefined ? {} : { title: patch.title }),
          ...(patch.startTime === undefined
            ? {}
            : { startTime: new Date(patch.startTime) }),
          ...(patch.endTime === undefined
            ? {}
            : { endTime: new Date(patch.endTime) }),
          ...(patch.days === undefined ? {} : { days: patch.days }),
        })
        .where(and(eq(routine.id, routineId), eq(routine.userId, user.id)))
        .returning();
      if (row === undefined) return undefined;

      await tx
        .delete(event)
        .where(and(eq(event.routineId, routineId), gt(event.startTime, now)));

      return toRoutine(row);
    });
  }

  async removeRoutine(
    user: CalendarUser,
    routineId: string,
    now: Date,
  ): Promise<boolean> {
    if (!isUuid(routineId)) return false;

    return this._db.transaction(async (tx) => {
      await tx
        .delete(event)
        .where(
          and(
            eq(event.routineId, routineId),
            eq(event.userId, user.id),
            gt(event.startTime, now),
          ),
        );

      // The days already gone stay, as what happened; the foreign key lets
      // go of them.
      const removed = await tx
        .delete(routine)
        .where(and(eq(routine.id, routineId), eq(routine.userId, user.id)))
        .returning({ id: routine.id });

      return removed.length > 0;
    });
  }

  /** Writes down every day of every routine in the window not yet there. */
  private async _expand(
    user: CalendarUser,
    from: Date,
    to: Date,
    zone: Zone,
  ): Promise<void> {
    const routines = await this.routines(user);
    const rows = routines.flatMap((it) =>
      occurrencesBetween(it, from, to, zone).map((day) => ({
        userId: user.id,
        title: it.title,
        startTime: day.start,
        endTime: day.end,
        fixed: true,
        routineId: it.id,
        occurrence: day.start,
      })),
    );
    if (rows.length === 0) return;

    await this._db
      .insert(event)
      .values(rows)
      .onConflictDoNothing({ target: [event.routineId, event.occurrence] });
  }
}

function toEvent(row: EventRow, days: string | null): CalendarEvent {
  const routineDays = routineDaysOf(days);

  return {
    id: row.id,
    title: row.title,
    startTime: row.startTime.toISOString(),
    endTime: row.endTime.toISOString(),
    managed: row.managed,
    fixed: row.fixed,
    notes: row.notes,
    ...(row.pausedAt === null
      ? {}
      : {
          pausedAt: row.pausedAt.toISOString(),
          remainingSeconds: row.remainingSeconds ?? 0,
        }),
    ...(row.pausedSeconds > 0 ? { pausedSeconds: row.pausedSeconds } : {}),
    ...(row.started ? { started: true } : {}),
    ...(row.notBefore === null
      ? {}
      : { notBefore: row.notBefore.toISOString() }),
    ...(row.routineId === null ? {} : { routineId: row.routineId }),
    ...(routineDays === undefined ? {} : { routine: routineDays }),
  };
}

function toRoutine(row: RoutineRow): CalendarRoutine | undefined {
  const days = routineDaysOf(row.days);
  if (days === undefined) return undefined;

  return {
    id: row.id,
    title: row.title,
    startTime: row.startTime.toISOString(),
    endTime: row.endTime.toISOString(),
    days,
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
