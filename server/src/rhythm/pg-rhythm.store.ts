import { Inject, Injectable } from '@nestjs/common';
import { and, eq, gt } from 'drizzle-orm';
import { CalendarUser } from '../calendar/calendar.types';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { cycleStart, dayOff, rhythm } from '../db/schema';
import {
  DayKind,
  DayOff,
  DEFAULT_CYCLE_LENGTH,
  DEFAULT_PERIOD_LENGTH,
  DEFAULT_REST,
  RestRules,
  Rhythm,
} from '../time/day-kinds';
import { CycleSettings, RhythmStore, rhythmOf } from './rhythm.store';

/** The rhythm, in Postgres. */
@Injectable()
export class PgRhythmStore extends RhythmStore {
  constructor(@Inject(DB) private readonly _db: Database) {
    super();
  }

  async read(user: CalendarUser): Promise<Rhythm> {
    const [rows, starts, days] = await Promise.all([
      this._db.select().from(rhythm).where(eq(rhythm.userId, user.id)),
      this._db
        .select({ day: cycleStart.day })
        .from(cycleStart)
        .where(eq(cycleStart.userId, user.id)),
      this._db.select().from(dayOff).where(eq(dayOff.userId, user.id)),
    ]);
    const row = rows[0];

    return rhythmOf(
      row === undefined
        ? DEFAULT_REST
        : {
            saturday: row.saturdayKind as DayKind,
            sunday: row.sundayKind as DayKind,
            lightMinutes: row.lightMinutes,
          },
      row === undefined
        ? {
            length: DEFAULT_CYCLE_LENGTH,
            periodLength: DEFAULT_PERIOD_LENGTH,
            periodKind: 'light',
            nextStart: null,
          }
        : {
            length: row.cycleLength,
            periodLength: row.periodLength,
            periodKind: row.periodKind as DayKind,
            nextStart: row.nextStart,
          },
      starts.map((it) => it.day),
      days.map((it) => ({
        id: it.id,
        day: it.day,
        title: it.title,
        kind: it.kind === 'work' ? 'work' : 'off',
      })),
    );
  }

  async setRest(user: CalendarUser, rest: RestRules): Promise<void> {
    const values = {
      saturdayKind: rest.saturday,
      sundayKind: rest.sunday,
      lightMinutes: rest.lightMinutes,
    };
    await this._db
      .insert(rhythm)
      .values({ userId: user.id, ...values })
      .onConflictDoUpdate({ target: rhythm.userId, set: values });
  }

  async setCycle(user: CalendarUser, settings: CycleSettings): Promise<void> {
    const values = {
      cycleLength: settings.length,
      periodLength: settings.periodLength,
      periodKind: settings.periodKind,
      nextStart: settings.nextStart,
    };
    await this._db
      .insert(rhythm)
      .values({ userId: user.id, ...values })
      .onConflictDoUpdate({ target: rhythm.userId, set: values });
  }

  async addStart(user: CalendarUser, day: string): Promise<void> {
    await this._db
      .delete(cycleStart)
      .where(and(eq(cycleStart.userId, user.id), gt(cycleStart.day, day)));
    await this._db
      .insert(cycleStart)
      .values({ userId: user.id, day })
      .onConflictDoNothing();
  }

  async putDay(user: CalendarUser, day: Omit<DayOff, 'id'>): Promise<DayOff> {
    const [row] = await this._db
      .insert(dayOff)
      .values({ userId: user.id, ...day })
      .onConflictDoUpdate({
        target: [dayOff.userId, dayOff.day],
        set: { title: day.title, kind: day.kind },
      })
      .returning();
    return { id: row.id, day: row.day, title: row.title, kind: day.kind };
  }

  async replace(user: CalendarUser, it: Rhythm): Promise<void> {
    await this.setRest(user, it.rest);
    const cycle = it.cycle;
    await this.setCycle(user, {
      length: cycle?.length ?? DEFAULT_CYCLE_LENGTH,
      periodLength: cycle?.periodLength ?? DEFAULT_PERIOD_LENGTH,
      periodKind: cycle?.periodKind ?? 'light',
      nextStart: cycle?.nextStart ?? null,
    });
    if (cycle === undefined) {
      await this._db.delete(cycleStart).where(eq(cycleStart.userId, user.id));
    } else {
      await this.addStart(user, cycle.lastStart);
    }
    await this._db.delete(dayOff).where(eq(dayOff.userId, user.id));
    if (it.daysOff.length > 0) {
      await this._db
        .insert(dayOff)
        .values(it.daysOff.map((day) => ({ userId: user.id, ...day })));
    }
  }

  async removeDay(user: CalendarUser, id: string): Promise<boolean> {
    const rows = await this._db
      .delete(dayOff)
      .where(and(eq(dayOff.userId, user.id), eq(dayOff.id, id)))
      .returning({ id: dayOff.id });
    return rows.length > 0;
  }
}
