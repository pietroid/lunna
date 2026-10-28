import * as path from 'path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import { PgArtifactStore } from '../artifacts/pg-artifact.store';
import { PgCalendarStore } from '../calendar/pg-calendar.store';
import { CalendarUser } from '../calendar/calendar.types';
import type { Database } from '../db/db';
import { schema, user } from '../db/schema';
import { PgTaskStore } from '../tasks/pg-task.store';
import { PLAN_TTL_MS } from './plan';
import { PgPlanStore } from './pg-plan.store';

/**
 * What undoing a plan stands on, in a real Postgres (PGlite): the plans
 * outlive the process, and every store writes a row back as it was.
 */
const OWNER: CalendarUser = { id: 'u1', timeZone: 'America/Sao_Paulo' };
const OTHER: CalendarUser = { id: 'u2', timeZone: 'America/Sao_Paulo' };
const NOW = new Date('2026-03-10T13:00:00Z');

describe('undo in Postgres', () => {
  let client: PGlite;
  let db: Database;

  beforeAll(() => {
    jest.useFakeTimers({ now: NOW, doNotFake: ['nextTick', 'setImmediate'] });
  });

  afterAll(() => {
    jest.useRealTimers();
  });

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
  });

  afterEach(async () => {
    await client.close();
  });

  describe('PgPlanStore', () => {
    const body = {
      gestures: [{ do: 'deliver' as const, id: 'a1' }],
      changes: [],
      pushed: [],
      assumed: [],
    };

    it('keeps a plan, and what applying it did, for its owner only', async () => {
      const plans = new PgPlanStore(db);
      const plan = await plans.put(OWNER.id, body);

      expect(await plans.get(OTHER.id, plan.id)).toBeUndefined();
      expect(await plans.get(OWNER.id, 'not-an-id')).toBeUndefined();
      expect((await plans.get(OWNER.id, plan.id))?.gestures).toEqual(
        body.gestures,
      );

      plan.applied = { undo: [], touched: ['a1'] };
      await plans.save(plan);
      // Read by another process, as after a deploy.
      const again = await new PgPlanStore(db).get(OWNER.id, plan.id);
      expect(again?.applied).toEqual({ undo: [], touched: ['a1'] });

      plan.applied = undefined;
      await plans.save(plan);
      expect((await plans.get(OWNER.id, plan.id))?.applied).toBeUndefined();
    });

    it('knows when another answer to the same question was applied', async () => {
      const plans = new PgPlanStore(db);
      const plan = await plans.put(OWNER.id, body);
      const option = await plans.put(OWNER.id, { ...body, group: plan.id });
      const other = await plans.put(OWNER.id, { ...body, group: plan.id });

      expect(await plans.answered(option)).toBe(false);
      option.applied = { undo: [], touched: [] };
      await plans.save(option);
      expect(await plans.answered(other)).toBe(true);
      expect(await plans.answered(plan)).toBe(true);
      expect(await plans.answered(option)).toBe(false);
    });

    it('forgets a plan once it is two hours old', async () => {
      const plans = new PgPlanStore(db);
      const plan = await plans.put(OWNER.id, body);

      jest.setSystemTime(NOW.getTime() + PLAN_TTL_MS + 1);
      expect(await plans.get(OWNER.id, plan.id)).toBeUndefined();
      jest.setSystemTime(NOW);
    });
  });

  it('writes a task, an event and a delivery back with their own ids', async () => {
    const tasks = new PgTaskStore(db);
    const events = new PgCalendarStore(db);
    const artifacts = new PgArtifactStore(db);

    const shelf = await artifacts.insertCategory(OWNER, {
      name: 'Atendimentos',
      position: 0,
    });
    const type = await artifacts.insertType(OWNER, {
      categoryId: shelf.id,
      name: 'Mapa astral',
      minutes: 90,
      price: 250,
      position: 0,
    });
    const tese = await artifacts.insert(OWNER, {
      title: 'Tese',
      typeId: type.id,
      value: 1500,
      deadline: '2026-04-01',
      position: 0,
    });
    const goal = await artifacts.insertGoal(OWNER, {
      kind: 'count',
      typeId: type.id,
      target: 3,
      starts: '2026-03-09',
      deadline: '2026-03-15',
    });
    const task = await tasks.insert(OWNER, {
      title: 'Revisão',
      minutes: 30,
      position: 1,
      backlog: true,
      artifactId: tese.id,
    });
    const event = await events.insert(OWNER, {
      title: 'Dentista',
      startTime: '2026-03-10T19:00:00.000Z',
      endTime: '2026-03-10T20:00:00.000Z',
      fixed: true,
    });

    await tasks.remove(OWNER, task.id);
    await events.remove(OWNER, event);
    await artifacts.removeGoal(OWNER, goal.id);
    await artifacts.remove(OWNER, tese.id);
    await artifacts.removeCategory(OWNER, shelf.id);
    expect(await artifacts.types(OWNER)).toEqual([]);

    await artifacts.revive(OWNER, { kind: 'category', row: shelf });
    await artifacts.revive(OWNER, { kind: 'type', row: type });
    await artifacts.revive(OWNER, { kind: 'artifact', row: tese });
    await artifacts.revive(OWNER, { kind: 'goal', row: goal });
    await tasks.revive(OWNER, task);
    await events.revive(OWNER, event);

    expect(await artifacts.categories(OWNER)).toEqual([shelf]);
    expect(await artifacts.types(OWNER)).toEqual([type]);
    expect(await artifacts.get(OWNER, tese.id)).toEqual(tese);
    expect(await artifacts.goals(OWNER)).toEqual([goal]);
    expect(await tasks.get(OWNER, task.id)).toEqual(task);
    expect(await events.get(OWNER, event.id)).toEqual(event);

    // A row already there is left as it is.
    await tasks.update(OWNER, { ...task, title: 'Revisão final' });
    await tasks.revive(OWNER, task);
    expect((await tasks.get(OWNER, task.id))?.title).toBe('Revisão final');
  });
});
