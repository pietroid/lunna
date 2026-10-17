import * as fs from 'fs';
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

  it('keeps the tasks of a project on the day, done ones included', async () => {
    const project = await projects.insert(OWNER, { title: 'Site' });
    const waiting = await tasks.insert(OWNER, {
      title: 'Esperando',
      minutes: 30,
      position: 0,
      backlog: true,
      projectId: project.id,
    });
    const done = await tasks.insert(OWNER, {
      title: 'Feita',
      minutes: 30,
      position: 1,
      projectId: project.id,
    });
    await tasks.update(OWNER, { ...done, doneAt: '2026-03-10T12:00:00.000Z' });

    expect((await tasks.pending(OWNER)).map((it) => it.title)).toEqual([
      waiting.title,
    ]);
    expect((await tasks.ofProjects(OWNER)).map((it) => it.title)).toEqual([
      'Esperando',
      'Feita',
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

/**
 * The migration that ended parking, run on rows written the way the
 * migration before it left them.
 */
describe('0007_drop_parked', () => {
  const folder = path.join(__dirname, '..', '..', 'drizzle');

  async function run(client: PGlite, file: string): Promise<void> {
    const sql = fs.readFileSync(path.join(folder, file), 'utf8');
    for (const statement of sql.split('--> statement-breakpoint')) {
      await client.exec(statement);
    }
  }

  it('moves every parked task to the end of the backlog, in order', async () => {
    const client = new PGlite();
    const files = fs
      .readdirSync(folder)
      .filter((it) => it.endsWith('.sql'))
      .sort();
    for (const file of files.filter((it) => it < '0007')) {
      await run(client, file);
    }
    await client.exec(`
      INSERT INTO "user" (id, name, email) VALUES
        ('u1', 'Owner', 'owner@example.com'),
        ('u2', 'Other', 'other@example.com');
      INSERT INTO project (id, user_id, title) VALUES
        ('00000000-0000-4000-8000-000000000001', 'u1', 'Site');
      INSERT INTO task (user_id, title, minutes, position, backlog, parked, project_id) VALUES
        ('u1', 'Na fila', 30, 0, false, false, null),
        ('u1', 'Depois', 30, 4, true, false, null),
        ('u1', 'Segunda', 30, 7, false, true, '00000000-0000-4000-8000-000000000001'),
        ('u1', 'Primeira', 30, 2, false, true, '00000000-0000-4000-8000-000000000001'),
        ('u2', 'Sozinha', 30, 9, false, true, null);
    `);

    await run(client, '0007_drop_parked.sql');

    const rows = await client.query<{
      user_id: string;
      title: string;
      backlog: boolean;
      position: number;
    }>(
      'SELECT user_id, title, backlog, position FROM task ORDER BY user_id, backlog, position',
    );
    expect(
      rows.rows.map((it) => [it.user_id, it.title, it.backlog, it.position]),
    ).toEqual([
      ['u1', 'Na fila', false, 0],
      ['u1', 'Depois', true, 4],
      ['u1', 'Primeira', true, 5],
      ['u1', 'Segunda', true, 6],
      ['u2', 'Sozinha', true, 0],
    ]);
    await client.close();
  });
});
