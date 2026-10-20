# An agent queue that works while you don't

2026-10-17. RFC. Status: decided and built (2026-10-20) as `.tool/queue`, with GitHub Issues as the inbox and no budget gate; see the answers under Decisions. Deep-research pass not run.

## Thesis

**Own everything around the model (the queue, the scheduler, the budget
gate, the gates and the phone) and keep Claude Code only as the engine, run
headless on the MacBook at night, metered by the subscription's own windows
rather than by dollars.**

"Costs must be the same" decides the engine. The subscription is the only
way the price stays flat, and its login is only allowed inside the
unmodified Claude Code binary. OpenCode (installed here) or the Agent SDK
signed in with the subscription is explicitly ruled out [1]. So the
independent part can't be the engine; it is everything around it. That is
also the part worth owning: a queue of Markdown files, a `launchd` job, a
budget rule and `ntfy` push. None of it is Claude-specific, and an engine
adapter (`claude -p` today, `opencode run` with a paid key as a fallback)
is one function. Claude Code on the web would cost the same, since it draws
from the same pool [6], but it is the most Claude-bound option of all and
cannot run the Mac's Flutter, Chrome and simulators.

"Spend limit" has to mean **percent of the 5-hour and weekly windows**,
because that is what runs out. The good news, measured: an unattended
process can read both for free. `claude -p "/usage"` is a local command (0
tokens, 0.4 s) that returns `Current session: 61%` and `Current week: 68%`,
and every stream-json run emits a `rate_limit_event` with `utilization` and
epoch `resetsAt` ([`data/usage-probe.md`](./data/usage-probe.md)). The gate
is ~40 lines ([`code/budget.mjs`](./code/budget.mjs)). You never prompt
between 00:00 and 11:00
([`data/sessions.txt`](./data/sessions.txt)), so the night holds two full
5-hour windows. **The weekly cap binds, not the hours**: the queue moves
work into the night, it does not add capacity. On this plan (Pro, 68% of
the week used in six days) that is the honest limit.

What it does **not** need: a server, a database, Claude cloud, a new app,
or the Pi as a runner. The skills already stop at the right places
(design approval, RFC notes). Run unattended, each stop becomes a **gate**:
the run writes its state into the topic folder, pushes a notification and
exits. Your answer starts the next phase as a **fresh** session, which is
also cheaper: `/usage` says 45% of the last day's usage was at more than
150k of context.

## How it works today

```
you ──/create, /research, /improve──▶ claude (interactive, on the MacBook)
         ▲                                │
         └──── you read, answer, approve ◀┘   (each phase stops and waits)
```

- Every run is started by hand and waits for you at each phase: 45 sessions
  in 15 days, ~$179 API-equivalent ([`code/sessions.mjs`](./code/sessions.mjs)).
- **Prompts happen only between 11:00 and 24:00.** 00:00–11:00 has had none.
- Billing is a subscription (`billingType: stripe_subscription`,
  `organizationType: claude_pro` in `~/.claude.json`). The USD in
  transcripts and `.tool/cost` is the API price, not money spent.
- `/usage` at 22:00 today: session 61%, week 68% (resets Sun 10:00).
- MacBook Air M5, fanless, 16 GB. Sleeps when the lid closes (`pmset -g`:
  sleep held off now only by `caffeinate` and Claude).
- An always-on Raspberry Pi already serves production through a Cloudflare
  tunnel (SETUP.md §4).

## Diagnosis

