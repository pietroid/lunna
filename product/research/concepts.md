# Concepts: what the RFCs taught

Every idea an RFC put under *Ideas to keep*: the sentence to remember, the
source to read, and where it was met. A new RFC reads this first, gives an
idea already here one line and a link, and goes one level deeper on it
(see `/research`, Phase 3). Newest topics add to the bottom of their group.

RFCs: [agent-reliability](./2026-10-16-agent-reliability/README.md) ·
[agent-queue](./2026-10-17-agent-queue/README.md) ·
[agent-ui](./2026-10-17-agent-ui/README.md) ·
[posthog](./2026-10-21-posthog/README.md) ·
[agent-full-surface](./2026-10-21-agent-full-surface/README.md)

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
- **Met in:** agent-ui §4.7; agent-full-surface, idea 4 (RAG-MCP: >90% under ~30 tools, failure past ~100; Anthropic's tool search only past 10 tools or 10K tokens, so ~35 gesture kinds in one enum need distinct verbs instead).

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
- **Here:** reads stay generous; every new write gesture gets a dry run, refusals and an eval case.
- **Met in:** agent-full-surface, idea 1.

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
