# Multica on the Mac, as a window on the queue

2026-10-21 · RFC · proposed (issue #18) · deep-research pass not run

## In one minute

**Run Multica on the Mac as a second screen for the queue, not a second
queue. `.tool/queue` stays the only thing that starts a run or opens a
gate. Multica shows each issue, its gate and how the run is going, and
hands your answers back to the queue.**

- **Do:** run Multica's Docker stack on the Mac, pinned to v0.6.5, and
  reach it from the phone over Tailscale (private to your devices, no
  public port).
- **Do:** let the queue **mirror** its state into Multica on every tick
  (status, the gate's comment, a progress comment while a run goes), keyed
  by the GitHub issue number.
- **Do:** read your Multica comments as answers, the same as GitHub
  comments, and copy each one onto the GitHub issue so the record stays
  whole.
- **Not needed:** Multica's daemon (it would run `claude` a second way,
  with permission checks skipped), its GitHub App, or a public URL.
- **You decide:** Multica as a screen (**recommended**) or as the runner.
  Also where the server runs (**the Mac**, as asked), how the phone gets
  in (**Tailscale**) and which app (**the web app first**).

## Ideas to keep

1. **"One queue, one writer: everything else is a screen."**
   Thompson, [Single Writer Principle](https://mechanical-sympathy.blogspot.com/2011/09/single-writer-principle.html):
   each piece of data should be "owned by a single execution context for
   all mutations". *For us:* two dispatchers polling one inbox would both
   start #18, run `/research` twice and use the week twice. `queue.mjs`
   owns every change of state. Multica only draws it and passes your words
   back. *New*
2. **"Mirror by level, not by edge."**
   Kubernetes, [Controllers](https://kubernetes.io/docs/concepts/architecture/controller/):
   a control loop "tries to move the current state closer to the desired
   state", over and over. *The failure case:* a Multica user imported
   GitHub issues with a one-off `gh issue list | multica issue create`
   loop, and the boards drifted, because "a merged PR or closed issue on
   GitHub doesn't update the Multica item"
   ([#1120](https://github.com/multica-ai/multica/issues/1120)). *For us:*
   each tick works out the whole desired status from `.git/queue/` and sets
   any that differ ([`code/mirror.mjs`](./code/mirror.mjs)). A missed
   update fixes itself within a minute. *New*
3. **"A gate in code can't be skipped; a gate in a prompt can."**
   One level deeper than [workflow before agent](../concepts.md#workflow-before-agent).
   As the runner, Multica keeps the gates in the agent's instructions: "A
   run finishing does not move the issue by itself: the person or agent
   handling the step updates its status"
   ([Workflows](https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/workflows.mdx)).
   *For us:* "approve" today is a regex in `queue.mjs:44` that the model
   never sees. As the runner, Multica would leave the decision to stop and
   wait to the model.
4. **"Skipping permissions is for a container, not your home folder."**
   Claude Code, [Permission modes](https://code.claude.com/docs/en/permission-modes):
   `bypassPermissions` is meant for "isolated containers and VMs only",
   and "allow rules have no effect" in it. Multica's daemon starts
   `claude` with exactly that, as your macOS user, with no sandbox
   ([Security model](https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/security-model.mdx)).
   *For us:* the queue runs in `auto` mode, where a second model checks
   each action before it runs. As a screen, Multica never runs `claude` at
   all. *New*
5. **"Reach it privately before you open a port."**
   Tailscale, [Serve](https://tailscale.com/kb/1312/serve): it shares a
   local service with your tailnet (your own devices, signed in to
   Tailscale) only; making it public is a separate tool, Funnel.
   Multica's compose file binds to `127.0.0.1` and warns: "Do NOT change
   these bindings to 0.0.0.0". *For us:* the phone joins the tailnet and
   nothing on the Mac is reachable from outside it. *New*

## The change

| # | Change | Fixes | Size |
|---|--------|-------|------|
| 1 | Multica on the Mac, reached over Tailscale | 1, 2 | evening, no code |
| 2 | The mirror: status and gate comment, every tick | 3, 4 | S, ~80 lines in `queue.mjs` |
| 3 | A progress comment while a run goes | 5 | S, ~30 lines |
| 4 | Answers from Multica, copied onto GitHub | 3, 6 | S, ~40 lines |

### 1. The stack on the Mac

Multica's `docker-compose.selfhost.yml` (Postgres 17, the Go API on
`:8080`, the Next.js web app on `:3000`, both bound to `127.0.0.1`) runs
under OrbStack or Docker Desktop. Neither is installed now (`which docker`
finds nothing). The images are built for arm64.

- `.env`: `MULTICA_IMAGE_TAG=v0.6.5` (releases land "most weekdays", so
  pin the tag and upgrade on purpose), `JWT_SECRET=$(openssl rand -hex 32)`,
  `ALLOWED_EMAILS=<yours>`, `ALLOW_SIGNUP=false` after the first login,
  `DO_NOT_TRACK=1`. Leave `GITHUB_APP_*` unset.
- Sign-in is a code sent by email. With no SMTP set, the backend prints
  the code to its log (`docker compose logs backend`), which is enough for
  one person.
- `tailscale serve` for `:3000` gives an `https://<mac>.<tailnet>.ts.net`
  address that only your devices can open. Install Tailscale on the Mac and
  the phone.
- The CLI (`brew install multica-ai/tap/multica`, `multica login`) is what
  the queue writes through. **Don't run `multica daemon start`.**

When the Mac sleeps, the board can't be reached either. The queue already
needs the Mac awake, so nothing new is lost.

### 2. The mirror

One function in `queue.mjs`, `mirror(cfg, st)`, called for every state at
the end of each `tick` and wrapped like `push` (a failure is logged and
never stops the queue):

- **Key.** The first time it sees an issue, it runs `multica issue create`
  with `--title "#18 <title>" --project Queue` and the issue's body plus
  links (issue, PR, review page). Then
  `multica issue metadata set <id> github_issue 18` tags it with the
  GitHub number, and the id is kept in `st.multica`.
- **Status, by level.** `desired(st)` maps the queue's state onto
  Multica's built-in statuses, and the mirror calls `multica issue status`
  only when Multica shows something else. The dry run on today's nine
  issues is in [`data/mirror-dry-run.md`](./data/mirror-dry-run.md):

  | Queue | Multica |
  |---|---|
  | queued, nothing run yet | `todo` |
  | working, or answered and next | `in_progress` |
  | waiting at a gate | `in_review` |
  | failed, or paused on the usage limit | `blocked` |
  | merged | `done` |

- **The gate.** `work()` already writes the gate's comment (summary, open
  questions, the review-page link, the usage line). The mirror posts the
  same text on the Multica issue, so the phone shows what to answer
  without opening GitHub.

Nobody is assigned in Multica, so no comment there can start an agent: an
issue with no agent assignee triggers nothing ([Comments](https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/comments.mdx)).

### 3. Progress while a run goes

`claude()` already reads the stream and keeps `lastText`. Every two
minutes during a run it updates one comment on the Multica issue: the
phase, minutes so far, turns, and the first line of the model's latest
message (as `.tool/queue log` prints it). GitHub doesn't show this today,
and it is the "see things on my phone" part of the issue.

### 4. Answers from Multica

`answers()` also reads `multica issue comment list <id> --since <gateAt>
--output json` and keeps your comments that don't carry the queue's mark.
They go through the same `isApproval` and `feedback`, so "approve" on the
phone in Multica is the same as "approve" on GitHub. Each one is then
posted on the GitHub issue as a quote ("From Multica: …", with the mark),
so the issue and the PR still hold the whole conversation. Line comments
stay on GitHub. Multica has no lines of the README to comment on.

## Decisions for you

1. **Multica's role.**
   - (a) **A screen; the queue dispatches** *(recommended)*. Cost: about
     150 lines, and Multica's board shows only what the queue writes to it.
   - (b) **The runner.** Its daemon runs `claude` per issue, and its
     workflow columns are the gates. Cost: the gates move into a prompt
     (idea 3) and runs skip permission checks (idea 4). You lose the
     `--json-schema` contract (summary, doc, replies to line comments), the
     `/usage` figures per run, and the fresh session per phase: Multica
     resumes the issue's previous session instead (*deeper than*
     [resume from files](../concepts.md#resume-from-files-not-from-context)).
     It also has to be set to one run at a time (the default is 6 per
     agent, 20 per daemon).
   - Not an option: both dispatching (idea 1).
2. **Where the server runs.**
   - (a) **The Mac**, as asked *(recommended for the trial)*: next to the
     queue, and down when the queue is down. Cost: Postgres and two
     containers on a 16 GB fanless Air (idle memory not measured: phase 0).
   - (b) The Raspberry Pi: always on, and the images are built for arm64.
     Cost: it shares the box with production, and the queue reaches it
     over the tailnet.
3. **How the phone gets in.**
   - (a) **Tailscale Serve** *(recommended)*: only your devices, HTTPS
     included, nothing public.
   - (b) A Cloudflare Tunnel hostname, beside the Pi's, behind Cloudflare
     Access. Cost: a public name in front of a pre-1.0 server.
4. **Which phone app.**
   - (a) **The web app, added to the home screen** *(recommended first)*.
   - (b) The iOS app, built from source with Xcode. With a free Apple ID
     it stops working after 7 days. The Lunna project carries a team id
     (`K3U55XXNRM`); if that is a paid account, signing lasts longer
     (not checked). There is no Android app.
5. **Approving from Multica.**
   - (a) **"approve" as a comment**, parsed as on GitHub *(recommended)*.
   - (b) Also count a drag to `done` as approval. Cost: a drag is easy to
     make by accident, and merging deploys.
6. **The other RFC.** [agent-console](https://github.com/pietroid/lunna/blob/queue/14-open-source-alternatives-to-manage-agent/product/research/2026-10-21-agent-console/README.md)
   (#14, not merged) proposes a status issue and a Queue view on the
   review page, and says Multica "not now".
   - (a) **If this RFC goes ahead, drop that RFC's phase 3** (status issue
     and Queue view): the Multica board is that screen. Keep its phases
     1–2 (faster listener, Approve button) *(recommended)*.
   - (b) Build both screens.

## Decided unattended

- **Read, not installed.** Multica, OrbStack and Tailscale were judged
  from their docs and the Multica repo on 2026-10-21 (v0.6.5). Nothing was
  installed on the Mac.
- **"The same queue GitHub manages"** was taken to mean one queue that
  shows up in both places, not a move off GitHub, because #14's RFC had
  already weighed the move and advised against it for now.
- **The mirror was tried dry**, on the real state files
  ([`code/mirror.mjs`](./code/mirror.mjs)). No Multica commands were sent.

## Deeper

### How it works today

```
GitHub issue ──tick (60 s)──▶ queue.mjs ──▶ claude -p (worktree, auto mode)
   ▲  labels, gate comment, PR body          │ stream-json → .git/queue/logs
   └──────────── your comment / line comment ┘
phone: GitHub app + ntfy push (+ review page on Pages)
```

- State: one JSON per issue in `.git/queue/issues/` (`queue.mjs:66-68`).
  Labels on GitHub (`setStatus`, `queue.mjs:235`).
- The phone sees: labels, the gate's comment, the PR, and a push at each
  gate (`push`, `queue.mjs:72`). It sees nothing *during* a run. The
  stream goes only to `.git/queue/logs/` (34 MB, 28 runs).

### Diagnosis

| # | Symptom | Root cause | Where |
|---|---------|------------|-------|
| 1 | No board: which issue is where takes `.tool/queue ls` on the Mac | The state lives in local JSON; GitHub shows only one label per issue | `queue.mjs:66`, `:235` |
| 2 | Nothing on the Mac is reachable from the phone | The doc page binds to localhost; Multica's compose does too, on purpose | `annotate.mjs`, compose file |
| 3 | A second queue would run issues twice | `tick` starts any `next` it finds; a second dispatcher would too | `queue.mjs:560-565` |
| 4 | A one-off import drifts | Sync by event (or once), not by state | multica #1120 |
| 5 | A run is a black box until its gate | `lastText` is read from the stream but only kept for errors | `queue.mjs:211`, `:228` |
| 6 | Answers in two places split the record | `answers()` reads only GitHub | `queue.mjs:252` |

### Multica, as read for this RFC

| | What it does | Ref |
|---|---|---|
| Server | Go API, Next.js, Postgres 17; Docker Compose; binds 127.0.0.1 | 2, 3 |
| GitHub | Links PRs by issue id, read-only; needs a GitHub App and a webhook GitHub can reach | 4 |
| Issue import | None documented | 5 |
| Daemon | `claude` with `bypassPermissions`, as your user; resumes sessions | 6, 9 |
| Phone | iOS from source, no Android; the web app | 10 |
| License | Internal use needs no commercial license | 13 |

### Rollout

| Phase | Ships | Fixes | Size |
|-------|-------|-------|------|
| 0 | Install and measure: stack up, idle memory (`docker stats`), the web app on the phone over Tailscale, whether a comment keeps an HTML mark (`<!-- lunna-queue -->`), `issue list --metadata github_issue=18` | n/a | evening |
| 1 | Mirror out: create, key, status by level, gate comment | 1, 3, 4 | S |
| 2 | Progress comment during runs | 5 | S |
| 3 | Answers in, copied onto GitHub | 6 | S |
| 4 | After two weeks, count where answers came from; if Multica's share is small, remove the mirror (`st.multica` and one call) | n/a | XS |

Unverified until phase 0: that the web app works on a phone screen, that
Tailscale Serve on `:3000` alone is enough (the web app proxies the API,
but its websocket may need `:8080` too), and that Multica keeps HTML
comments in markdown. If it doesn't, the mark becomes a short visible
footer.

## References

1. multica-ai/multica, README. https://github.com/multica-ai/multica: Go, Next.js, Postgres; daemon spawns agent CLIs; iOS built from source; "We release most weekdays".
2. Multica, `docker-compose.selfhost.yml`. https://github.com/multica-ai/multica/blob/main/docker-compose.selfhost.yml: ports bound to 127.0.0.1, "Do NOT change these bindings to 0.0.0.0"; `ALLOWED_EMAILS`, `DO_NOT_TRACK`, `MULTICA_IMAGE_TAG`.
3. Multica, SELF_HOSTING.md. https://github.com/multica-ai/multica/blob/main/SELF_HOSTING.md: `JWT_SECRET` required; login code in the backend log without email.
4. Multica docs, *GitHub integration*. https://multica.ai/docs/github-integration: PR linking only; read-only; a GitHub App and a webhook URL for self-hosting.
5. multica-ai/multica #1120. https://github.com/multica-ai/multica/issues/1120: GitHub issue sync requested; a one-off import drifts; closed 2026-06-12 with no linked PR.
6. Multica docs, *Security model*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/security-model.mdx: Claude Code runs with `bypassPermissions`; no filesystem sandbox; use a dedicated user, container or VM.
7. Multica docs, *Workflows*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/workflows.mdx: hand to agent or member; "A run finishing does not move the issue by itself".
8. Multica docs, *Daemon and runtimes*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/daemon-runtimes.mdx: 20 runs per daemon, 6 per agent by default; `--permission-mode` can't be overridden.
9. Multica docs, *AI coding tools comparison*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/providers.mdx: session resumption per issue; skills from `.claude/skills/`.
10. Multica docs, *Mobile app (iOS)*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/mobile-app.mdx: not on the App Store; 7-day free signing; no Android.
11. Multica docs, *Comments* and *@-mention agents*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/mentioning-agents.mdx: plain comments only reach an agent assignee.
12. Multica docs, *CLI*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/cli.mdx: `issue create`, `status`, `metadata set`, `comment list --since`.
13. Multica LICENSE. https://github.com/multica-ai/multica/blob/main/LICENSE: internal use within one organization needs no commercial license.
14. Claude Code, *Permission modes*. https://code.claude.com/docs/en/permission-modes: `bypassPermissions` for "isolated containers and VMs only"; auto mode's classifier.
15. Kubernetes, *Controllers*. https://kubernetes.io/docs/concepts/architecture/controller/: control loops move current state toward desired state.
16. M. Thompson, *Single Writer Principle*. https://mechanical-sympathy.blogspot.com/2011/09/single-writer-principle.html: one execution context owns all mutations.
17. Tailscale, *Serve*. https://tailscale.com/kb/1312/serve: tailnet-only sharing with HTTPS; Funnel is the public one.
18. agent-console RFC (#14, branch). https://github.com/pietroid/lunna/blob/queue/14-open-source-alternatives-to-manage-agent/product/research/2026-10-21-agent-console/README.md: Multica weighed as a replacement; "not now".
