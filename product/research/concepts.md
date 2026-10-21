# Concepts: what the RFCs taught

Every idea an RFC put under *Ideas to keep*: the sentence to remember, the
source to read, and where it was met. A new RFC reads this first, gives an
idea already here one line and a link, and goes one level deeper on it
(see `/research`, Phase 3). Newest topics add to the bottom of their group.

RFCs: [agent-reliability](./2026-10-16-agent-reliability/README.md) ·
[agent-queue](./2026-10-17-agent-queue/README.md) ·
[agent-ui](./2026-10-17-agent-ui/README.md) ·
[posthog](./2026-10-21-posthog/README.md) ·
[agent-console](./2026-10-21-agent-console/README.md)

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
- **Met in:** agent-ui §4.7.

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
- **Met in:** agent-reliability §4.3.

### Just-in-time context
> Hand out identifiers up front; let tools fetch the details.

- **Read:** Anthropic, [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents).
- **Here:** an index of projects on the board, `read_cards` for what is inside.
- **Met in:** agent-ui §4.6.

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
- **Met in:** agent-reliability §4.2.

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
- **Met in:** agent-ui §4.8; agent-console idea 4 (GitHub forbids author approval, so the queue's "approve" is a regex over a comment, and a button that posts the exact word makes it one action).

### Guardrails are not redress
> Preventing harm and undoing it are different properties; build the undo.

- **Read:** Alqithami & Alzahrani, [Agent RedressBench](https://ojs.aaai.org/index.php/AIES/article/view/43130) (AIES 2026).
- **Here:** Desfazer that really brings a deleted task back, before offering delete.
- **Met in:** agent-ui §4.9.

## Measuring and running

### pass^k: grade the final state
> Grade the final state, k times; right three times in four feels broken.

- **Read:** Yao et al., [τ-bench](https://arxiv.org/abs/2406.12045); Anthropic, [Demystifying evals](https://anthropic.com/engineering/demystifying-evals-for-ai-agents).
- **Here:** `npm run eval:agent`: a starting day, a fixed clock, a request, a check on the day after Aplicar.
- **Met in:** agent-reliability §4.4 and §5.7 (its Q/A explains evals from zero).

### Resume from files, not from context
> A long-running agent picks up from files, never from its memory.

- **Read:** Anthropic, [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).
- **Here:** each queue phase is a fresh `claude -p` that reads the topic folder.
- **Met in:** agent-queue §literature 4.

### Acknowledge in seconds
> Acknowledge in seconds, even when the work takes an hour.

- **Read:** Nielsen, [Response times: the 3 important limits](https://www.nngroup.com/articles/response-times-3-important-limits/): 10 s holds attention; past it, say when it will be done.
- **Here:** the queue read comments only between runs (median 69 s, max 54 min); a listener apart from the worker puts 👀 and the status up within 10 s.
- **Met in:** agent-console idea 1.

### A 304 is free
> Poll often, but poll conditionally; prefer being pushed.

- **Read:** GitHub, [REST API best practices](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api): webhooks first; a conditional request answered `304` doesn't count against the rate limit.
- **Here:** three repo-wide `since=` calls with `If-None-Match` every 10 s replace a per-issue sweep every 60 s.
- **Met in:** agent-console idea 2.

### Own the gates, rent the screens
> Write the part only you have; let others maintain the screens.

- **Read:** the failure case, Vibe Kanban's [README](https://raw.githubusercontent.com/BloopAI/vibe-kanban/HEAD/README.md): "Vibe Kanban is sunsetting".
- **Here:** gates, budget and run rules stay in `.tool/queue`; the screens are the GitHub app, a static Pages page and the Claude app.
- **Met in:** agent-console idea 3; round 2 added a second failure case, OpenClaw's one-click gateway token theft ([CVE-2026-25253](https://www.runzero.com/blog/openclaw/)), fixed only on installs someone updated by hand.

### The harness that holds the login holds the bill
> Only Claude Code itself runs on the subscription; any other manager pays per token.

- **Read:** Claude Code, [Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance): subscription OAuth supports "ordinary use of Claude Code and other native Anthropic applications"; other products use API keys.
- **Here:** the queue shells out to the unmodified `claude -p`, so it stays on the plan; Hermes or OpenClaw would add their own dispatcher model on a per-token key in front of the same command.
- **Met in:** agent-console idea 5.

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
