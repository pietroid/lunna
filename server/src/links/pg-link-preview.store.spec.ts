import * as path from 'path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import type { Database } from '../db/db';
import { schema } from '../db/schema';
import { PgLinkPreviewStore } from './pg-link-preview.store';

/** The Postgres preview store, against a real Postgres (PGlite). */
describe('PgLinkPreviewStore', () => {
  let client: PGlite;
  let store: PgLinkPreviewStore;

  beforeEach(async () => {
    client = new PGlite();
    const pglite = drizzle(client, { schema });
    await migrate(pglite, {
      migrationsFolder: path.join(__dirname, '..', '..', 'drizzle'),
    });
    store = new PgLinkPreviewStore(pglite as unknown as Database);
  });

  afterEach(async () => {
    await client.close();
  });

  it('keeps one preview per link, the last one read', async () => {
    const url = 'https://example.com/';
    expect(await store.get(url)).toBeUndefined();

    await store.put({
      url,
      title: null,
      site: null,
      image: null,
      failed: true,
      fetchedAt: new Date('2026-03-10T13:00:00Z'),
    });
    await store.put({
      url,
      title: 'Um',
      site: 'Example',
      image: 'https://example.com/a.jpg',
      failed: false,
      fetchedAt: new Date('2026-03-11T13:00:00Z'),
    });

    expect(await store.get(url)).toEqual({
      url,
      title: 'Um',
      site: 'Example',
      image: 'https://example.com/a.jpg',
      failed: false,
      fetchedAt: new Date('2026-03-11T13:00:00Z'),
    });
  });
});
