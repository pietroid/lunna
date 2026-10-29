import * as path from 'path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import type { Database } from '../db/db';
import { schema, user } from '../db/schema';
import { PgSuggestionStore } from './pg-suggestion.store';
import { NewSuggestion } from './suggestion.store';

/** The suggestion each person holds, in a real Postgres (PGlite). */
const NOW = new Date('2026-03-10T13:00:00Z');
const PLAN = '0b8f2c1e-8a3f-4c1d-9a51-3f3c9e2d1a10';

const made = (text: string): NewSuggestion => ({
  focus: 'delivery',
  text,
  action: { label: 'Encaixar às 14:00', planId: PLAN },
  opening: { ui: [], reply: text, steps: [], options: [] },
  basis: 'abc',
  validUntil: new Date('2026-03-10T17:00:00Z'),
});

describe('suggestions in Postgres', () => {
  let client: PGlite;
  let store: PgSuggestionStore;

  beforeEach(async () => {
    client = new PGlite();
    const pglite = drizzle(client, { schema });
    await migrate(pglite, {
      migrationsFolder: path.join(__dirname, '..', '..', 'drizzle'),
    });
    await pglite.insert(user).values([
      { id: 'u1', name: 'Owner', email: 'owner@example.com' },
      { id: 'u2', name: 'Other', email: 'other@example.com' },
    ]);
    store = new PgSuggestionStore(pglite as unknown as Database);
  });

  afterEach(async () => {
    await client.close();
  });

  it('keeps one per person, a new one replacing it', async () => {
    const first = await store.put('u1', made('Primeira'), NOW);
    expect(await store.current('u1')).toEqual({
      id: first.id,
      userId: 'u1',
      ...made('Primeira'),
      createdAt: NOW,
    });

    const second = await store.put('u1', made('Segunda'), NOW);
    expect(second.id).not.toBe(first.id);
    expect((await store.current('u1'))?.text).toBe('Segunda');
    expect(await store.current('u2')).toBeUndefined();
  });

  it('is taken by its plan, and only its own person’s', async () => {
    await store.put('u1', made('Encaixo?'), NOW);
    await store.takeByPlan('u2', PLAN, NOW);
    expect((await store.current('u1'))?.takenAt).toBeUndefined();

    await store.takeByPlan('u1', PLAN, NOW);
    expect((await store.current('u1'))?.takenAt).toEqual(NOW);
  });
});
