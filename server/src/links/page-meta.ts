/**
 * Reading what a page says about itself from its HTML: the Open Graph and
 * Twitter tags most sites write for exactly this, and the `<title>` when
 * they write none.
 */

/** What a page's head says of it. */
export interface PageMeta {
  title: string | null;
  site: string | null;
  image: string | null;
}

const MAX_TEXT = 300;

/** The meta of [html], its picture resolved against [page]. */
export function readPageMeta(html: string, page: URL): PageMeta {
  const meta = new Map<string, string>();
  for (const tag of html.match(/<meta\b[^>]*>/gi) ?? []) {
    const attributes = attributesOf(tag);
    const key = (attributes.property ?? attributes.name)?.toLowerCase();
    const content = attributes.content;
    if (key && content !== undefined && !meta.has(key)) meta.set(key, content);
  }
  const first = (...keys: string[]): string | null => {
    for (const key of keys) {
      const value = text(meta.get(key));
      if (value) return value;
    }
    return null;
  };

  const titleTag = /<title\b[^>]*>([\s\S]*?)<\/title>/i.exec(html)?.[1];
  return {
    title: first('og:title', 'twitter:title') ?? text(titleTag),
    site: first('og:site_name', 'application-name'),
    image: address(
      first(
        'og:image:secure_url',
        'og:image',
        'og:image:url',
        'twitter:image',
        'twitter:image:src',
      ),
      page,
    ),
  };
}

/**
 * The charset a page declares in its own head, for when the server did not
 * name one.
 */
export function declaredCharset(head: string): string | undefined {
  return /<meta\b[^>]*charset\s*=\s*["']?\s*([\w-]+)/i.exec(head)?.[1];
}

function attributesOf(tag: string): Record<string, string> {
  const attributes: Record<string, string> = {};
  const pattern = /([\w:.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/g;
  for (const [, name, double, single, bare] of tag.matchAll(pattern)) {
    attributes[name.toLowerCase()] = double ?? single ?? bare;
  }
  return attributes;
}

/** Decoded, on one line, trimmed and capped; null when nothing is left. */
function text(raw: string | undefined): string | null {
  if (raw === undefined) return null;

  const value = entities(raw).replace(/\s+/g, ' ').trim();
  if (value === '') return null;

  return value.length > MAX_TEXT ? `${value.slice(0, MAX_TEXT - 1)}…` : value;
}

/** [raw] as an http(s) address, resolved against [page]. */
function address(raw: string | null, page: URL): string | null {
  if (raw === null) return null;
  try {
    const url = new URL(raw, page);
    return url.protocol === 'http:' || url.protocol === 'https:'
      ? url.href
      : null;
  } catch {
    return null;
  }
}

const NAMED: Record<string, string> = {
  amp: '&',
  lt: '<',
  gt: '>',
  quot: '"',
  apos: "'",
  nbsp: ' ',
  ndash: '–',
  mdash: '—',
  hellip: '…',
  middot: '·',
  laquo: '«',
  raquo: '»',
};

function entities(raw: string): string {
  return raw.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (whole, name: string) => {
    if (name[0] === '#') {
      const code =
        name[1] === 'x' || name[1] === 'X'
          ? parseInt(name.slice(2), 16)
          : parseInt(name.slice(1), 10);
      return code > 0 && code <= 0x10ffff ? String.fromCodePoint(code) : whole;
    }
    return NAMED[name.toLowerCase()] ?? whole;
  });
}
