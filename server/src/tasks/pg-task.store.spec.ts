import * as path from 'path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import { CalendarUser } from '../calendar/calendar.types';
import { PgCalendarStore } from '../calendar/pg-calendar.store';
import type { Database } from '../db/db';
import { schema, user } from '../db/schema';
import { PgTaskStore } from './pg-task.store';

/**
 * The Postgres task store, against a real Postgres.
 *
 * PGlite, as in `pg-calendar.store.spec.ts`: the migrations and the queries
 * as they run in production, with no server to connect to.
 */
const OWNER: CalendarUser = { id: 'u1', timeZone: 'America/Sao_Paulo' };
const OTHER: CalendarUser = { id: 'u2', timeZone: 'America/Sao_Paulo' };

describe('PgTaskStore', () => {
  let client: PGlite;
  let db: Database;
  let store: PgTaskStore;

  beforeEach(async () => {
    client = new PGlite();
    const pglite = drizzle(client, { schema });
    await migrate(pglite, {
      migrationsFolder: path.join(__dirname, '..', '..', 'drizzle'),
    });
    await pglite.insert(user).values([
      { id: OWNER.id, name: 'Owner', email: 'owner@example.com' },
      { id: OTHER.id, name: 'Other', email: 'other@example.com' },
    ]);

    db = pglite as unknown as Database;
    store = new PgTaskStore(db);
  });

  afterEach(async () => {
    await client.close();
  });

  it('reads the queue back in order of position', async () => {
    await store.insert(OWNER, { title: 'Segundo', minutes: 30, position: 1 });
    await store.insert(OWNER, { title: 'Primeiro', minutes: 30, position: 0 });
    await store.insert(OWNER, { title: 'Meio', minutes: 30, position: 0.5 });

    const queue = await store.pending(OWNER);

    expect(queue.map((it) => it.title)).toEqual([
      'Primeiro',
      'Meio',
      'Segundo',
    ]);
  });

  it('keeps one person out of another one’s queue', async () => {
    const mine = await store.insert(OWNER, {
      title: 'Meu',
      minutes: 30,
      position: 0,
    });

    expect(await store.pending(OTHER)).toEqual([]);
    expect(await store.get(OTHER, mine.id)).toBeUndefined();
  });

  it('round-trips the floor, the notes and being done', async () => {
    const created = await store.insert(OWNER, {
      title: 'Ler',
      minutes: 45,
      position: 0,
      notBefore: '2026-03-10T16:00:00.000Z',
    });

    expect(created).toMatchObject({
      notes: '',
      notBefore: '2026-03-10T16:00:00.000Z',
    });

    await store.update(OWNER, {
      ...created,
      notes: 'Capítulo 3',
      notBefore: undefined,
      doneAt: '2026-03-10T17:00:00.000Z',
    });

    const stored = await store.get(OWNER, created.id);
    expect(stored).toMatchObject({
      notes: 'Capítulo 3',
      doneAt: '2026-03-10T17:00:00.000Z',
    });
    expect(stored?.notBefore).toBeUndefined();
    // Done is off the queue, and still there.
    expect(await store.pending(OWNER)).toEqual([]);
  });

  it('lets go of the hour a removed task was taking', async () => {
    const task = await store.insert(OWNER, {
      title: 'Ler',
      minutes: 30,
      position: 0,
    });
    const calendar = new PgCalendarStore(db);
    const hour = await calendar.insert(OWNER, {
      title: 'Ler',
      startTime: '2026-03-10T13:00:00.000Z',
      endTime: '2026-03-10T13:30:00.000Z',
      fixed: false,
      started: true,
      taskId: task.id,
    });
    expect(hour).toMatchObject({ taskId: task.id, started: true });

    await store.remove(OWNER, task.id);

    expect(await store.get(OWNER, task.id)).toBeUndefined();
    expect((await calendar.get(OWNER, hour.id))?.taskId).toBeUndefined();
  });

  it('treats an id that is not one as not found', async () => {
    expect(await store.get(OWNER, 'nope')).toBeUndefined();
  });
});
