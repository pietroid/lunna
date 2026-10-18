# Link cards

A link written on a line of its own in a task's or a project's notes is
drawn as a card: the page's picture, its title and its site, the whole card
one tap from the browser. Delivered in
[product/delivery/2026-10-17-link-cards](../delivery/2026-10-17-link-cards/README.md).

## The contract

**The notes stay text.** A card is the URL on its own line; nothing about
it is saved in the notes but the URL. The server, the agent and every
other reader see a link. Title and picture live in `link_preview`, read
once by the server and kept for everyone.

- Only a line that is just a link is a card. A link inside a sentence stays
  text.
- Pasting a link, or return after one typed by hand, makes the card and puts
  the cursor on the line under it. Typing beside a card moves the text to a
  line of its own: a card never shares its row, and two cards never share
  one.
- A backspace at the start of the line under a card selects it (the caret
  right after it, the card ringed in `accent`) and deletes nothing; a
  second backspace takes the card and its line away. Any other key
  deselects. Undo is the keyboard's.
- A card has the same small gap above and below, whether text follows it
  or not: an empty last line under a card gets a zero-width character in
  the drawn span, so it is a line of text tall rather than the card's.

## In the app

- `LiveTextController` (`app_ui`) holds each card as one
  `LiveTextController.card` character (`￼`) in `text`, drawn as a
  `WidgetSpan` of `AppLinkCard`; `notes` (get/set) is the saved form, with
  the URLs. Pages read and write `.notes`, never `.text`. A notes
  `TextField` must set `strutStyle: StrutStyle.disabled`, or the default
  strut caps every line at the text's height and the cards overlap.
- `AppLinkCard` reads its preview from the `LinkPreviewScope` above it
  (`LinkPreviews`: `cached`, `fetch`, `open`). While it is fetched the
  picture and the title pulse under the host; a link with nothing to say
  draws its URL as the title, for good, and still opens.
- `ApiLinkPreviews` (`app/lib/links/`) is the real one, provided above the
  router in `main.dart`: a session cache over `GET /api/links/preview`, and
  `url_launcher` in `externalApplication` mode. On the web a picture is
  drawn through `GET /api/links/image`, since CanvasKit cannot draw one
  from another origin; phones load it from its own address.

## On the server (`server/src/links/`)

| Route | Answer |
|-------|--------|
| `GET /api/links/preview?url=` | `{ url, title, site, image }`, `url` echoed as sent |
| `GET /api/links/image?url=` | the picture's bytes (JPEG, PNG, GIF, WebP, BMP), `Cache-Control: private, max-age=604800`, sandboxed |

Both are behind `SessionGuard`: the server reads pages only for the people
who use it.

- **Read once, kept for everyone.** `link_preview` has one row per link (no
  user column). A kept row is answered at once. A page that could not be read
  is kept as `failed` (answered with the URL only) and tried again a day
  later. Two cards of one link opened together read the page once.
- **What is read.** `og:title`, `twitter:title`, then `<title>`;
  `og:site_name`; `og:image` (and its variants), then `twitter:image`,
  resolved against the address the redirects ended at. A link straight to a
  picture is its own picture. Pages are read up to 1 MB, pictures up to 5 MB
  (a larger picture is refused, not cut), 5 s per hop, four redirects.
- **Never inward.** `HttpPageFetcher` refuses anything that is not http(s),
  any address written out that is not public, and any host that resolves to
  one (loopback, private, CGNAT, link-local and the cloud metadata, ULA,
  multicast, IPv4-mapped), checked in the socket's own `lookup` so the
  address checked is the one connected to, on every redirect. SVG is never
  proxied (it can carry script and the proxy answers from the app's origin).
- **Refusals** are 400 in Portuguese: no link, too long (2048), not a web
  address, not http(s), with a user and password. An unreadable picture is
  a 404.

The specs replace the web with a fake (`links.controller.spec.ts`); the
guard is tested on addresses that resolve without a network
(`page-fetcher.spec.ts`).
