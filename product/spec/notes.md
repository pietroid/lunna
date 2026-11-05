# Notes

Every task and every block has free-text `notes`. The event page edits them
in place and saves them through `PATCH /api/tasks/:id` or
`PATCH /api/events/:id` a moment after typing stops, on blur, and when the
page closes.

A task's notes and a delivery's have the agent's bar at their foot, and
beside it a microphone that **dictates**: plain speech to text, straight
into the notes, each recording a paragraph of its own (at the cursor while
typing), saved like typing.
The bar's own microphone still asks the agent, which then knows the page
it was opened on (`about`). See "Dictation" in
[product/spec/agent.md](./agent.md).

A link on a line of its own in the notes is drawn as a **link card**
(picture, title, site; a tap opens the browser). **The notes stay text**:
the card is the URL on its own line, and pages read and write
`LiveTextController.notes`, never `.text`. The server reads each link's
page once, for everyone (`link_preview`), never from an address that is
not public, and proxies the pictures for the web. See
[product/spec/links.md](./links.md).
