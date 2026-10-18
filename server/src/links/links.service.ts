import { Injectable, NotFoundException } from '@nestjs/common';
import { LinkPreviewStore } from './link-preview.store';
import { KeptPreview, LinkPreview } from './link.types';
import { Fetched, PageFetcher } from './page-fetcher';
import { declaredCharset, readPageMeta } from './page-meta';
import { Link } from './request';

/** A page is read up to here: its head is all a preview needs. */
const PAGE_BYTES = 1024 * 1024;
/** A picture larger than this is not drawn on a 64 px card. */
const IMAGE_BYTES = 5 * 1024 * 1024;
/** A page that could not be read is tried again after a day. */
const RETRY_FAILED_MS = 24 * 60 * 60 * 1000;

const PAGE_TYPES = new Set(['text/html', 'application/xhtml+xml']);
/** The pictures a card draws. SVG is not one: it can carry script, and the
 * proxy answers from the app's own origin. */
const IMAGE_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/bmp',
]);

/** A picture, as the proxy answers it. */
export interface ProxiedImage {
  type: string;
  body: Buffer;
}

/**
 * What links say about themselves.
 *
 * A link's page is read once, for everyone, and kept: a card read again
 * never waits on someone else's site. A page that could not be read is kept
 * as such, so it is not fetched on every open, and tried again a day later.
 */
@Injectable()
export class LinksService {
  private readonly _reading = new Map<string, Promise<KeptPreview>>();

  constructor(
    private readonly _store: LinkPreviewStore,
    private readonly _fetcher: PageFetcher,
  ) {}

  async preview({ link, url }: Link): Promise<LinkPreview> {
    const kept = await this._store.get(link);
    if (kept && !(kept.failed && isStale(kept))) return viewOf(kept);

    // Two cards of one link opened together read its page once.
    let reading = this._reading.get(link);
    if (!reading) {
      reading = this._read(url, link).finally(() => this._reading.delete(link));
      this._reading.set(link, reading);
    }
    return viewOf(await reading);
  }

  /** The picture at [url], when it is one a card can draw. */
  async image(url: URL): Promise<ProxiedImage> {
    let fetched: Fetched;
    try {
      fetched = await this._fetcher.fetch(url, {
        maxBytes: IMAGE_BYTES,
        truncate: false,
        accept: 'image/*',
      });
    } catch {
      throw new NotFoundException('Não deu para abrir essa imagem.');
    }
    if (!IMAGE_TYPES.has(fetched.type)) {
      throw new NotFoundException('Esse link não é uma imagem.');
    }

    return { type: fetched.type, body: fetched.body };
  }

  private async _read(url: URL, link: string): Promise<KeptPreview> {
    const preview: KeptPreview = {
      url: link,
      title: null,
      site: null,
      image: null,
      failed: false,
      fetchedAt: new Date(),
    };
    try {
      const page = await this._fetcher.fetch(url, {
        maxBytes: PAGE_BYTES,
        truncate: true,
        accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.5',
      });
      if (PAGE_TYPES.has(page.type)) {
        Object.assign(preview, readPageMeta(textOf(page), page.url));
      } else if (IMAGE_TYPES.has(page.type)) {
        // A link straight to a picture is its own picture.
        preview.image = page.url.href;
      }
    } catch {
      preview.failed = true;
    }

    await this._store.put(preview);
    return preview;
  }
}

function isStale(kept: KeptPreview): boolean {
  return Date.now() - kept.fetchedAt.getTime() >= RETRY_FAILED_MS;
}

function viewOf({ url, title, site, image }: KeptPreview): LinkPreview {
  return { url, title, site, image };
}

/** The page's text, in the charset its server or its head names. */
function textOf(page: Fetched): string {
  const charset =
    page.charset ??
    declaredCharset(page.body.subarray(0, 2048).toString('latin1'));
  try {
    return new TextDecoder(charset ?? 'utf-8').decode(page.body);
  } catch {
    return new TextDecoder('utf-8').decode(page.body);
  }
}
