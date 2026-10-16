import * as path from 'path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import { CalendarUser } from '../calendar/calendar.types';
import type { Database } from '../db/db';
import { schema, user } from '../db/schema';
import { PgTaskStore } from '../tasks/pg-task.store';
import { PgProjectStore } from './pg-project.store';

/**
 * The Postgres project store, and the task columns that point at it,
 * against a real Postgres (PGlite), migrations and all.
 */
const OWNER: CalendarUser = { id: 'u1', timeZone: 'America/Sao_Paulo' };
const OTHER: CalendarUser = { id: 'u2', timeZone: 'America/Sao_Paulo' };

describe('PgProjectStore', () => {
  let client: PGlite;
  let projects: PgProjectStore;
  let tasks: PgTaskStore;

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

    const db = pglite as unknown as Database;
    projects = new PgProjectStore(db);
    tasks = new PgTaskStore(db);
  });

  afterEach(async () => {
    await client.close();
  });

  it('keeps a project, its deadline and its doneness', async () => {
    const created = await projects.insert(OWNER, {
      title: 'Site',
      deadline: '2026-03-24',
    });
    await projects.update(OWNER, {
      ...created,
      notes: 'Ideias',
      doneAt: '2026-03-20T12:00:00.000Z',
    });

    expect(await projects.get(OWNER, created.id)).toEqual({
      ...created,
      notes: 'Ideias',
      doneAt: '2026-03-20T12:00:00.000Z',
    });
    expect(await projects.list(OTHER)).toEqual([]);
    expect(await projects.get(OWNER, 'not-an-id')).toBeUndefined();
  });

  it('keeps a parked task out of the day, and in its project', async () => {
    const project = await projects.insert(OWNER, { title: 'Site' });
    await tasks.insert(OWNER, {
      title: 'Parada',
      minutes: 30,
      position: 0,
      projectId: project.id,
      parked: true,
    });
    await tasks.insert(OWNER, {
      title: 'Solta',
      minutes: 30,
      position: 1,
      projectId: project.id,
    });

    expect((await tasks.pending(OWNER)).map((it) => it.title)).toEqual([
      'Solta',
    ]);
    expect(
      (await tasks.ofProjects(OWNER)).map((it) => [it.title, it.parked]),
    ).toEqual([
      ['Parada', true],
      ['Solta', undefined],
    ]);
  });

  it('lets a task outlive its project', async () => {
    const project = await projects.insert(OWNER, { title: 'Site' });
    const task = await tasks.insert(OWNER, {
      title: 'Solta',
      minutes: 30,
      position: 0,
      projectId: project.id,
    });

    await projects.remove(OWNER, project.id);

    expect((await tasks.get(OWNER, task.id))?.projectId).toBeUndefined();
  });
});
