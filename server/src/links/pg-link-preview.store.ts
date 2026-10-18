import { Inject, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { linkPreview } from '../db/schema';
import { LinkPreviewStore } from './link-preview.store';
import { KeptPreview } from './link.types';

/** The previews, in Postgres. */
@Injectable()
export class PgLinkPreviewStore extends LinkPreviewStore {
  constructor(@Inject(DB) private readonly _db: Database) {
    super();
  }

  async get(url: string): Promise<KeptPreview | undefined> {
    const [row] = await this._db
      .select()
      .from(linkPreview)
      .where(eq(linkPreview.url, url));

    return row;
  }

  async put(preview: KeptPreview): Promise<void> {
    const { title, site, image, failed, fetchedAt } = preview;
    await this._db.insert(linkPreview).values(preview).onConflictDoUpdate({
      target: linkPreview.url,
      set: { title, site, image, failed, fetchedAt },
    });
  }
}
