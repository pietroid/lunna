import { KeptPreview } from './link.types';

/**
 * Where the previews are kept, one per link, for everyone: the same link
 * says the same thing to whoever pasted it.
 */
export abstract class LinkPreviewStore {
  abstract get(url: string): Promise<KeptPreview | undefined>;

  /** Keeps [preview], over whatever was kept for its link. */
  abstract put(preview: KeptPreview): Promise<void>;
}

/** The previews in memory, for the specs. */
export class MemoryLinkPreviewStore extends LinkPreviewStore {
  private readonly _previews = new Map<string, KeptPreview>();

  get(url: string): Promise<KeptPreview | undefined> {
    const kept = this._previews.get(url);
    return Promise.resolve(kept === undefined ? undefined : { ...kept });
  }

  put(preview: KeptPreview): Promise<void> {
    this._previews.set(preview.url, { ...preview });
    return Promise.resolve();
  }
}
