import * as path from 'path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import type { Database } from '../db/db';
import { schema, user } from '../db/schema';
import { CalendarUser } from './calendar.types';
import { PgCalendarStore } from './pg-calendar.store';

/**
 * The Postgres store, against a real Postgres.
 *
 * PGlite is Postgres compiled to WebAssembly and run in-process, so this
 * covers the actual SQL — the migrations, the window query, the upsert that
 * keeps a routine from being written twice — without a server to connect to.
 */
const ZONE = 'America/Sao_Paulo';
const OWNER: CalendarUser = { id: 'u1', timeZone: ZONE };
const OTHER: CalendarUser = { id: 'u2', timeZone: ZONE };

/** 10:00 in São Paulo on 10/03/2026. */
const NOW = new Date('2026-03-10T13:00:00Z');

function hours(from: Date, count: number): Date {
  return new Date(from.getTime() + count * 3_600_000);
}

describe('PgCalendarStore', () => {
  let client: PGlite;
  let store: PgCalendarStore;

  beforeEach(async () => {
    client = new PGlite();
    const db = drizzle(client, { schema });
    await migrate(db, {
      migrationsFolder: path.join(__dirname, '..', '..', 'drizzle'),
    });
    await db.insert(user).values([
      { id: OWNER.id, name: 'Owner', email: 'owner@example.com' },
      { id: OTHER.id, name: 'Other', email: 'other@example.com' },
    ]);

    // The pglite and node-postgres flavours of Drizzle answer the same
    // queries the same way; only the driver type differs.
    store = new PgCalendarStore(db as unknown as Database);
  });

  afterEach(async () => {
    await client.close();
  });

  it('writes a block down and reads it back in its window', async () => {
    const created = await store.insert(OWNER, {
      title: 'Revisar proposta',
      startTime: NOW.toISOString(),
      endTime: hours(NOW, 1).toISOString(),
      fixed: false,
    });

    const day = await store.window(OWNER, hours(NOW, -2), hours(NOW, 36), ZONE);

    expect(day).toEqual([
      {
        id: created.id,
        title: 'Revisar proposta',
        startTime: NOW.toISOString(),
        endTime: hours(NOW, 1).toISOString(),
        managed: true,
        fixed: false,
        notes: '',
      },
    ]);
  });

  it('keeps one person out of another one’s day', async () => {
    await store.insert(OWNER, {
      title: 'Meu',
      startTime: NOW.toISOString(),
      endTime: hours(NOW, 1).toISOString(),
      fixed: false,
    });

    expect(
      await store.window(OTHER, hours(NOW, -2), hours(NOW, 36), ZONE),
    ).toEqual([]);
  });

  it('round-trips the pause, the floor and the notes', async () => {
    const created = await store.insert(OWNER, {
      title: 'Escrever',
      startTime: NOW.toISOString(),
      endTime: hours(NOW, 1).toISOString(),
      fixed: false,
    });

    const saved = await store.update(OWNER, {
      ...created,
      started: true,
      pausedAt: hours(NOW, 0.5).toISOString(),
      remainingSeconds: 1799.6,
      pausedSeconds: 120,
      notBefore: hours(NOW, 3).toISOString(),
      notes: 'Começar pela seção 3.',
    });

    expect(saved).toMatchObject({
      started: true,
      pausedAt: hours(NOW, 0.5).toISOString(),
      remainingSeconds: 1800,
      pausedSeconds: 120,
      notBefore: hours(NOW, 3).toISOString(),
      notes: 'Começar pela seção 3.',
    });

    // And clearing them clears them.
    const cleared = await store.update(OWNER, {
      ...saved,
      started: undefined,
      pausedAt: undefined,
      remainingSeconds: undefined,
      pausedSeconds: undefined,
      notBefore: undefined,
    });

    expect(cleared.started).toBeUndefined();
    expect(cleared.pausedAt).toBeUndefined();
    expect(cleared.remainingSeconds).toBeUndefined();
    expect(cleared.pausedSeconds).toBeUndefined();
    expect(cleared.notBefore).toBeUndefined();
  });

  it('writes each day of a routine once, however often it is read', async () => {
    // Noon, every day.
    await store.insertRoutine(OWNER, {
      title: 'Almoço',
      startTime: '2026-03-10T15:00:00Z',
      endTime: '2026-03-10T16:00:00Z',
      days: 'daily',
    });

    const from = hours(NOW, -2);
    const to = hours(NOW, 36);
    await store.window(OWNER, from, to, ZONE);
    const day = await store.window(OWNER, from, to, ZONE);

    expect(day.map((it) => it.startTime)).toEqual([
      '2026-03-10T15:00:00.000Z',
      '2026-03-11T15:00:00.000Z',
    ]);
    expect(day.every((it) => it.fixed && it.routine === 'daily')).toBe(true);
  });

  it('skips the days a routine does not fall on', async () => {
    // Friday 13/03/2026 at noon, weekdays only.
    await store.insertRoutine(OWNER, {
      title: 'Daily',
      startTime: '2026-03-13T15:00:00Z',
      endTime: '2026-03-13T15:30:00Z',
      days: 'weekdays',
    });

    const day = await store.window(
      OWNER,
      new Date('2026-03-13T00:00:00Z'),
      new Date('2026-03-17T00:00:00Z'),
      ZONE,
    );

    // Friday, then straight to Monday.
    expect(day.map((it) => it.startTime)).toEqual([
      '2026-03-13T15:00:00.000Z',
      '2026-03-16T15:00:00.000Z',
    ]);
  });

  it('keeps a cancelled day of a routine cancelled', async () => {
    await store.insertRoutine(OWNER, {
      title: 'Almoço',
      startTime: '2026-03-10T15:00:00Z',
      endTime: '2026-03-10T16:00:00Z',
      days: 'daily',
    });

    const from = hours(NOW, -2);
    const to = hours(NOW, 36);
    const [today] = await store.window(OWNER, from, to, ZONE);
    await store.remove(OWNER, today);

    const day = await store.window(OWNER, from, to, ZONE);
    expect(day.map((it) => it.startTime)).toEqual(['2026-03-11T15:00:00.000Z']);
  });

  it('moves the days still ahead when a routine is retimed', async () => {
    const created = await store.insertRoutine(OWNER, {
      title: 'Almoço',
      startTime: '2026-03-10T15:00:00Z',
      endTime: '2026-03-10T16:00:00Z',
      days: 'daily',
    });

    const from = hours(NOW, -2);
    const to = hours(NOW, 36);
    await store.window(OWNER, from, to, ZONE);

    await store.updateRoutine(
      OWNER,
      created.id,
      {
        title: 'Almoço tarde',
        startTime: '2026-03-10T16:00:00Z',
        endTime: '2026-03-10T17:00:00Z',
      },
      NOW,
    );

    const day = await store.window(OWNER, from, to, ZONE);
    expect(day.map((it) => [it.title, it.startTime])).toEqual([
      ['Almoço tarde', '2026-03-10T16:00:00.000Z'],
      ['Almoço tarde', '2026-03-11T16:00:00.000Z'],
    ]);
  });

  it('keeps the days already gone when a routine is removed', async () => {
    const created = await store.insertRoutine(OWNER, {
      title: 'Café',
      // 08:00, which at NOW has already happened today.
      startTime: '2026-03-10T11:00:00Z',
      endTime: '2026-03-10T11:30:00Z',
      days: 'daily',
    });

    await store.window(OWNER, hours(NOW, -4), hours(NOW, 36), ZONE);
    expect(await store.removeRoutine(OWNER, created.id, NOW)).toBe(true);

    const day = await store.window(OWNER, hours(NOW, -4), hours(NOW, 36), ZONE);
    expect(day.map((it) => it.startTime)).toEqual(['2026-03-10T11:00:00.000Z']);
    expect(day[0].routineId).toBeUndefined();
    expect(await store.routines(OWNER)).toEqual([]);
  });

  it('treats an id that is not one as not found', async () => {
    expect(await store.get(OWNER, 'nope')).toBeUndefined();
    expect(await store.removeRoutine(OWNER, 'nope', NOW)).toBe(false);
  });
});
