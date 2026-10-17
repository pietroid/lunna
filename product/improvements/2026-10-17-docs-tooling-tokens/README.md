# Docs under product/, tools under .tool/, and where the tokens go

2026-10-17. The session that the `/improve` skill was written from. It moved
the repo's documents and tools into one place each, renamed `/feature` to
`/create`, and measured why a feature costs ~20M input tokens.

## 1. The request

1. "let's improve the structure of the repository documentation. we should have everything under product/. Remove the _product folder. move the research and delivery folder to this docs, and just delete the record one. Btw update the skill to be create instead of feature. Update the skills to reflect this decision. Also improve the research tooling, we have a tool to interact with md. I think after the research is done, the tool should open, or we at least should have some sort of command line to open a document that easily. Move the tooling to .tool so that s all the internal tools we will use. create a readme. Propose any improvement that will make my life easier and you to consume less tokens and less time. validate with me anything you have doubt."
   - Answers: move the feature specs out of AGENTS.md; add a permission allowlist; don't commit.
2. "great, if you see there is a lot of tokens in used on "delivery" when you take a look at the product data. Its 10x in against out. How we could optimize that? you can use the /research skill if necessary."
   - Answers: implement `.tool/cost`, `.tool/preview` + `.tool/check`, and the split of `/create` at approval; the build starts with `/clear` then `/create build <slug>`.
3. "ok, one small improvement, research must group the research by folder data code etc how delivery is"
4. "great, one more thing. Isnt there any other strategy like using graphs, etc to make 10x smaller tokens in? Im baffled that much tokens is used."
5. "nope, thats ok, thanks for the explanation. Please wrap this session in a agnostic way for a skill called /improve. Besides research and create, this skill is meant to be run everytime I think something can be improved on the codebase, on the harness. Instruct it to save on improvements writing a small report of what was done and references as well."

## 2. What changed

| Area | Before | After |
|------|--------|-------|
| Docs | `_product/{research,record,tool}`, `delivery/` at the root | `product/{spec,research,delivery,improvements}/`, `product/README.md`; `record/time-system.md` deleted |
| Research layout | `<date>-<slug>.md` + shared `reports/`, `research_notes/` | one folder per topic: `README.md`, `data/`, `code/`, `reports/`, `notes/` |
| Tools | `_product/tool/annotate.mjs`, scripts inside the skill folder | `.tool/`: `doc`, `cost`, `check`, `preview`, `annotate.mjs`, `mockup/`, with `.tool/README.md` |
| Skills | `/feature`, `/research` | `/create` (two sessions, split at approval), `/research` (topic folders, opens the RFC, reads notes), `/improve` (new) |
| AGENTS.md | 30 KB, Agent/Voice/Projects in full | 24 KB; those specs in `product/spec/{agent,projects}.md` behind pointers |
| Harness | no project settings | `.claude/settings.json` allowlists `.tool/*`, flutter/npm checks, read-only git |
| Cost records | `usage-bars` readings at phase edges (tokens froze mid-session in 2 of 3 deliveries) | `.tool/cost`: per-message table from the transcript |

The tools:

```bash
.tool/doc ls | open <words> | notes <words> [--open]   # read and comment on product/ docs
.tool/cost [session] [--usd N] [--list]                 # what a session cost, per message
.tool/check [--all] [--brands lunna]                    # CI's checks on what changed, ✓/✗ per step
.tool/preview <slug> <scenes> [--brands lunna,focus] [--board board.json]
```

## 3. Evidence

From the transcripts in `~/.claude/projects/<repo>/`, with
[`code/anatomy.mjs`](./code/anatomy.mjs) ([`data/anatomy.txt`](./data/anatomy.txt))
and [`code/attribute.mjs`](./code/attribute.mjs)
([`data/attribution.txt`](./data/attribution.txt)).

- **Tokens in ≈ turns × context.** The Projects delivery took 101 turns at
  56k → 322k of context (209k on average): 21.06M in, 134k out (158:1). The
  five feature sessions run 130:1 to 233:1.
- **The build after approval is the expensive part**: 50 turns at up to
  301k, 59% of that session's input. Hence the split.
