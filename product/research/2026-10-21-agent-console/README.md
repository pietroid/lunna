# A console for the agent queue, with no server to keep

2026-10-21 · RFC · proposed (issue #14; round 2: Hermes and OpenClaw; deep-research pass not run)

## In one minute

**Keep Claude Code as the engine and GitHub as the record. Fix the cracks
inside the queue and the page you already have, and adopt nothing
third-party: every tool on offer replaces a part that already works.**

- **Do:** keep reading comments while a job runs, every 10 s, with
  requests that cost nothing when nothing changed. Today a comment waits
  69 s at the median and 5.5 min at p75, and up to 54 min when another
  issue is running.
- **Do:** add an **Approve** button to the review page and to the phone
  push. GitHub's own Approve can't be used here: the PRs are opened as you,
  and an author can't approve their own PR.
- **Do:** turn the review page into the **console**: what is running, what
  waits for you, the week's usage. It reads a status issue that the queue
  keeps up to date.
- **Not needed:** a backend, or Vibe Kanban, Happy, Hermes, OpenClaw or
  GitHub Actions runners (see [the table](./data/options.md)). Hermes and
  OpenClaw would put a second agent, on a second bill, in front of
  `claude -p`, which is what the queue already runs.
- **You decide:** a budget ceiling (**stop new runs at 85% of the week**,
  recommended), and whether to also use Remote Control for ad-hoc sessions
  (**yes, by hand**, recommended).

## Ideas to keep

1. **"Acknowledge in seconds, even when the work takes an hour."**
   Nielsen, [Response times: the 3 important limits](https://www.nngroup.com/articles/response-times-3-important-limits/):
   10 s "is about the limit for keeping the user's attention". Past that,
   people need to be told when it will be done. *For us:* the 👀 reaction
   and the status issue are that message. Today neither comes until the
   current run ends ([`data/latency.md`](./data/latency.md)). *New*
2. **"A 304 is free: poll often, but poll conditionally."**
   GitHub, [REST API best practices](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api):
   webhooks come first, and a conditional request answered `304` "does not
   count against your primary rate limit". *For us:* three repo-wide calls
   every 10 s replace a per-issue sweep every 60 s. Webhooks would need an
   open port or a relay, so they wait until the polling proves too slow.
   *New*
3. **"Own the gates, rent the screens."** Write the part that is only
   yours (the gates, the budget, the rules for when a run starts). Leave
   the screens to someone who maintains them: the GitHub app, Pages, the
   Claude app. *The failure case:* Vibe Kanban, the best-known
   open-source board for coding agents, now opens with "Vibe Kanban is
   sunsetting" ([README](https://raw.githubusercontent.com/BloopAI/vibe-kanban/HEAD/README.md)).
   *For us:* the queue is ~680 lines we understand. The console is a
   static page over GitHub's API, so it has no server to patch. *New*
5. **"The harness that holds the login holds the bill."**
   Claude Code, [Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance):
   subscription sign-in is "designed to support ordinary use of Claude Code
   and other native Anthropic applications"; other products "should use API
   key authentication". *For us:* any manager that is not `claude` itself
   either shells out to `claude -p` (as the queue does) or pays per token.
   Hermes's own brain would be the second case. *New*
4. **"Approval belongs on the action"**, a level deeper. See
   [the concept](../concepts.md#approval-on-the-action). GitHub's docs say
   "Pull request authors cannot approve their own pull requests"
   ([docs](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/approving-a-pull-request-with-required-reviews)),
   so for us the approval is a word that a regex looks for in a comment
   (`queue.mjs:44`). A button that posts that exact word turns approving
   from typing into a single action.
   *Deeper than* [Approval on the action](../concepts.md#approval-on-the-action)

## The change

| # | Change | Fixes | Size |
|---|--------|-------|------|
| 1 | Listen while working: a 10 s conditional poll, apart from the run | 1 | S (~60 lines in `queue.mjs`) |
| 2 | Approve button: on the review page and in the push | 2, 3 | S |
| 3 | The console: a status issue kept by the queue, drawn by the review page | 4, 5, 6 | M |

### 1. Listen while working

**What.** Split `loop()` into two parts:

- a **listener** that runs every 10 s, even while a job runs;
- a **worker** that runs one job at a time, as today, started without
  `await` from the loop.

The listener makes three conditional calls (`If-None-Match` with the last
`etag`, through `fetch` with `gh auth token`):

- `repos/:r/issues?state=open&since=T` for new issues and label changes;
- `repos/:r/issues/comments?since=T` for every issue and PR conversation
  comment in one call;
- `repos/:r/pulls/comments?since=T` for the line comments.

Each new comment by the owner gets 👀 at once and sets `st.next`, as
`tick()` does now. `answers()` stays as it is, since it is what builds the
reply for the run. PR reviews that carry only a body have no repo-wide
endpoint, so they are still read per PR, once a minute.

**Why.** The loop sleeps 60 s (`queue.mjs:583`), then awaits the whole
run (`queue.mjs:560`). A comment on #10 left during #12's run waited
328 s, and a second note on #12 waited 54 min. The run still waits its
turn (one at a time keeps the usage figures honest), but the
acknowledgement and the status don't wait for it.

**How to check.** Rerun `node code/latency.mjs` after a week. The
target is a 👀 within 15 s, and a run start within 15 s whenever nothing
else is running.

### 2. Approve as a button

**What.**

- **Review page.** When the PR's issue carries `agent:waiting`, the page
  shows an **Approve** button beside Send. It posts `approve` as a PR
  conversation comment. It uses the same token and the same endpoint
  Send's fallback already uses (`review.html:391`, `issues/:pr/comments`),
  and that is a path the queue already reads (`queue.mjs:250`).
- **Push.** The ntfy push gets a second button, `view` → `review.html?pr=N#approve`.
  It opens the page on a confirm sheet, so the tap and the confirm are
  the whole approval.

**Why not an ntfy `http` button that posts the comment itself?** The
button would have to carry the GitHub token in the message. On ntfy.sh
"the topic is essentially a password" ([ntfy](https://docs.ntfy.sh/publish/)),
so anyone who knows the topic could read the token.

**Why not GitHub's Approve?** The PR author can't approve their own PR,
and the queue opens PRs as you.

### 3. The console

**What.** The queue keeps **one pinned issue, "Queue"** (label
`queue:status`). It rewrites the issue's body only when something changes,
so there is at most one `PATCH` per change. The body has four parts:

- **Now:** the issue and phase running, since when, and turns so far.
- **Waiting for you:** each gate, with links to the PR and the page.
- **Budget:** `/usage` session % and week %, the reset time, and the
  ceiling (decision 1).
- **Recent runs:** the last 10, with phase, time and % of the week (from
  `st.runs`, which `usageTable` already formats, `queue.mjs:108`).

The same data sits in a fenced `json` block at the end of the body.

- **In the GitHub app** the issue is already a readable dashboard, with
  no new code on the phone.
- **The review page**, opened without `?pr=`, draws it as a Queue view,
  each waiting item with its **Approve**.
- **Comments on the status issue** are commands from the owner: `pause`,
  `resume`, `budget 90`. The listener reads them like any other comment.

**Why an issue, not a database or a gist.** It is already in the API the
page and the queue use, it shows in the phone's GitHub app, it keeps its
own edit history, and it needs no new scope.

**Why not a third-party console.** See the table in
[`data/options.md`](./data/options.md):

- Remote Control, Dispatch and Happy drive *live sessions*. None of them
  has gates or PRs, or knows about the budget.
- Vibe Kanban has a board and diff review, but it is sunsetting, and its
  board would replace GitHub as the record.
- GitHub's Agent HQ bills through Copilot, not your subscription.
- Hermes and OpenClaw are personal-agent gateways (chat apps in, an agent
  of their own out). See [below](#hermes-openclaw-and-other-agent-gateways).

> **Q:** havent you considered hermes or similar options?

> **A:** Not in round 1; now in
> [their own section](#hermes-openclaw-and-other-agent-gateways). You'd
> text "research X" on Telegram, Hermes's own model (on an API key: the
> subscription covers only Claude Code) calls its `claude-code` skill,
> which runs `claude -p`, and a summary comes back. That is the queue with
> a paid dispatcher in front, no gates, and a gateway to patch. The phone
> chat it adds, Remote Control gives for free. Recommendation stands;
> Hermes is decision 6.

## Decisions for you

1. **Budget.**
   - (a) Show it only.
   - (b) **Show it, and start no run above 85% of the week**, changed by
     commenting `budget N` on the status issue *(recommended)*.
   - (c) A dollar cap.

   Cost of (b): about 15 lines, and a run can still finish above the
   ceiling. (c) gates the wrong meter, since the plan runs out by window,
   not by dollars ([agent-queue](../2026-10-17-agent-queue/README.md)).
2. **Remote Control for ad-hoc work.**
   - (a) **Use it by hand when away** (`claude remote-control --spawn worktree`
     in the repo), next to the queue *(recommended)*.
   - (b) Keep it always on with a LaunchAgent.
   - (c) Don't use it.

   Cost: none to maintain, since Anthropic keeps it. Its runs draw from
   the same windows, so the queue's `/usage` figures include them. Its
   transcripts are stored on Anthropic's servers while connected.
3. **Push instead of polling.** A GitHub webhook can post to a second ntfy
   topic that the Mac subscribes to, which gives sub-second reaction with
   no open port.
   - (a) **Later, only if 10 s feels slow** *(recommended)*.
   - (b) Now. Cost: one more secret topic and a stream that has to stay
     connected.
4. **Engine on GitHub Actions** (`claude-code-action` with
   `CLAUDE_CODE_OAUTH_TOKEN`), so the Mac no longer needs to be awake.
   - (a) **Not now** *(recommended)*: the gates would have to be rebuilt as
     workflows, the previews need macOS and Chrome, and a self-hosted
     runner on a public repo lets any fork's PR run code on the Mac.
   - (b) Try it on `research` issues only. They need no Flutter.
5. **Two comment pages.** `.tool/doc open` (`annotate.mjs`, local, writes
   the file) and the review page (Pages, posts to the PR) both draw
   Markdown and take notes.
   - (a) **Keep both for now** *(recommended)*: the local one works with
     no PR.
   - (b) Retire the local one.

6. **A chat gateway (Hermes) for ad-hoc work.**
   - (a) **Not now** *(recommended)*: Remote Control covers chat-from-the-phone
     with no second bill and nothing to patch.
   - (b) Try Hermes on the Mac, Telegram only, with a cheap OpenRouter model
     as dispatcher and the `claude-code` skill in print mode. Cost: a
     per-token bill for the dispatcher, a gateway process to keep updated,
     and a second record of work beside GitHub.

## Decided unattended

- **Topic and scope.** The question was framed as "keep Claude Code, add
  a way to interact with it", so the RFC compares tools *around*
  `claude`, and rules out other agents.
- **Tools were read, not installed.** Happy, Vibe Kanban and Remote
  Control were judged from their docs and READMEs. None was run on the
  Mac, which an unattended run shouldn't change.
- **Every decision above is marked with its recommended option.**
- **Round 2 (Hermes).** The note asked about Hermes "or similar", read as
  the self-hosted personal-agent gateways: Hermes Agent and OpenClaw.
  Coding-agent multiplexers (Claude Squad, Conductor and the like) were
  left out, since they are desktop screens for live sessions, the niche
  Remote Control already fills. Neither gateway was installed. No Phase 4
  pass: the note did not ask for one.

## Deeper

### How it works today

```
issue / comment ──(LaunchAgent, a pass every 60 s)──▶ tick()
   tick: gh issue list, then per issue at a gate: 3 paginated reads
   one job ready ─▶ await work() ── claude -p … (10–60 min) ──▶ PR, comment, ntfy
                         ▲ while this runs, nothing is read or acknowledged
phone: ntfy push (one "Open" button) ─▶ GitHub app or review.html ─▶ type "approve"
budget: /usage read before and after each run, shown per PR, never acted on
```

### Diagnosis

| # | Symptom | Root cause | Where |
|---|---------|------------|-------|
| 1 | Slow to react to comments | The loop sleeps 60 s between passes and awaits the whole run, so comments are read only between jobs. Measured over 12 answers: median 69 s, p75 328 s, max 3,252 s | `.tool/queue.mjs:583`, `:560`; [`code/latency.mjs`](./code/latency.mjs) |
| 2 | Approving means typing | A PR author can't approve their own PR, and the queue opens PRs as you, so approval is a regex over the comment text | `.tool/queue.mjs:44`, `:282` |
| 3 | The push can only open a page | Its one action is `view` "Open" | `.tool/queue.mjs:72` |
| 4 | The HTML pages feel hacky | Two pages draw Markdown and take notes, one local and one on Pages, and the token is asked for in a `prompt()` | `.tool/annotate.mjs:148`, `.tool/review.html:380` |
| 5 | No view of the queue away from the Mac | The state is in `.git/queue/*.json` and only `queue ls` reads it. Usage is shown per PR, never as a total | `.tool/queue.mjs:652`, `:101` |
| 6 | No budget control | `/usage` is read around every run but never gates one. The agent-queue RFC decided against a gate | `.tool/queue.mjs:80`, `:185` |

There is nothing to test here yet: `queue.mjs` exports `answers`,
`feedback` and `approves` for tests, but no test covers the loop's timing.

### The literature

1. **Response-time limits.** 0.1 s, 1 s and 10 s. Past 10 s, show when it
   will be done [1]. *For us:* acknowledge within 10 s, and show "next
   after #12" rather than nothing.
2. **GitHub REST practice.** Prefer webhooks. If you poll, respect
   `x-poll-interval`, and `304`s are free [2]. *For us:* three
   conditional calls every 10 s cost nothing on a quiet day.
3. **Authors can't approve** [3]. *For us:* the button has to post our
   own word. GitHub's review state can't carry it.
4. **Remote Control** [4]. It runs locally the whole time. Server mode
   spawns sessions on demand (`--spawn worktree`, `--capacity`, default
   32). It needs subscription auth ("API keys are not supported"), and
   the process must keep running. Claude decides when to send a push.
   *For us:* a maintained phone UI for live work, with no gates.
5. **Channels** [5]. A research preview: an MCP server pushes events
   into *one open session*, behind a sender allowlist, and can relay
   permission prompts. *For us:* it fits a chat bridge, not a queue of
   fresh sessions.
6. **Dispatch** [6]. You message a task from the phone and it spawns a
   Desktop Code session, with a push when it is done. Pro/Max only.
   *For us:* the same niche as Remote Control.
7. **Happy** [7]. MIT, an Expo app plus a CLI that wraps the
   `claude`/`codex` harnesses, end-to-end encrypted, with its own relay
   server. *For us:* an open-source Remote Control. It adds a relay to
   trust and offers no gates.
8. **Vibe Kanban** [8]. A board, a worktree per card, diff review with
   inline comments, many agents. It is sunsetting. *For us:* the
   maintenance risk of a third-party console, seen in practice.
9. **claude-code-action** [9]. Pro/Max can authenticate with
   `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token`. GitHub warns
   against self-hosted runners on public repos, since a fork's PR can run
   code on them [10]. *For us:* GitHub-hosted runners only, if ever
   (decision 4).
10. **ntfy actions** [11]. The `http` button POSTs with headers and a
    body, and the topic is the password. *For us:* the push links to the
    page and never carries the token.
11. **Agent HQ** [12]. Claude runs inside Copilot, billed through
    Copilot. Secondary sources only, and they disagree on which plans get
    it. *For us:* a different bill, so out.

### Hermes, OpenClaw and other agent gateways

Both are MIT, self-hosted, and built the same way: one **gateway** process
that holds the chat connections (Telegram, WhatsApp, Slack, Discord,
Signal…), a cron, and **an agent loop of their own** that picks a model
and tools on every message [13][15].

| Part | What it is | Who owns it | Example |
|---|---|---|---|
| Gateway | the process that talks to the chat apps | Hermes / OpenClaw, on your Mac or a VPS | a Telegram bot that takes "research X" |
| Dispatcher | the agent that reads the message and picks a tool | Hermes's loop, on **your API key** | an OpenRouter model choosing the `claude-code` skill |
| Worker | the agent that writes the code | Anthropic: `claude -p`, on the subscription | the same command `queue.mjs` runs |
| Gates, PRs, budget | what stops and waits for you | nobody: neither has them | today, `.tool/queue` |

What we read:

1. **Hermes and Claude Code.** Hermes ships a `claude-code` skill: print
   mode (`-p`) for one-shot tasks, tmux for multi-turn, `-w` for a
   worktree, and "never send a blind `Enter` on a timer to approve
   prompts" [14]. A PR to make `claude -p` a full Hermes *provider* was
   closed "as not-planned per standing maintainer policy" (July 2026) [16].
   *For us:* Claude Code is a tool Hermes calls, never its brain.
2. **The bill.** Subscription OAuth is for "ordinary use of Claude Code
   and other native Anthropic applications"; others "should use API key
   authentication" [17]. OpenClaw's own docs say to reuse the `claude` CLI
   login on the same host and "do not copy an OAuth token into OpenClaw",
   and recommend an API key "for shared production automation" [15].
   *For us:* the dispatcher is a second, per-token bill.
3. **Maintenance.** OpenClaw's CVE-2026-25253 (CVSS 8.8): a crafted link
   made the Control UI hand its gateway token to an attacker, even on
   localhost; the fix needed a manual update [18]. *For us:* the burden the
   issue asked to avoid, and the failure case of idea 3.
4. **What they do well.** One chat for every phone app, cron with delivery
   to the chat, command approval [13]. *For us:* the phone side is what
   Remote Control and the ntfy push already cover; nothing here replaces
   the gates.

### Rollout

| Phase | Ships | Fixes | Size |
|-------|-------|-------|------|
| 0 | Measure: `code/latency.mjs` (done: median 69 s, p75 328 s, max 3,252 s) | n/a | done |
| 1 | Listener apart from the worker, 10 s conditional poll | 1 | S |
| 2 | Approve on the review page, and the push's second button | 2, 3 | S |
| 3 | Status issue, the page's Queue view, `pause`/`resume`/`budget N` | 4, 5, 6 | M |
| 4 | Remeasure latency, and decide on webhooks (decision 3) | n/a | XS |

## References

1. Nielsen Norman Group, *Response times: the 3 important limits*. https://www.nngroup.com/articles/response-times-3-important-limits/: 10 s holds attention; longer needs a "when it's done" estimate.
2. GitHub, *Best practices for using the REST API*. https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api: webhooks over polling; a `304` doesn't count against the rate limit.
3. GitHub, *Approving a pull request with required reviews*. https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/approving-a-pull-request-with-required-reviews: "Pull request authors cannot approve their own pull requests."
4. Claude Code, *Remote Control*. https://code.claude.com/docs/en/remote-control: server mode, `--spawn worktree`, `--capacity`, subscription only, the process must keep running, push notifications, transcripts stored while connected; also the comparison with Dispatch, Channels and Slack.
5. Claude Code, *Channels*. https://code.claude.com/docs/en/channels: research preview; events into an open session; allowlist; permission relay.
6. Claude Code, *Desktop: sessions from Dispatch*. https://code.claude.com/docs/en/desktop: a task messaged from the phone spawns a Code session; Pro/Max.
7. slopus/happy, README. https://github.com/slopus/happy: MIT; app, CLI wrapping the harnesses, relay server; ~24k stars.
8. BloopAI/vibe-kanban, README. https://raw.githubusercontent.com/BloopAI/vibe-kanban/HEAD/README.md: "Vibe Kanban is sunsetting"; worktree per card; diff review.
9. anthropics/claude-code-action, *Setup*. https://github.com/anthropics/claude-code-action/blob/main/docs/setup.md: `CLAUDE_CODE_OAUTH_TOKEN` via `claude setup-token` for Pro/Max.
10. Datadog, *GitHub self-hosted runner* rule (citing GitHub's guidance). https://docs.datadoghq.com/security/code_security/iac_security/iac_rules/cicd-github-self-hosted-runner/: no self-hosted runners on public repos.
11. ntfy, *Publishing*. https://docs.ntfy.sh/publish/: `http` actions with headers and body; "the topic is essentially a password".
12. letsdatascience, *GitHub adds Claude and Codex to Copilot* (secondary). https://letsdatascience.com/news/github-adds-claude-and-codex-to-copilot-3ae28203: Agent HQ, Copilot billing.

13. NousResearch/hermes-agent, README. https://github.com/NousResearch/hermes-agent: MIT; one gateway for Telegram, Discord, Slack, WhatsApp, Signal; cron; command approval; any provider.
14. Hermes docs, *Claude Code* skill. https://hermes-agent.nousresearch.com/docs/user-guide/skills/bundled/autonomous-ai-agents/autonomous-ai-agents-claude-code: print mode, tmux for interactive, `-w` worktrees, read prompts before approving.
15. OpenClaw docs, [overview](https://docs.openclaw.ai/) and [Anthropic provider](https://docs.openclaw.ai/providers/anthropic): one gateway, browser dashboard; reuse the Claude CLI login on its host, API key for shared automation.
16. hermes-agent PR #40528. https://github.com/NousResearch/hermes-agent/pull/40528: `claude -p` as provider, closed as not planned (2026-07-14).
17. Claude Code, *Legal and compliance*. https://code.claude.com/docs/en/legal-and-compliance: subscription OAuth for Claude Code and native apps; API keys for other products.
18. runZero, *OpenClaw CVE-2026-25253*. https://www.runzero.com/blog/openclaw/: one-click gateway token theft, CVSS 8.8, fixed in 2026.1.29 (secondary; exposure counts vary by source).

Measured here: [`data/latency.md`](./data/latency.md) ([`code/latency.mjs`](./code/latency.mjs));
the options compared: [`data/options.md`](./data/options.md).

**Unverified:**

- Agent HQ plans and billing (secondary sources only).
- Happy's push notifications and how it starts sessions (not stated in
  its README).
- Whether Dispatch needs the Desktop app open.
- Hermes's star count and release pace (the README showed ~256k stars on
  2026-10-21; secondary sources disagree), and whether a third-party
  `claude -p` provider plugin for Hermes is maintained.

A Phase 4 pass would check these, and re-read the options table against
current releases.
