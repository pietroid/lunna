/** What a link says about itself, as the app draws it on a card. */
export interface LinkPreview {
  /** The link, exactly as the app asked for it. */
  url: string;
  /** The page's title, or null when it has none or could not be read. */
  title: string | null;
  /** The site's own name, or null for the app to show the host. */
  site: string | null;
  /** The page's picture, at its own address, or null. */
  image: string | null;
}

/** A preview as it is kept: what was read, and when. */
export interface KeptPreview extends LinkPreview {
  /** The page could not be read. */
  failed: boolean;
  fetchedAt: Date;
}