| # | Symptom | Root cause | Where |
|---|---------|------------|-------|
| 1 | Nothing happens unless you are at the keyboard | Skills say "Stop after each phase … only go on when the user asks"; there is no queued or headless form | `.claude/skills/create/SKILL.md:8` |
| 2 | Unattended, a skill would block or guess | Forks go through `AskUserQuestion`, which `--permission-prompts none` removes from the tool list [2] | `.claude/skills/create/SKILL.md:143`, `improve/SKILL.md:39` |
| 3 | Idle hours are wasted | No queue: a request lives in your head until you type it | — |
| 4 | A dollar "spend limit" would gate the wrong thing | The plan is metered in 5-hour/weekly windows; `.tool/cost` prints API-equivalent USD | `.tool/cost.mjs:14` |
| 5 | Gates (design, RFC notes) need you at the Mac | The comment page binds to 127.0.0.1 | `.tool/annotate.mjs:148` |
| 6 | The laptop sleeps with the lid closed | macOS default; an Air has no clamshell mode without a display | `pmset -g` |
| 7 | Long sessions burn the window | 45% (day) / 58% (week) of usage at >150k context; a gate answered in the same session re-reads all of it | [`data/usage-probe.md`](./data/usage-probe.md) |

## What the literature says, applied here

1. **The subscription only works inside Claude Code.** OAuth login "is
   intended exclusively for … subscription plans" and Claude Code and native
   apps; Agent SDK products "should use API key authentication" [1]. The
   January–February 2026 enforcement hit OpenCode by name [7]. *For us:*
   the engine is `claude -p`, unmodified, signed in as you, on your machine.
   Nothing that intermediates the token (a custom SDK runner, OpenCode with
   your Max/Pro login).
2. **The same docs allow exactly this kind of use.** Pro/Max limits
   "assume ordinary, individual usage of Claude Code and the Agent SDK" [1],
   and `claude -p` runs your skills (`/research …` in the prompt is
   expanded) [2]. *For us:* one person's queue on their own laptop, one job
   at a time, sits inside that. Twenty parallel workers would not.
3. **Headless has every control the runner needs** [2]: `--output-format
   stream-json` (with `rate_limit_event`, `result.total_cost_usd`,
   `session_id`), `--max-turns`, `--max-budget-usd` (an API-price estimate,
   useful as a runaway cap, not as the meter), `--permission-mode auto` with
   `--permission-prompts none` for unattended runs, SIGINT to end a turn
   cleanly (SIGTERM leaves it unfinished). `--bare` skips skills and
   CLAUDE.md and **needs an API key**, so we can't use it. *For us:*
   no `--bare`; `auto` + `none` + a project allowlist.
4. **Long-running agents resume from files, not from context** [3]: one
   feature per session, a progress file, a JSON list only the agent's
   status field changes, git commits as checkpoints, and a check at the
   start of each session. *For us:* each phase is a fresh `claude -p` that
   reads the topic folder (the delivery README, the RFC and its notes),
   which `/create` already does at approval (`/create build <slug>`). The
   queue item's `status` is the progress file.
5. **The usage windows are readable** [4]: the status line gets
   `rate_limits.five_hour/seven_day.used_percentage` and `resets_at`, only
   for Pro/Max, and they drift between concurrent terminals. *For us:* the
   runner reads `/usage` before each job (free), watches
   `rate_limit_event` during it, and runs **one job at a time** so the
   figure stays honest.
6. **Hooks cover the notifications** [5]: `Notification` fires with
   `agent_needs_input`, `agent_completed`, `permission_prompt`,
   `idle_prompt`; `Stop` gets `last_assistant_message`; `SessionEnd` hooks
   get 1.5 s. *For us:* one `Notification` hook that posts to ntfy helps the
   interactive sessions on day one, before any queue exists.
