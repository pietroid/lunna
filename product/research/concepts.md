# Concepts: what the RFCs taught

Every idea an RFC taught (*Ideas to keep*, now the `[!TIP]`s recapped in *Go deeper*): the sentence to remember, the
source to read, and where it was met. A new RFC reads this first, gives an
idea already here one line and a link, and goes one level deeper on it
(see `/research`, Phase 3). Newest topics add to the bottom of their group.

RFCs: [agent-reliability](./2026-10-16-agent-reliability/README.md) ·
[agent-queue](./2026-10-17-agent-queue/README.md) ·
[agent-ui](./2026-10-17-agent-ui/README.md) ·
[posthog](./2026-10-21-posthog/README.md) ·
[agent-full-surface](./2026-10-21-agent-full-surface/README.md) ·
[multica-on-the-mac](./2026-10-21-multica-on-the-mac/README.md) ·
[neon-compute](./2026-10-23-neon-compute/README.md) ·
[notification-lifecycle](./2026-10-28-notification-lifecycle/README.md) ·
[lunna-as-a-secretary](./2026-10-28-lunna-as-a-secretary/README.md)

## Tools: what the model is given

### Poka-yoke tools
> Make the wrong call impossible to write, not just discouraged.

- **Read:** Anthropic, [Writing tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents); deeper, SWE-agent's "agent-computer interface" (Yang et al., NeurIPS 2024).
- **Here:** arguments shaped like a drag (`before: <card>`), short refs, days resolved by the server.
- **Met in:** agent-reliability §4.1 (and its Q/A with real cases), agent-ui §4.5.

### Fewer tools
> Every tool you add is one more way for a small model to miss.

