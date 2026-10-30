import * as path from 'path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import { CalendarUser } from '../calendar/calendar.types';
import type { Database } from '../db/db';
import { schema, user } from '../db/schema';
import { PgRhythmStore } from './pg-rhythm.store';

/** The Postgres rhythm store, against PGlite: the migration and the queries. */
const OWNER: CalendarUser = { id: 'u1', timeZone: 'America/Sao_Paulo' };
const OTHER: CalendarUser = { id: 'u2', timeZone: 'America/Sao_Paulo' };

describe('PgRhythmStore', () => {
  let client: PGlite;
  let store: PgRhythmStore;

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
    store = new PgRhythmStore(pglite as unknown as Database);
  });

  afterEach(async () => {
    await client.close();
  });

  it('reads the weekend off and no cycle with nothing written', async () => {
    expect(await store.read(OWNER)).toEqual({
      rest: { saturday: 'off', sunday: 'off', lightMinutes: 180 },
      daysOff: [],
    });
  });

  it('keeps the cycle, its last start and the correction', async () => {
    await store.addStart(OWNER, '2026-09-30');
    await store.addStart(OWNER, '2026-10-28');
    await store.setCycle(OWNER, {
      length: 30,
      periodLength: 4,
      periodKind: 'off',
      nextStart: '2026-11-25',
    });
    expect((await store.read(OWNER)).cycle).toEqual({
      lastStart: '2026-10-28',
      length: 30,
      periodLength: 4,
      periodKind: 'off',
      nextStart: '2026-11-25',
    });
    // A start written earlier forgets the ones after it.
    await store.addStart(OWNER, '2026-10-26');
    expect((await store.read(OWNER)).cycle?.lastStart).toBe('2026-10-26');
    expect((await store.read(OTHER)).cycle).toBeUndefined();
  });

  it('writes one date per day, replacing it, and takes it away', async () => {
    const first = await store.putDay(OWNER, {
      day: '2026-11-20',
      kind: 'off',
      title: 'Feriado',
    });
    await store.putDay(OWNER, { day: '2026-11-20', kind: 'work', title: '' });
    await store.putDay(OWNER, { day: '2026-11-14', kind: 'work', title: '' });
    const { daysOff } = await store.read(OWNER);
    expect(daysOff.map((it) => [it.day, it.kind])).toEqual([
      ['2026-11-14', 'work'],
      ['2026-11-20', 'work'],
    ]);
    expect(await store.removeDay(OTHER, first.id)).toBe(false);
    expect(await store.removeDay(OWNER, daysOff[1].id)).toBe(true);
    expect((await store.read(OWNER)).daysOff).toHaveLength(1);
  });

  it('writes a rhythm back whole', async () => {
    await store.addStart(OWNER, '2026-10-28');
    await store.putDay(OWNER, { day: '2026-11-20', kind: 'off', title: 'X' });
    const was = await store.read(OWNER);
    await store.setRest(OWNER, {
      saturday: 'work',
      sunday: 'light',
      lightMinutes: 60,
    });
    await store.addStart(OWNER, '2026-10-30');
    await store.putDay(OWNER, { day: '2026-11-21', kind: 'work', title: '' });

    await store.replace(OWNER, was);
    expect(await store.read(OWNER)).toEqual(was);
  });
});
