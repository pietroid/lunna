# Results: issue #85, the first queue run after the cost cuts

2026-11-03. Watched live from the queue logs (`.git/queue/logs/85-*.jsonl`).

> **Corrected 2026-11-05** by
> [2026-11-05-create-orchestrator](../2026-11-05-create-orchestrator/README.md),
> which measured: cache reads cost the same on Sonnet and Opus ($0.20/M), so
> Sonnet saves ~20–30 %, not two thirds (§2 below); and dropping the
> account's MCP servers and plugins takes the first turn from 38.8k to
> 32.5k tokens, ~3 % of an issue, not ~15 % (§5).

## Numbers

| Run | Model | Min | Turns | Tokens in | Peak context | Cost (API-eq) | 5 h window |
|-----|-------|-----|-------|-----------|--------------|---------------|------------|
| design | Opus | 15 | 82 | 9.6M | 162k | $4.29 | 6% → 25% |
| revise 1 | Opus | 4 | 32 | 2.5M | 94k | $1.47 | → 33% |
| revise 2 | Opus | 3 | 16 | 0.9M | 66k | $0.76 | → 37% |
| build | Opus | 30 | 209 | 42.8M | 328k | $13.42 | 39% → 100% |
| build (finish) | Opus | 3 | 17 | 1.1M | 69k | $0.71 | extra credit |
| **Total** | | **55** | **356** | **57M** | | **~$20.65** | **the whole window** |

Baseline (107 earlier runs): median design $6.82, revise $1.53, build $15.60.

## What worked

- **Thumbnails.** All 31 images read during design, revise and build were
  thumbnails (~40–90k chars each, against 300–560k before). Images
  stopped being the cost.
- **Read caps.** No tool result over 20k chars except images. A whole
  build read only ~770k chars of tool output.
- **Design got cheaper:** $4.29 against a $6.82 median, without the model change.

## What did not

- **Sonnet never ran.** `.tool/queue.mjs` checked `phase === 'create:design'`,
  but `phase` is `'design'`. Fixed locally
  (`` `${st.kind}:${phase}` === 'create:design' ``), not pushed yet.
- **The build is now the cost.** 209 turns over a context that only grew,
  from 59k to 328k. Tool output was only ~190k tokens of it: the rest is the
  base prompt plus the agent's own edits (python patches, writes) re-read
  every turn. Late turns cost ~300k tokens each.
- **One issue used up the whole 5 h window**, and the build was the most of it (+61 points).
- **The design phase broke tests it never ran.** Its `EventTile` change failed
  5 timeline tests, fixed by the build at its most expensive point.
- **A limit hit after the work was done counted as a failure.** The build had
  already returned its summary; the extra turns that followed hit the limit
  and the queue paused the issue until the reset. It was resumed by hand.
- **The finishing run read two full-size PNGs** (620k chars): the thumbnail
  rule lives in the skill's design steps, not in the rules every run gets.

## Proposed improvements

In order of impact. Estimates are against #85 (~$20.65, the whole 5 h window).

### 1. Build in short sessions

**Problem.** Tokens in ≈ turns × context. The build ran 209 turns while its
context grew to 328k, so its second half cost three times its first.

**Change.** `.tool/queue.mjs` runs the build as a chain of fresh sessions,
each handing over through a file (`product/delivery/<slug>/handoff.md`: done,
next, open failures):

1. server (routes, store, tests);
2. app (widgets, l10n, tests);
3. `.tool/check` + prints + README.

Each starts at ~50k context and stays under ~150k. Alternative with less
plumbing: have the build compact itself between those steps.

**Impact.** Average turn drops from ~200k to ~100k tokens: build **$13 → ~$6**,
window **+61 → ~+30 points**.

### 2. Sonnet for design and revise

**Problem.** The switch to Sonnet never fired (the bug above), and it only
names design.

**Change.** In `.tool/queue.mjs`:
`` ['create:design', 'create:revise'].includes(`${st.kind}:${phase}`) ``. Push it.

**Impact.** ~~Design + revises $6.52 → ~$2~~ Design + revises **$6.52 →
~$4.6** (corrected: cache reads cost the same on both models).

### 3. Design runs the tests of what it touches

**Problem.** Design changed `EventTile` (a shared widget) and never ran its
package's tests. The build found 5 failures at ~300k tokens per turn.

**Change.** In the `/create` skill's design phase: after changing a widget
under `app/packages/<pkg>/`, run `flutter test` in that package (output
filtered to failures) before shooting the prints; keep design's changes to
shared widgets to the minimum the mockup needs.

**Impact.** ~10–15 build turns saved at the most expensive point: **~$2–3**.

### 4. A finished run is finished

**Problem.** The build returned its structured output, then a few more turns
hit the limit; `.tool/queue.mjs` saw the last result (an error) and paused
the issue until the reset. Resumed by hand.

**Change.** In `claude()`, keep the first `result` that carries a valid
`structured_output` and treat the run as ok even if later results are errors.

**Impact.** No dollars, but no hour-long stall and no manual resume.

### 5. Smaller base context, rules for every run

**Problem.** Every turn starts at ~47k tokens (system prompt, AGENTS.md ~15k,
the skill). The thumbnail rule only lives in the skill's design steps, so
the finishing run read two full-size PNGs (620k chars).

**Change.**
- Move the thumbnail rule and the read caps into the queue's
  `--append-system-prompt` (`rules(st)`), so every phase gets them.
- Trim AGENTS.md further into `product/spec/` (it is read on every turn of
  every session); aim for ~8k tokens.

**Impact.** ~7k tokens × ~350 turns ≈ 2.5M tokens per issue: **~$1–2**, and no
stray full-size images.

### Together

| | #85 | Target |
|---|---|---|
| Design + revises | $6.52 | ~$2 |
| Build | $14.13 | ~$5 |
| **Issue** | **~$20.65** | **~$7** |
| 5 h window | 100% | ~35–40% |

### How to check

Run the next `/create` issue with these in place, and compare with this
table using `code/analyze-queue.mjs` on its logs.