7. **ntfy is a phone channel you can own** [8][9]: a POST is a push; up to
   three action buttons (`view` opens a URL, `http` fires a request). A
   self-hosted server needs `upstream-base-url: https://ntfy.sh` for instant
   iOS delivery (only a poll id goes upstream; without it delivery "can take
   hours"), and should be `deny-all` by default. *For us:* the dispatcher
   **subscribes** to an inbox topic over outbound HTTP, so the phone can
   add a request or press "Approve" and the Mac needs no open port.
8. **Keeping an Air awake with the lid closed** [10]: `sudo pmset
   disablesleep 1` works without a display, on AC; heat is the risk on a
   fanless Air, and it must be set back. *For us:* the dispatcher turns it
   on only while a job runs and on AC, and off after (a sudoers rule for
   that one command).

## Capacity: how much fits in a week

What each kind of run costs in **percent of the weekly limit**, from every
transcript (subagents included), split at each `/clear`, weighted by price
ratios and calibrated against one `/usage` reading (68% used between the
week's start, Sun 10:00, and Sat 21:51) by
[`code/weekly.mjs`](./code/weekly.mjs) → [`data/weekly.txt`](./data/weekly.txt):

| Run | Runs seen | Median turns | Median % of week | p75 | Max |
|-----|-----------|--------------|------------------|-----|-----|
| `/create` design (incl. `/feature`, `/design-proposal`) | 9 | 57 | 1.5 | 3.4 | 4.1 |
| `/create build` | 4 | 74 | 2.1 | 5.0 | 5.0 |
| `/research` (no deep-research pass) | 3 | 33 | 1.1 | 1.4 | 1.4 |
| `/improve`: one run, the session that wrote the skill (5 requests) | 1 | 55 | 1.7 | — | — |
| Everything else (fixes, ad-hoc work, pre-skill features) | 35 | 20 | 0.3 | 2.0 | 10.9 |

A creation is a design and a build: **~3.6% median**, ~2.7% for a small one
(link cards: 1.5 + 1.2), ~9% for a Projects-sized one (4.0 + 5.0), before
the fixes that follow it. This week 29% of the limit went to `/create` and
36% to everything else.

With 4 research runs and 1–2 improvements a day, and ~10% kept for fixes and
ad-hoc sessions:

| | Light | Heavy |
|---|---|---|
| Research, 4 × | 1.3% → 5% | 2% (with a deep-research pass) → 8% |
| Improvements | 7 × 1% → 7% | 14 × 1.5% → 21% |
| Fixes, ad hoc | 10% | 10% |
| **Left for creations** | **78%** | **61%** |
| Small (2.7%) | 28 | 22 |
| Median (3.6%) | 21 | 17 |
| Projects-sized (9%) | 8 | 6 |

So **~15–20 typical creations a week, or 6–8 large ones**. A realistic mix is
about 10–12. Two cautions:

- The 5-hour window, not the week, caps one evening: it ran to 61% today.
  How many weekly points one window holds is not measured yet (rollout
  phase 0).
- The calibration counts only this machine. Any claude.ai chat this week also
  counts toward the 68%, so these per-run figures are, if anything, too high.
  One reading is a thin calibration. Phase 0's before/after readings
  replace it.

## Recommendations

### 1. (first) The queue: Markdown files in the repo

`product/queue/<date>-<slug>.md`, one per request, frontmatter plus the
prompt as you'd type it:

```markdown
---
kind: research | create | improve
status: queued | running | gate | done | failed | parked
priority: 2            # 1 first
gate: null             # design | rfc-notes | approval, while status=gate
topic: product/research/2026-10-17-agent-queue   # set by the first run
runs: []               # {phase, session, started, minutes, session_pct, week_pct}
---
Research how the agent could …
```

Files, because the topic folder is already the state that every skill
reads and writes, git versions it, and `.tool/doc` can show it. Adding one
from the phone goes through the ntfy inbox (rec. 4), which writes the file.
`.tool/queue ls | add <kind> "<prompt>" | park <id>` covers the terminal.

### 2. (first) The dispatcher: `launchd` + one Node script

`.tool/queue run`, started every 15 minutes by a LaunchAgent
(`~/Library/LaunchAgents/dev.pietroid.lunna-queue.plist`,
`StartInterval 900`):

1. **Window.** Only between 00:00 and 10:30 (configurable), only on AC
   (`pmset -g batt`), and never while an interactive `claude` is running
   (`pgrep`), so it never competes with you.
2. **Budget gate** (`code/budget.mjs`): start a job only if the 5-hour
   window is under 80% and the week is under its pacing line, *elapsed
   share of the week − 15 points* reserved for you. Today: 68% used, line
   77.8%, so go ([`data/budget-sample.json`](./data/budget-sample.json)).
3. **Pick** the highest-priority `queued` item, or a `gate` item you've
   answered (rec. 3).
4. **Run** it in its own worktree and branch (`agent/<slug>`), never main:

> **Q:** _“Budget gate (code/budget.mjs): start a job only if the 5-hour window is under 80% and the week is under its pacing line, elapsed share of the week − 15 points reserved for you. Today: 68% used, line 77.8%, so go”_ — Dont need for now.

> **A:** Dropped. No gate: every run records `/usage` before and after, and the PR description and each push show it (`.tool/queue`).

   ```bash
   claude -p "/research <prompt>" --permission-mode auto --permission-prompts none \
     --max-turns 120 --output-format stream-json --verbose
   ```

   with `LUNNA_QUEUE=1` in the env. Watch the stream: on a
   `rate_limit_event` above 90%, SIGINT and mark it `parked`; the next
   window resumes it from its files.
5. **Record** `/usage` before and after into `runs[]`, so each kind's cost in
   window-percent is learned rather than guessed (`.tool/cost` keeps the
   token view).
6. **Notify** (rec. 4) and exit. One job per tick, one at a time.

The engine call is one function. A fallback adapter (`opencode run`, or
Codex, with a **paid** key) can be wired for when the week is spent, off by
default because it breaks "costs the same".

### 3. (first) Gates: the skills learn an unattended mode

One paragraph in each skill, read when `LUNNA_QUEUE=1`:

- Don't call `AskUserQuestion` (it isn't there). Write each fork into the
  document as `> **Q (agent):** … Options: A *(recommended)*, B.`, take the
  recommended option **only** where the skill already allows a default, and
  otherwise stop.
- At the end of a phase that waits for you, set the queue item to
  `status: gate`, `gate: <name>`, commit on the branch, and exit.

| Skill | Gate | You answer with | Next run |
|-------|------|-----------------|----------|
| `/research` | `rfc-notes`: after Phase 3 | notes on the page, or "go" | answers notes, then Phase 4 (deep research) if you said so |
| `/create` | `design`: board and prints ready | Decision note, or ✓ in ntfy | `/create build <slug>`, fresh session |
| `/create` | `delivery`: build done, `.tool/check` green | review the branch | you merge; nothing auto-merges |
| `/improve` | `approval`: the forks of step 2 | the answers | the change and its report |

The dispatcher treats a gate as answered when `.tool/doc notes <topic>
--open` shows no open agent question **and** there's a new Decision or
"go", or when the ntfy "Approve" button posts. Each answer starts a fresh
session from the files (finding 4), never `--resume` of a 200k one.

### 4. (second) The phone: ntfy, both ways

- **Out:** `POST` to `ntfy.sh/<secret-topic>` (or the Pi's own ntfy later)
  at three moments only: a gate is open, a job failed, the week's budget
  stopped the queue. Buttons: `view` → the RFC/board, `http` → Approve,
  Park.
- **In:** the dispatcher long-polls `<secret-topic>-inbox/json`; a message
  from the ntfy app like `research: how could …` becomes a queue file.
- **Interactive sessions too:** a `Notification` hook on
  `agent_needs_input|agent_completed` posts the same way. This ships first,
  alone, and is useful immediately.
- **Reading on the phone:** the gate's `view` link needs a page. Options in
  decision 3.

### 5. (second) Keeping the Mac available

| Option | Lid closed | Cost | Note |
|--------|------------|------|------|
| Lid open, display off, on AC (`pmset -c sleep 0`) | no | none | simplest; `caffeinate -s` while a job runs |
| `pmset disablesleep 1` only while a job runs *(recommended)* | yes | a sudoers line | dispatcher sets and clears it; heat on a fanless Air, so AC and a hard surface |
| `pmset repeat wakeorpoweron` at 00:30 | needs the above | none | wakes a sleeping Mac for the window; unverified with lid closed |
| Pi as the runner | n/a | setup, risk | ARM Linux Flutter is unofficial, no iOS simulator, and it holds production secrets |
| Claude Code on the web | n/a | same pool | ruled out by "independent"; no local Flutter/Chrome |

The Pi is the right home for the **always-on half** (ntfy server, later the
inbox) and the wrong home for the agent.

## Decisions for you

1. **Engine.** `claude -p` on the subscription *(recommended)*: same cost,
   allowed [1]. / OpenCode or Codex with an API key: independent, costs
   per token (~$20/day at your pace, from the transcripts' API prices).
   / Claude Code on the web: same cost, most Claude-bound.
2. **Inbox.** Markdown files + ntfy inbox topic *(recommended)*: one tool
   both ways, no ports. / GitHub Issues: best phone UI, needs a
   sync. / A Lunna project ("Agente") as the inbox: dogfoods the app's
   dictation and notes, but couples the product to the workflow.
3. **Reading gates on the phone.** Push the branch and read the Markdown
   on GitHub *(recommended to start)*: zero infra, but no note-taking. /
   Expose `.tool/doc` through the existing Cloudflare tunnel behind Access:
   full commenting, one more public surface. / Tailscale: private, one
   more app.
4. **Budget.** Window share and reserve: 80% of each night window, 15
   weekly points kept for you *(recommended)*. Tighter if you often work
   Saturdays before the reset.
5. **What may run unattended.** `/research` only for the first two weeks
   *(recommended)*, then `/improve`, then `/create` design. `/create build`
   always stops at `delivery`; nothing merges itself.
6. **ntfy host.** ntfy.sh with a long random topic *(recommended to
   start)*: titles pass through their server. / Self-hosted on the Pi with
   `deny-all`, upstream for iOS.

> **Q:** _“Engine. claude -p on the subscription (recommended): same cost, allowed [1]. / OpenCode or Codex with an API key: independent, costs per token (~$20/day at your pace, from the transcripts' API prices). / Claude Code on the web: same cost, most Claude-bound.”_ — claude locally in my mac seems good.

> **A:** Done: `claude -p` on the subscription, in a worktree per issue, `--permission-mode auto --permission-prompts none`.

> **Q:** _“GitHub Issues: best phone UI, needs a sync.”_ — Github issues is better. But I would still have the markdown _after_ the task is done, but that is essentially the research and create task right? I think it would just be nice to add as well the content as PR. Imagine I open a github issue, the agent opens a PR with the description very much alike the MD we had. My role is to approve the design (it could be a comment for example that i must answer in the issue) and when everything is done, it just merges to main and let me know that the issue was solved.

> **A:** Built that way in `.tool/queue`: the issue is the queue (Create/Research/Improve templates add the label), the draft PR's description is the delivery README with its pictures under a usage table, you answer on the issue (`approve` alone goes on, anything else is feedback), and the last `approve` merges into main, closes the issue and pushes to the phone.

> **Q:** _“Expose .tool/doc through the existing Cloudflare tunnel behind Access: full commenting, one more public surface.”_ — no need for that. lets just have github issues as described by the comment above

> **A:** Done: nothing exposed; the PR is the page you read.

> **Q:** _“Budget. Window share and reserve: 80% of each night window, 15 weekly points kept for you (recommended). Tighter if you often work Saturdays before the reset.”_ — lets not worry about budget for now. I think we can let the github description know

> **A:** Done: per-run and total usage (time, turns, tokens, API-eq. USD, 5-hour and weekly windows) top the PR and ride on every push.

> **Q:** _“What may run unattended. /research only for the first two weeks (recommended), then /improve, then /create design. /create build always stops at delivery; nothing merges itself.”_ — Everything run unattended, I alraedy trust it enough.

> **A:** Done: all three kinds run unattended, and the last gate merges.

> **Q:** _“ntfy host. ntfy.sh with a long random topic (recommended to start): titles pass through their server.”_ — it can be. I just need a easy notification service on the phone.

> **A:** ntfy.sh with a random topic: install the ntfy app and subscribe to it. No account, no server.

## Rollout

| Phase | Ships | Fixes | Size |
|-------|-------|-------|------|
| 0 | `SessionStart`/`SessionEnd` hook appending `/usage` to a CSV; a week of it gives each kind's cost in window-% | 4 | 1 h |
| 1 | `Notification` hook → ntfy for interactive sessions | 5 (partly) | 1 h |
| 2 | `product/queue/`, `.tool/queue`, `launchd` job, budget gate, worktrees; `/research` only | 1, 3, 4 | 1 day |
| 3 | Unattended mode in the three skills; gates; ntfy Approve and inbox | 2, 5 | 1 day |
| 4 | Keep-awake while running; ntfy on the Pi; optional paid fallback engine | 6 | ½ day |
| 5 | Measure after two weeks: jobs/night, gate wait, % of week used at night vs day | — | 1 h |

> **Q:** _“Keep-awake while running; ntfy on the Pi; optional paid fallback engine”_ — Why on the pi? Cant we use another service?

> **A:** No need: ntfy.sh is the service. Nothing runs on the Pi.

## References

1. Claude Code, *Legal and compliance* (Authentication and credential use; Acceptable use). https://code.claude.com/docs/en/legal-and-compliance: OAuth only for Claude Code and native apps; SDK products use API keys; limits assume ordinary individual use of Claude Code and the Agent SDK.
2. Claude Code, *Run Claude Code programmatically*. https://code.claude.com/docs/en/headless: `-p`, stream-json, `--permission-prompts none` removes `AskUserQuestion`, `--bare` needs an API key, SIGINT vs SIGTERM, skills expand in `-p`.
3. Anthropic Engineering, *Effective harnesses for long-running agents*. https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents: fresh sessions resume from a progress file, a feature list and git.
4. Claude Code, *Customize your status line*. https://code.claude.com/docs/en/statusline: `rate_limits.five_hour/seven_day.used_percentage`, `resets_at`, Pro/Max only.
5. Claude Code, *Hooks reference*. https://code.claude.com/docs/en/hooks: `Notification` types (`agent_needs_input`, `agent_completed`), `Stop.last_assistant_message`, `SessionEnd` budget.
6. Third-party summaries of plan limits (secondary, unverified against Anthropic): https://www.datacamp.com/tutorial/claude-code-usage-limits, https://claude-monitor.com/claude-code-usage-limits: web, desktop and CLI share one pool; programmatic use was not split off.
7. The Register, *Anthropic clarifies ban on third-party tool access to Claude* (2026-02-20). https://www.theregister.com/software/2026/02/20/anthropic-clarifies-ban-on-third-party-tool-access-to-claude/5014546: OpenCode named.
8. ntfy, *Publishing*. https://docs.ntfy.sh/publish/: headers, `view`/`http` actions, up to three.
9. ntfy, *Configuration*. https://docs.ntfy.sh/config/: `upstream-base-url` for iOS, `auth-default-access: deny-all`.
10. *How to Keep Your MacBook Running 24/7 for AI Agents* and Beebom (secondary). https://blitzmetrics.com/?p=103280, https://beebom.com/how-prevent-mac-sleeping-when-closing-lid/amp/: `pmset disablesleep 1`, AC only, heat on an Air.

Measured here: [`data/usage-probe.md`](./data/usage-probe.md) (`/usage` and
`rate_limit_event` from a headless run), [`data/sessions.txt`](./data/sessions.txt)
and [`data/sessions.csv`](./data/sessions.csv) (`code/sessions.mjs`),
[`data/budget-sample.json`](./data/budget-sample.json) (`code/budget.mjs`).

**Unverified:** that programmatic and interactive use still share one pool
(secondary sources only; the probe shows `claude -p` reporting the same
percentages, which suggests it); that `pmset repeat` wakes an Air with the
lid closed; whether ntfy's `http` action buttons work on iOS as on Android.