- **Where the input goes** (Projects session; the first agent session is
  similar): fixed prefix 27%, reading code 34%, the model's own output
  re-read 29% (thinking, text, commands 19%; code written 10%), screenshots
  5%, build and test output 3%.
- **Limits.** The prefix alone (55k × 101 turns) caps any saving at ~3.7x,
  and cache reads are ~60% of the dollars (by the usual price ratios), so
  ~2.5x in dollars at most. A code graph or repo map only touches the
  "reading code" slice: ~10–17%.
- **Corrected on the way:** thinking was 50k tokens, not the ~85k first
  estimated from visible output; the usage record's `thinking_tokens` is
  the figure.

## 4. Verified

- ✓ `.tool/doc`: `ls`; `open` twice on one file reuses one server; a note
  saved through the page's own POST lands under its block; `notes --open`
  tells answered from open questions; a topic's `README.md` wins over a
  newer note beside it.
- ✓ `.tool/cost` on a past session (matches the transcript's own
  `costUSD`, $9.58) and on this one.
- ✓ `.tool/preview preview 1 2 --brands lunna,focus`: both strips, ~30 s.
- ✓ `.tool/check --all`: analyze, 10 package test runs, server eslint, tsc
  and tests, ~35 s.
- Bugs found and fixed: two `flutter build web` at once collide on
  `app/ios/Flutter/ephemeral` (builds now run in turn); `packages/*/lib`
  expanded outside `app/`; a failed build printed no reason.
- Not verified: clicking through the annotate page in a browser; the split
  `/create` flow, which waits for the next feature.

## 5. Not done

- Move "The timeline" section of AGENTS.md (~4 KB) to `product/spec/timeline.md`.
- Commit or remove the four third-party skills (`evaluation`, `advanced-evaluation`, `context-degradation`, `tool-design`), listed in every session.
- Turn off connectors this project doesn't use (Claude Docs, maybe Chrome); measure with `/context` first.
- A fresh subagent for long build steps (the attribution says it is cheaper than carrying the main context; it costs visibility).
- `.tool/map`: an outline of the code (symbols with line numbers), for the ~10–15% that reading code costs.
- `.tool/cost --why`: the attribution above, built into the cost tool.

## 6. References

- Files: `.tool/`, `.claude/skills/{create,research,improve}/SKILL.md`,
  `.claude/settings.json`, `AGENTS.md`, `README.md`, `product/README.md`,
  `product/spec/`, and the memory file `docs-as-md-files.md`.
- Related: `product/delivery/2026-10-16-projects/` and
  `product/delivery/2026-10-16-day-gestures/` (the sessions measured),
  `product/research/2026-10-16-agent-reliability/` (moved to the new layout).
- Named as options, not evaluated here: Aider's repo map
  (https://aider.chat/docs/repomap.html), Serena, an LSP-based symbol MCP
  (https://github.com/oraios/serena).

## 7. Cost and time

From `.tool/cost --usd` with the running total from `mcp__usage-bars__session_cost`.
Includes the talk around the work; wall-clock time includes pauses between messages.

| # | At | Took | Message | Turns | Peak context | In (cache read) | Out (thinking) | USD |
|---|---|---|---|---|---|---|---|---|
| 1 | 14:46 | 4 min | let's improve the structure of the repository d… | 17 | 97k | 1.35M (1.28M) | 19k (5k) | $1.09 |
| 2 | 14:52 | 11 min | great, if you see there is a lot of tokens in u… | 27 | 161k | 3.65M (3.59M) | 37k (14k) | $2.02 |
| 3 | 15:05 | 1 min | ok, one small improvement, research must group … | 4 | 166k | 654k (649k) | 3k (721) | $0.28 |
| 4 | 15:06 | 1 min | great, one more thing. Isnt there any other str… | 2 | 170k | 337k (332k) | 5k (2k) | $0.21 |
| 5 | 15:10 | 1 min | nope, thats ok, thanks for the explanation. Ple… | 1 | 173k | 173k (170k) | 1k (586) | $0.09 |
| | | **24 min** | **Total** | **51** | | **6.16M** (6.02M) | **66k** (23k) | **$3.68** |

Row 5 was read before this report and the skill were written, so their
cost isn't in it. Nothing outside Claude was spent.
