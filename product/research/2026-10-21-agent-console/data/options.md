# The options, side by side (2026-10-21)

What each one would take over from `.tool/queue` + GitHub, read from its
docs or README on 2026-10-21 (links in the RFC's References). "Gates" means
the design / RFC / review stops that wait for an answer and leave a PR.

| Option | Who maintains it | Runs Claude where | Uses the subscription | Gates and PRs | Queue, budget view | Fit |
|---|---|---|---|---|---|---|
| **The queue + GitHub (today)** | you (~1,100 lines: queue.mjs, review.html) | the Mac, `claude -p` | yes | yes | `queue ls` on the Mac only | keep, fix the cracks |
| Claude Remote Control, server mode (`claude remote-control --spawn worktree`) | Anthropic | the Mac | yes (API keys refused) | no: live sessions, steered from the Claude app | sessions list in the app; no budget | complement for ad-hoc work |
| Claude Dispatch (Desktop + phone) | Anthropic | the Mac (Desktop app) | yes, Pro/Max only | no | no | complement, needs Desktop open |
| Claude Channels (Telegram, Discord, iMessage, own MCP) | Anthropic (plugins), you (a custom one) | the Mac, one open session | yes | no; events into one long session | no | research preview; one session, not a queue |
| Happy (slopus/happy, MIT) | community, ~24k stars | the Mac, wraps `claude` | yes (wraps the real binary) | no | no | a phone remote for sessions, like Remote Control |
| Vibe Kanban (BloopAI) | **sunsetting**; community after the company shut down | local web app, a worktree per card | yes, via the agent's own login | its own board and diff review, not GitHub gates | board yes, budget no | rejected: maintenance risk is the point |
| claude-code-action on GitHub Actions | Anthropic + GitHub | GitHub runners (or a self-hosted one) | `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token` (Pro/Max) | event-driven; you rebuild the gates as workflows | Actions tab; no budget | later, if the Mac must go; self-hosted runner on a public repo is unsafe |
| GitHub Agent HQ / Copilot agents (Claude inside Copilot) | GitHub | GitHub's cloud | **no**: Copilot billing | yes, GitHub's own | GitHub's mission control | rejected: different bill, no Mac |

Added in round 2 (the note "havent you considered hermes or similar options?"):

| Option | Who maintains it | Runs Claude where | Uses the subscription | Gates and PRs | Queue, budget view | Fit |
|---|---|---|---|---|---|---|
| Hermes Agent (NousResearch, MIT) | community, Nous Research | the Mac or a VPS; its `claude-code` skill runs `claude -p` | the worker yes (it is `claude`); its own dispatcher model **no**, per-token | no; command approval only | chat replies, cron; no budget | later (decision 6); a paid dispatcher in front of what the queue runs |
| OpenClaw (MIT) | community | the Mac or a VPS, one gateway; reuses the `claude` CLI login on its host | same as Hermes; docs advise an API key for automation | no | browser dashboard of sessions; no budget | rejected: same shape, plus a gateway with a 2026 one-click token-theft CVE to keep patched |

Added in round 3 (the reply "and multica it seems it allows for claude code"):

| Option | Who maintains it | Runs Claude where | Uses the subscription | Gates and PRs | Queue, budget view | Fit |
|---|---|---|---|---|---|---|
| Multica (multica-ai; Apache 2.0 + conditions; ~53k stars, v0.6.5) | Index Labs and community; releases every few days, 1,880 open issues and PRs | the Mac, a daemon spawning `claude -p` (stream-json, `bypassPermissions`) | yes: no model of its own, the CLI's own login | its own issues, board and workflow handoffs; GitHub PRs linked and read, never written | board, run list, token counts; no plan-window budget | closest fit; not now (decision 7): moves the record off GitHub, pre-1.0, iOS from source only |
