import * as fs from 'fs';
import * as path from 'path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import { CalendarUser } from '../calendar/calendar.types';
import type { Database } from '../db/db';
import { schema, user } from '../db/schema';
import { PgTaskStore } from '../tasks/pg-task.store';
import { PgArtifactStore } from './pg-artifact.store';

/**
 * The Postgres artifact store, and the task columns that point at it,
 * against a real Postgres (PGlite), migrations and all.
 */
const OWNER: CalendarUser = { id: 'u1', timeZone: 'America/Sao_Paulo' };
const OTHER: CalendarUser = { id: 'u2', timeZone: 'America/Sao_Paulo' };

describe('PgArtifactStore', () => {
  let client: PGlite;
  let artifacts: PgArtifactStore;
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
    artifacts = new PgArtifactStore(db);
    tasks = new PgTaskStore(db);
  });

  afterEach(async () => {
    await client.close();
  });

  it('keeps the catalogue, a delivery of a kind, and the goals', async () => {
    const shelf = await artifacts.insertCategory(OWNER, {
      name: 'Atendimentos',
      position: 0,
    });
    const type = await artifacts.insertType(OWNER, {
      categoryId: shelf.id,
      name: 'Mapa astral',
      minutes: 90,
      price: 350,
      position: 0,
    });
    const made = await artifacts.insert(OWNER, {
      title: 'Mapa · Ana',
      typeId: type.id,
      minutes: 90,
      value: 350,
      blockMinutes: 60,
    });
    const goal = await artifacts.insertGoal(OWNER, {
      kind: 'count',
      typeId: type.id,
      target: 3,
      period: 'week',
      starts: '2026-03-09',
    });

    expect(await artifacts.categories(OWNER)).toEqual([shelf]);
    expect(await artifacts.types(OWNER)).toEqual([type]);
    expect(type.blockMinutes).toBeUndefined();
    expect(await artifacts.get(OWNER, made.id)).toMatchObject({
      typeId: type.id,
      minutes: 90,
      value: 350,
      blockMinutes: 60,
      position: 0,
    });
    expect(await artifacts.goals(OWNER)).toEqual([goal]);
    expect(await artifacts.types(OTHER)).toEqual([]);

    await artifacts.removeGoal(OTHER, goal.id);
    expect(await artifacts.goals(OWNER)).toHaveLength(1);
    await artifacts.removeGoal(OWNER, goal.id);
    expect(await artifacts.goals(OWNER)).toEqual([]);
  });

  it('keeps an artifact, its deadline and its doneness', async () => {
    const created = await artifacts.insert(OWNER, {
      title: 'Site',
      deadline: '2026-03-24',
    });
    await artifacts.update(OWNER, {
      ...created,
      notes: 'Ideias',
      doneAt: '2026-03-20T12:00:00.000Z',
    });

    expect(await artifacts.get(OWNER, created.id)).toEqual({
      ...created,
      notes: 'Ideias',
      doneAt: '2026-03-20T12:00:00.000Z',
    });
    expect(await artifacts.list(OTHER)).toEqual([]);
    expect(await artifacts.get(OWNER, 'not-an-id')).toBeUndefined();
  });

  it('keeps the tasks of an artifact on the day, done ones included', async () => {
    const artifact = await artifacts.insert(OWNER, { title: 'Site' });
    const waiting = await tasks.insert(OWNER, {
      title: 'Esperando',
      minutes: 30,
      position: 0,
      backlog: true,
      artifactId: artifact.id,
    });
    const done = await tasks.insert(OWNER, {
      title: 'Feita',
      minutes: 30,
      position: 1,
      artifactId: artifact.id,
    });
    await tasks.update(OWNER, { ...done, doneAt: '2026-03-10T12:00:00.000Z' });

    expect((await tasks.pending(OWNER)).map((it) => it.title)).toEqual([
      waiting.title,
    ]);
    expect((await tasks.ofArtifacts(OWNER)).map((it) => it.title)).toEqual([
      'Esperando',
      'Feita',
    ]);
  });

  it('lets a task outlive its artifact', async () => {
    const artifact = await artifacts.insert(OWNER, { title: 'Site' });
    const task = await tasks.insert(OWNER, {
      title: 'Solta',
      minutes: 30,
      position: 0,
      artifactId: artifact.id,
    });

    await artifacts.remove(OWNER, artifact.id);

    expect((await tasks.get(OWNER, task.id))?.artifactId).toBeUndefined();
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

/**
 * The migrations that turned projects into deliveries, run on rows written
 * the way the migrations before them left them.
 */
describe('0009_artifacts and 0010_drop_projects', () => {
  const folder = path.join(__dirname, '..', '..', 'drizzle');

  async function run(client: PGlite, file: string): Promise<void> {
    const sql = fs.readFileSync(path.join(folder, file), 'utf8');
    for (const statement of sql.split('--> statement-breakpoint')) {
      await client.exec(statement);
    }
  }

  it('makes every project a one-off delivery that keeps its tasks', async () => {
    const client = new PGlite();
    const files = fs
      .readdirSync(folder)
      .filter((it) => it.endsWith('.sql'))
      .sort();
    for (const file of files.filter((it) => it < '0009')) {
      await run(client, file);
    }
    await client.exec(`
      INSERT INTO "user" (id, name, email) VALUES
        ('u1', 'Owner', 'owner@example.com');
      INSERT INTO project (id, user_id, title, notes, deadline, done_at, created_at) VALUES
        ('00000000-0000-4000-8000-000000000002', 'u1', 'Tese', 'Ideias', '2026-11-30', null, '2026-02-01'),
        ('00000000-0000-4000-8000-000000000001', 'u1', 'Site', '', null, '2026-03-01', '2026-01-01');
      INSERT INTO task (user_id, title, minutes, position, project_id) VALUES
        ('u1', 'Capítulo 2', 90, 0, '00000000-0000-4000-8000-000000000002'),
        ('u1', 'Solta', 30, 1, null);
    `);

    await run(client, '0009_artifacts.sql');
    await run(client, '0010_drop_projects.sql');

    const artifacts = await client.query<{
      title: string;
      notes: string;
      deadline: string | null;
      done: boolean;
      position: number;
      type_id: string | null;
    }>(
      'SELECT title, notes, deadline::text, done_at IS NOT NULL AS done, position, type_id FROM artifact ORDER BY position',
    );
    expect(artifacts.rows).toEqual([
      {
        title: 'Site',
        notes: '',
        deadline: null,
        done: true,
        position: 1,
        type_id: null,
      },
      {
        title: 'Tese',
        notes: 'Ideias',
        deadline: '2026-11-30',
        done: false,
        position: 2,
        type_id: null,
      },
    ]);
    const tasks = await client.query<{ title: string; artifact_id: string }>(
      'SELECT title, artifact_id FROM task ORDER BY position',
    );
    expect(tasks.rows).toEqual([
      {
        title: 'Capítulo 2',
        artifact_id: '00000000-0000-4000-8000-000000000002',
      },
      { title: 'Solta', artifact_id: null },
    ]);
    const tables = await client.query<{ name: string }>(
      "SELECT table_name AS name FROM information_schema.tables WHERE table_name = 'project'",
    );
    expect(tables.rows).toEqual([]);
    await client.close();
  });
});