- **Read:** Paramanayakam et al., [Less is more](https://arxiv.org/abs/2411.15399) (DATE 2025): fewer tools per task, better calls, up to 70% faster.
- **Here:** new abilities are gesture kinds inside one `answer` tool, not new tools.
- **Met in:** agent-ui §4.7; agent-full-surface, idea 4 (RAG-MCP: >90% under ~30 tools, failure past ~100; Anthropic's tool search only past 10 tools or 10K tokens, so ~35 gesture kinds in one enum need distinct verbs instead). Its Q/A: count **definitions** (the menu, which overlaps) apart from **calls** (each one a chance to miss: 0.97³ = 91%); one `answer` call carries a plan of many changes, and each verb carries only its own arguments.

### Declare once, reached by every caller
> One action, declared once, reached by every caller.

- **Read:** Android, [AppFunctions](https://developer.android.com/ai/appfunctions) (experimental): one annotated function, a generated schema, the app's own repository behind it.
- **Here:** a gesture and its route call the same service method; a rule left in a controller is one the agent skips.
- **Met in:** agent-full-surface, idea 3 and change 1.

### Free text to reason, schemas to choose
> Strict JSON hurts reasoning and helps classification.

- **Read:** Tam et al., [Let Me Speak Freely?](https://arxiv.org/abs/2408.02442).
- **Here:** a loose `intent` string first, then constrained `changes`.
- **Met in:** agent-reliability §4.5.

## Context: what the model reads

### Long context before retrieval
> When it all fits, put it all in; retrieval is for when it doesn't.

- **Read:** Li et al., [Retrieval augmented generation or long-context LLMs?](https://arxiv.org/abs/2407.16833) (EMNLP 2024); Liu et al., [Lost in the Middle](https://arxiv.org/abs/2307.03172): put what matters at the end.
- **Here:** one person's two weeks fit, so no RAG; the day goes last, right before the request.
- **Met in:** agent-reliability §4.3; lunna-as-a-secretary, slide 4 (a 300-row sheet is ~6–10k tokens: the limits are the 4,000-character message and the 12-change plan, not the context).

### Just-in-time context
> Hand out identifiers up front; let tools fetch the details.

- **Read:** Anthropic, [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents).
- **Here:** an index of projects on the board, `read_cards` for what is inside.
- **Met in:** agent-ui §4.6; lunna-as-a-secretary, slide 10 (sources listed by name on the board, `read_source` for the content).

### Progressive disclosure
> Always load the name; load the body only when it is relevant.

- **Read:** Anthropic, [Equipping agents with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills).
- **Here:** the skills in `.claude/skills/`, and the shape of these RFCs (a minute, then the change, then the evidence).
- **Met in:** agent-reliability §4.6.

### Thread memory, entity memory
> A conversation is a thread; a task is a namespace that outlives it.

- **Read:** LangChain, [Memory](https://docs.langchain.com/oss/python/concepts/memory).
- **Here:** talk about a task is found by the task; the notes are written by the person only.
- **Met in:** agent-ui §4.10.

## Shape: who decides what

### Workflow before agent
> If the path is always the same, code walks it, not the model.

- **Read:** Anthropic, [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents).
- **Here:** read the day, propose, reply: hard-coded, one round-trip fewer.
- **Met in:** agent-reliability §4.2; multica-on-the-mac, idea 3 (deeper: a gate in a prompt can be skipped; Multica's workflow leaves "move the card" to the agent; the trial measures whether it does).

### The model arranges, the server states facts
> The model may lay out the answer; only the server writes the facts in it.

- **Read:** [A2UI](https://github.com/google/A2UI) (an agent "generates an A2UI response or uses a pre-generated one").
- **Here:** the model picks blocks and words; hours, lengths and ids come from the dry run.
- **Met in:** agent-ui §4.2 and its Q/A.

### Generated UI where the task is interactive
> Generated UI beats chat for doing things, and loses on simple questions.

- **Read:** Chen et al., [Generative interfaces](https://arxiv.org/html/2508.19227v2) (2025): preferred 84% to 12%, except "how-to" questions.
- **Here:** cards for plans and choices, one caption line for a simple fact.
- **Met in:** agent-ui §4.4.

### Approval on the action
> Approval belongs on the action, not in the prompt.

- **Read:** Microsoft Agent Framework's `approval_mode` ([Chaganti](https://ravichaganti.com/blog/human-in-the-loop-with-function-approvals-in-microsoft-agent-framework/)).
- **Here:** every change is a plan and Aplicar is the yes; the server, not the prompt, says what needs it.
- **Met in:** agent-ui §4.8; agent-full-surface, idea 2 (GateArena: a confirmation bound to the call's exact parameters, harm 37.5–60% → 2.5%).

### Guardrails are not redress
> Preventing harm and undoing it are different properties; build the undo.

- **Read:** Alqithami & Alzahrani, [Agent RedressBench](https://ojs.aaai.org/index.php/AIES/article/view/43130) (AIES 2026).
- **Here:** Desfazer that really brings a deleted task back, before offering delete.
- **Met in:** agent-ui §4.9.

## Measuring and running

### Writes are where agents fail
> Agents fail on the steps that change things, not the ones that read.

- **Read:** [SABER](https://arxiv.org/html/2512.07850v1) (2025): writes are 14–18% of τ-bench steps; each wrong one cuts the odds of success by up to 92–96%, a wrong read by under 10%.
- **Here:** reads stay generous; every new write gesture gets a dry run, refusals and an eval case. Every eval failure recorded so far (`two-matches`, `blocked-by-event`, `from-backlog-today`) was a write; behind Aplicar, a wrong write is a wrong plan the person taps through.
- **Met in:** agent-full-surface, idea 1 (and its Q/A, with the trap of each new verb under *Writes, verb by verb*).

### pass^k: grade the final state
> Grade the final state, k times; right three times in four feels broken.

- **Read:** Yao et al., [τ-bench](https://arxiv.org/abs/2406.12045); Anthropic, [Demystifying evals](https://anthropic.com/engineering/demystifying-evals-for-ai-agents).
- **Here:** `npm run eval:agent`: a starting day, a fixed clock, a request, a check on the day after Aplicar.
- **Met in:** agent-reliability §4.4 and §5.7 (its Q/A explains evals from zero).

### Resume from files, not from context
> A long-running agent picks up from files, never from its memory.

- **Read:** Anthropic, [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).
- **Here:** each queue phase is a fresh `claude -p` that reads the topic folder.
- **Met in:** agent-queue §literature 4; multica-on-the-mac, decision 1 (Multica resumes the issue's session instead).

### One writer per queue
> One queue, one writer: everything else is a screen.

- **Read:** M. Thompson, [Single Writer Principle](https://mechanical-sympathy.blogspot.com/2011/09/single-writer-principle.html).
- **Here:** `queue.mjs` alone starts runs and opens gates. In the trial, Multica gets its own backlog, so each issue still has one writer; the one thing both share is the Claude subscription's weekly limit.
- **Met in:** multica-on-the-mac, idea 1 (first draft: Multica as a screen; revised: two queues, separate backlogs; second revision: the daemon shares the Claude subscription with the queue, so one run at a time).

### Mirror by level, not by edge
> Each pass, compute the whole desired state and fix what differs.

- **Read:** Kubernetes, [Controllers](https://kubernetes.io/docs/concepts/architecture/controller/); the failure case, [multica #1120](https://github.com/multica-ai/multica/issues/1120) (a one-off import drifts).
- **Here:** proposed as a mirror from `.git/queue/` onto Multica's statuses; dropped when the person chose separate backlogs.
- **Met in:** multica-on-the-mac, first draft, idea 2.

### Skip permissions only inside a box
> Skipping permissions is for a container, not your home folder.

- **Read:** Claude Code, [Permission modes](https://code.claude.com/docs/en/permission-modes): `bypassPermissions` for "isolated containers and VMs only".
- **Here:** the queue runs `auto`; Multica's daemon runs `bypassPermissions`, so it runs as a separate `multica` macOS user, with its own `claude` login and a GitHub token for one repo. Multica's own docs: "the boundary is the daemon user".
- **Met in:** multica-on-the-mac, idea 4, then idea 2 (deeper: the dedicated user as the lightest boundary; second revision: one on every machine that runs a daemon; fourth: the Mac only).

### Private network before public port
> Reach it privately before you open a port.

- **Read:** Tailscale, [Serve](https://tailscale.com/kb/1312/serve) (tailnet only; Funnel is the public one).
- **Here:** the phone reaches Multica on the Mac over the tailnet; nothing listens outside it.
- **Met in:** multica-on-the-mac, idea 5; overridden in its second revision (served publicly), see [the login is a shell](#the-login-is-a-shell).

### The login is a shell
> On a public URL, the login is a shell.

- **Read:** Multica, [Security model](https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/security-model.mdx): runs are unsandboxed, "the boundary is the daemon user".
- **Here:** whoever signs in to `multica.pietroteruya.dev` can assign an issue to an agent that runs `claude` with permission checks off on the Mac. So the login gets a shell's care: one allowed email, sign-up off, 6-digit codes that live 10 minutes and die after 5 tries, delivered only to your inbox.
- **Met in:** multica-on-the-mac, idea 4 (second revision).

### Everything dials out
> The tunnel dials out, so no port opens.

- **Read:** Cloudflare, [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/): an outbound-only connector, no inbound port.
- **Here:** the `cloudflared` connector on the Mac opens its own connection to Cloudflare and requests come back down it, so nothing listens on the Mac's network. (The second revision also had more machines' daemons dial in; the fourth kept the Mac only.)
- **Met in:** multica-on-the-mac, idea 5 (second revision; narrowed in the fourth).

## Observability: seeing what happened

### Report at the boundary
> An error you catch is an error nobody sees.

- **Read:** PostHog, [Flutter error tracking](https://posthog.com/docs/error-tracking/installation/flutter): autocapture hooks the global handlers; caught errors need `captureException`.
- **Here:** 26 catch sites turn failures into states; report at the Dio interceptor and `LoggingInterceptor`, which every failure crosses.
- **Met in:** posthog, idea 1 and change 2.

### Count actions on the server
> Count an action where it happens, not where it is drawn.

- **Read:** PostHog, [Product analytics best practices](https://posthog.com/docs/product-analytics/best-practices): backend analytics are more reliable; one id format everywhere.
- **Here:** every write is a server route, so one table of route → event covers three platforms.
- **Met in:** posthog, idea 2.

### Screenshot replay is irreversible
> A Flutter replay is a stack of pictures: mask before you record.

- **Read:** PostHog, [Mobile session replay](https://posthog.com/docs/session-replay/mobile) and [Canvas recording](https://posthog.com/docs/session-replay/canvas-recording).
- **Here:** `maskAllTexts` and `maskAllImages` stay on; titles and notes never leave the phone.
- **Met in:** posthog, idea 3.

### Heatmaps need a DOM
> A heatmap needs a page of elements; Flutter paints one canvas.

- **Read:** PostHog, [Heatmaps](https://posthog.com/docs/toolbar/heatmaps): the clickmap counts DOM elements.
- **Here:** coordinate heatmaps on the web build only; replay taps on the phones.
- **Met in:** posthog, idea 4.

## Cost: what the infrastructure bills

### Scale to zero is your quietest loop
> Scale to zero is a property of your quietest loop, not of your traffic.

- **Read:** [neondatabase/neon#12909](https://github.com/neondatabase/neon/discussions/12909) (a poller every ~4.5 min kept 0.25 CU up all month); Neon, [Compute lifecycle](https://neon.com/docs/introduction/compute-lifecycle): asleep after 5 minutes with no active queries.
- **Here:** `PauseTickerService` queried every minute, and an open web tab refreshes every minute: ~158 CU-hours a month for two people.
- **Met in:** neon-compute, slides 4–6.

### Derive on read, don't poll
> Poll only what you can't compute; derive the rest on read.

- **Read:** Chrome, [Timer throttling in Chrome 88](https://developer.chrome.com/blog/timer-throttling-in-chrome-88): hidden tabs' timers run once a minute; prefer push to polling.
- **Here:** a paused block's end is `now + owed`, so `catchUp` runs before each read instead of on a clock.
- **Met in:** neon-compute, slides 7–8; notification-lifecycle, slides 5 and 7 (overtime dragged on read; the Live Activity changes on state only); lunna-as-a-secretary, slide 9 (a Drive file read on ask, not synced; a WhatsApp webhook would write on every message).

### Settle on access, from absolute times
> Store when something happened; work out the rest from now, when someone asks.

- **Read:** Redis, [EXPIRE: How Redis expires keys](https://redis.io/docs/latest/commands/expire/): "a key is passively expired when a client tries to access it", expiry kept as absolute timestamps so time flows while the server is down.
- **Here:** a paused block's end is `now + owed` and a queued task's hour is `relayout` on read, so no tick and no "last read" watermark. The tick had hidden a `catchUp` bug that only a long gap shows.
- **Met in:** neon-compute, slide 9.

## Interruptions: when to ask

### Ask at the edges
> Defer an interruption to a breakpoint; the coarser the breakpoint, the cheaper.

- **Read:** Iqbal & Bailey, [Understanding and Developing Models for Detecting and Differentiating Breakpoints](https://www.interruptions.net/literature/Iqbal_Bailey-CHI07.pdf) (CHI 2007): ~2, ~4 and ~7 min to the next fine, medium and coarse breakpoint.
- **Here:** the start and end of a block are the coarsest breakpoints a planner knows; re-ask 10 min later; warn 15 min before a fixed block something runs into.
- **Met in:** notification-lifecycle, slide 6.

### The lock screen counts by itself
> A Live Activity can't reach the network, but its timer counts on its own: update it on state, never on the clock.

- **Read:** Apple, [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities): `Text(timerInterval:)`, 4 KB, start in the foreground or from a `LiveActivityIntent`.
- **Here:** the running block's activity is updated on start, pause, ±10, done and overtime; no push server and no minute updates.
- **Met in:** notification-lifecycle, slide 7.

## Sources: what the agent reads from outside

### Ask for the file, not the drive
> Ask for the one file the person picks; a scope over everything costs an audit and their trust.

- **Read:** Google, [Drive API scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth) (`drive.file` non-sensitive, `drive.readonly` restricted) and [the Picker for desktop and mobile](https://developers.google.com/workspace/drive/picker/guides/desktop-mobile-picker) (in the system browser, `drive.file` only).
- **Here:** she pastes a sheet's link, the picker opens on that file (`file_ids`), one tap grants it.
- **Met in:** lunna-as-a-secretary, slides 6–7.

### Rows as key: value blocks
> A small model reads a record better as `key: value` lines than as a CSV row.

- **Read:** Improving Agents, [Which table format do LLMs understand best?](https://www.improvingagents.com/blog/best-input-data-format-for-llms): 60.7% vs 44.3% on 1,000 records (GPT-4.1-nano), at 2.7× the tokens.
- **Here:** `read_source` writes each row as `Coluna: valor`, empty cells dropped.
- **Met in:** lunna-as-a-secretary, slide 4.

### Never hold a session to their account
> Read what the person hands over, or go through the platform's own API; an unofficial session puts their account at risk.

- **Read:** [Baileys](https://github.com/WhiskeySockets/Baileys)' disclaimer ("not affiliated … authorized … by WhatsApp"); WhatsApp, [About unofficial apps](https://faq.whatsapp.com/1217634902127718/); the official road, coexistence ([360dialog](https://docs.360dialog.com/docs/hub/embedded-signup/whatsapp-coexistence)).
- **Here:** a WhatsApp chat reaches Lunna as an export she shares; the whole inbox only through Meta's API, later.
- **Met in:** lunna-as-a-secretary, slides 8–9.
