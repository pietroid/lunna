import * as path from 'path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import { CalendarUser } from '../calendar/calendar.types';
import type { Database } from '../db/db';
import { schema, user } from '../db/schema';
import { PgConversationStore } from './pg-conversation.store';

/**
 * The Postgres conversation store, against a real Postgres (PGlite), as in
 * `pg-task.store.spec.ts`.
 */
const OWNER: CalendarUser = { id: 'u1', timeZone: 'America/Sao_Paulo' };
const OTHER: CalendarUser = { id: 'u2', timeZone: 'America/Sao_Paulo' };
const FIRST = '11111111-1111-4111-8111-111111111111';
const SECOND = '22222222-2222-4222-8222-222222222222';
const THEIRS = '33333333-3333-4333-8333-333333333333';
const AT = Date.parse('2026-03-10T13:00:00Z');
const at = (minutes: number) => new Date(AT + minutes * 60_000);

describe('PgConversationStore', () => {
  let client: PGlite;
  let store: PgConversationStore;

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
    store = new PgConversationStore(pglite as unknown as Database);

    await store.append(OWNER, FIRST, [
      { role: 'user', text: 'Passa a academia pras 18:30', at: at(0) },
      {
        role: 'assistant',
        text: 'Fica assim.',
        steps: ['Olhei hoje'],
        plan: {
          id: '44444444-4444-4444-8444-444444444444',
          changes: [],
          pushed: [],
        },
        at: at(1),
      },
    ]);
    await store.append(OWNER, SECOND, [
      { role: 'user', text: 'Oi', voiceSeconds: 3, at: at(60) },
      { role: 'assistant', text: 'Oi!', at: at(61) },
    ]);
    await store.append(OTHER, THEIRS, [
      { role: 'user', text: 'Academia amanhã', at: at(5) },
    ]);
  });

  afterEach(async () => {
    await client.close();
  });

  it('reads conversations back, most recent first, only the owner’s', async () => {
    const all = await store.recent(OWNER, undefined, 10);

    expect(all.map((it) => it.id)).toEqual([SECOND, FIRST]);
    expect(all[0].startedAt).toBe(at(60).toISOString());
    expect(all[0].messages[0].voiceSeconds).toBe(3);
    expect(all[1].messages.map((it) => it.text)).toEqual([
      'Passa a academia pras 18:30',
      'Fica assim.',
    ]);
    expect(all[1].messages[1].steps).toEqual(['Olhei hoje']);
    expect(all[1].messages[1].planStatus).toBe('proposed');
  });

  it('pages back from an instant', async () => {
    const page = await store.recent(OWNER, at(30), 10);
    expect(page.map((it) => it.id)).toEqual([FIRST]);

    expect(
      (await store.recent(OWNER, undefined, 1)).map((it) => it.id),
    ).toEqual([SECOND]);
  });

  it('records what became of a plan', async () => {
    await store.markPlan(
      OWNER,
      '44444444-4444-4444-8444-444444444444',
      'applied',
    );

    const [, first] = await store.recent(OWNER, undefined, 10);
    expect(first.messages[1].planStatus).toBe('applied');
  });

  it('searches by words in any case and by day, leaving one out', async () => {
    const found = await store.search(OWNER, { text: 'ACADEMIA', limit: 10 });
    expect(found.map((it) => it.text)).toEqual(['Passa a academia pras 18:30']);

    const none = await store.search(OWNER, {
      text: 'academia',
      exclude: FIRST,
      limit: 10,
    });
    expect(none).toEqual([]);

    const later = await store.search(OWNER, { from: at(30), limit: 10 });
    expect(later.map((it) => it.text)).toEqual(['Oi!', 'Oi']);

    const literal = await store.search(OWNER, { text: '100%', limit: 10 });
    expect(literal).toEqual([]);
  });
});
