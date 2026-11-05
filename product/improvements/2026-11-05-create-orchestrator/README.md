# /create as an orchestrator: small pieces, priced in points of the week

2026-11-05. Watching issue #85 on the queue showed that the 2026-11-03 cuts
(thumbnails, read caps) worked but weren't enough: one issue used ~$20.65
of API-equivalent tokens and the whole 5-hour window, 63 of those points in
one 31-minute build. This run turns `/create` into a cheap splitter whose
pieces are separate, self-contained issues, and takes every other lever
the measurements left.

## 1. The request

User messages, verbatim:

> watch consumption of https://github.com/pietroid/lunna/issues/85 closely on the queue. Lets see if the token improvements are effective

> I still think we should cut off more of this. what could be done?

> Yep, lets do all of it as an improvement (so document it properly). I want to highlight the following:
>
> - We can split create and desgin/build into separate skills/issues. Create remains the only template user facing, but design and build can become skills/subagents that are fast, independet, and self contained, for a specific subject. The create skill answers very fast by prioritizing what was asked based on estimated token consumption and estimated impact. It separates between multiple design works if needed, as well the build work, if needed. The idea is to be very fast and to the point. The whole orchestration must be done by this same github issue, if things get denied they are annotated as separate issues and moved to backlog so it isnt already tackled. the orchestrator will basically create github issues for each of design and build, with very short descriptions to user to approve, and if the user goes to completion, they are closed automatically, until the parent is closed automatically. Lets use a metric for token estimation related to number of points (%) of the week estimated to consume. Also lets simplify the design one, doesnt need to have the labels, and the passes can be as little as possible, it should really cost very few. We could have a "step by step" design screens describing what is happening, but you dont need a lot of info because it is already visual and easy to spot.

Answers to the forks:

| Question | Answer |
|----------|--------|
| What happens to an approved mockup's code? | The build branches from it; the mockup's PR closes unmerged, only the build's PR merges |
| Names of the two new skills (a user-level `design` skill exists) | `mockup` + `build` |
| Model and effort per phase | Split by phase: split Sonnet/low, mockup and revise Sonnet/medium, build and fix Opus/high |
| Trim AGENTS.md in this pass? | Now |

## 2. What changed

| Area | Before | After |
|------|--------|-------|
| `/create` | One skill, four phases: design (annotated board or plan), iterate, build, deliver, in one or two long sessions | A splitter: reads the ask, returns pieces (`mockup` or `build`), each with a brief, impact and an estimate in **points of the weekly window**, ordered by impact per point. Does no design or building |
| Design | `/create` Phase 1–2: a board of 3–5 screens with lettered pins, titles, whys, `board.mjs`, ~$3–4 a session | `/mockup`: a **step strip**, 2–5 screens with one numbered line under each, no pins; one build, one look at a thumbnail, one fix pass; budget ~0.5 pt. Runs the tests of any shared widget it changes |
| Build | `/create build` Phase 3–4, explores, writes all docs at the end of a 300k context | `/build`: starts from the brief and the mockup's `path:line` anchors, no exploration; long docs (README §3–5, spec, AGENTS pointer) go to the **`docs` subagent** (Sonnet, fresh context) |
| Queue: `create` issue | design → approve → build → approve → merge, all in one issue | **parent**: one split run (~$0.15), then one **child issue** per piece with its estimate; parent closes when no child is open, with estimate against what was used |
| Queue: answers | approve / anything else | also **"no"** (*não*, *depois*, *backlog*…): the piece leaves its parent for the backlog (labels → `backlog`, not worked; its build follows it; labelling it again revives it). **"approve" on the parent** starts every proposed piece |
| Queue: mockup → build | same branch | an approved mockup closes its issue and PR (unmerged) and keeps its branch; its build starts from that branch once approved |
| Queue: models | `--model sonnet` meant for design, never applied (`phase === 'create:design'` while `phase` was `'design'`) | `RUN` table: model **and effort** per `kind:phase`, applied |
| Queue: session setup | the account's 3 MCP servers, 38 skills, 43 tools on every turn | `LEAN` for create/mockup/build: `--setting-sources project,local --strict-mcp-config --tools` (8 tools) |
| Queue: a run that hits a limit after its output | counted as failed, paused until the reset (#85, resumed by hand) | the first result carrying the structured output wins: finished is finished |
| Queue: rules for every run | thumbnails and read caps only in `/create`'s design steps | in `rules()`: batch, read slices, nothing over ~20k, Edit/Write not edit scripts, `-thumb.png` only |
| `.tool/preview` | strip, board | `--steps <file>`: `steps.png` (2×, a numbered line under each scene) and `steps-thumb.png` (~140 px a scene) |
| `AGENTS.md` | 43.8k characters on every turn of every session | **26.9k**: eight sections moved verbatim to `product/spec/` (new: `timeline.md`, `routines.md`, `notes.md`, `auth.md`; appended: `home.md`, `artifacts.md`, `notifications.md`, `agent.md`), each replaced by a pointer that keeps its rule |
| `.gitignore` | `build/` also ignored `.claude/skills/build/` | `!/.claude/skills/build/`: the skill reaches main, and so the queue's worktrees |
| Docs | | `.tool/README.md` (queue flow, preview, mockup tools), the Create issue template, `.tool/multica-agent.md`, the #85 results (corrected) |

**How a `create` issue runs now:**

```
create issue ─▶ split (/create, Sonnet low, ~$0.15, seconds)
            ─▶ child issues: [mockup] ~0.5 pt, [build] ~2.5 pt after it, …
            ─▶ "approve" on the parent (or per child: approve / no / a note)
mockup ─▶ step strip ─▶ approve ─▶ closed, PR closed, branch kept
build  ─▶ from the mockup's branch ─▶ .tool/check ─▶ approve ─▶ merged, closed
no child open ─▶ parent closed: estimate vs used, per piece
```

## 3. Evidence

**Where #85's money went** (`code/runs.mjs` over `.git/queue/logs/85-*`;
all runs #85–#89 in `data/runs-85-89.md`):

| Run | Turns | Peak context | USD | cache read / write / output | 5 h pts |
|-----|-------|--------------|-----|------------------------------|---------|
| #85 design | 82 | 162k | $4.29 | 44 / 30 / 26 % | +23 |
| #85 build | 212 | 328k | $13.19 | 63 / 19 / 18 % | +63 |
| #87 build | 90 | 199k | $5.16 | 47 / 29 / 23 % | +37 |
| #89 build | 81 | 227k | $5.51 | 42 / 30 / 28 % | +14 |

- **Cost is turns × a context that only grows.** #85's build read only
  ~770k characters of tool output (~190k tokens) yet reached 328k: the rest
  is the base prompt and the agent's own edit scripts, re-read every turn.
  Hence small pieces, the docs subagent, and "Edit/Write, not scripts".
- **Short runs are mostly cache writes** (57–78 % in revises and resumes):
  the 1-hour cache costs 2× input to write. Smaller base context helps
  every new session.
- **Prices** (from the claude-api skill's table): Opus 5.5 $4/$20, Sonnet 5.5
  $2/$10, **cache reads $0.20 on both**.

**Corrections to what this conversation said earlier:**

- *"Sonnet cuts design to a third"*: no. Cache reads cost the same on both
  models; Sonnet saves on writes and output, **~20–30 %** (#85 design
  $4.29 → ~$3.10). The #85 results doc is annotated.
- *"Stripping the queue sessions' setup saves ~25k tokens a turn, ~15 %"*:
  measured, the Opus first turn goes from **38.8k to 32.5k** tokens
  (`--setting-sources project,local --strict-mcp-config --tools …`),
  ~3 % of an issue. AGENTS.md is loaded by the built-in
  `cc-plugin-agents-md` and stays; `--bare` would drop it but needs an
  API key (no subscription). With AGENTS.md trimmed (−16.9k characters,
  ~4k tokens), a lean turn starts near 28k.
- *"1 point ≈ $2.13"*: fitted over 141 queue runs (`code/week-rate.sh`,
  `data/week-rate.txt`), but the weekly window also counts what runs
  meanwhile (interactive sessions), so it reads low. Matching 300 `/usage`
  readings against priced usage gives **a full week ≈ $270, 1 point ≈
  $2.70** (the week ending Nov 1 hit 99 % at $268); that is the rate used.

**The split, for real** (`code/split-dry-run.mjs` on #85's ask, the exact
command the queue runs; `data/split-85.md`): **2 turns, 9 s, $0.15**,
first turn 36k tokens, 4 pieces (3 builds, 1 mockup) totalling ~7 pt;
#85 actually used ~7.6 pt ($20.65 at $2.70). It found that one ask held
four separable changes, and put the audit of #81/#83 first.

## 4. Verified

- ✓ `code/split-dry-run.mjs`: the split runs on Sonnet, low effort, lean
  (10 tools, 26 skills), returns schema-valid pieces; and `denies()` reads
  "no", "Não.", "backlog", "depois" as no, and "no, but change the icon",
  "approve" as not.
- ✓ `code/simulate.sh`: the real `queue.mjs` in a throwaway clone with a
  bare origin and fake `gh`/`claude`/`npm` (`code/sim/`), 13 checks
  (`data/simulate.txt`): split into children; approve-all on the parent;
  the build waits for its mockup; the mockup is accepted (PR closed
  unmerged, issue closed); the build's branch carries the mockup's preview;
  a build run that hits a limit after its output still counts as done;
  merge; the parent closes; on a second parent, "no" on the mockup sends it
  and its build to the backlog and the parent closes.
  - **Bug found and fixed**: a piece sent to the backlog in the same pass
    was revived ("Back in the queue"), because the pass's issue list
    predated the label change. The revive now re-reads the labels.
- ✓ `.tool/preview preview 1 2 --steps …`: built in 19 s, `steps.png` at
  2× (1752×2020) with numbered lines; `steps-thumb.png` 60k characters
  for two scenes (first try was 118k at a fixed 480 px; now ~140 px a
  scene).
- ✓ The base-context measurements above (`claude -p` on Haiku and Opus,
  default vs lean; every variant still saw AGENTS.md).
- ✓ `trim-agents.py`: every heading kept, every relative link in
  `AGENTS.md` and `product/spec/` resolves.
- ✓ `node --check .tool/queue.mjs`, `bash -n` on `preview` and
  `shoot-flutter.sh`; the 2026-10-21 queue test (`verify.mjs`) still
  passes; `.tool/check` ✓ (`app-analyze`).
- ✓ `.claude/skills/build/` was ignored by `build/` in `.gitignore`: found
  by `git status`, fixed.
- **Not verified here**: a real issue through GitHub (the simulation
  covers the logic, not GitHub's API); a real `/mockup` or `/build` session
  with the new skills and the `docs` subagent; whether `--effort` levels
  hold quality. The next `create` issue is the test: compare its parent's
  closing table (estimate vs used) with #85's ~7.6 pt.

## 5. Not done

- The queue's 1-hour cache writes (2× input; the 5-minute cache is 1.25×,
  and turns are seconds apart): no Claude Code flag for it was found.
- Splitting one build into several sessions (server, app, proof) by the
  queue: left to the split, which keeps builds to ≤ 15 files.
- Haiku for the `docs` subagent or for revises: Sonnet first; try Haiku
  once the pieces are measured.
- Calibrating the estimate table from the parents' closing tables after a
  few issues.

## 6. References

Files changed:

- `.claude/skills/create/SKILL.md` (rewritten), `.claude/skills/mockup/SKILL.md`,
  `.claude/skills/build/SKILL.md`, `.claude/agents/docs.md` (new)
- `.tool/queue.mjs`, `.tool/preview`, `.tool/mockup/shoot-flutter.sh`,
  `.tool/README.md`, `.tool/multica-agent.md`, `.github/ISSUE_TEMPLATE/create.md`, `.gitignore`
- `AGENTS.md`; `product/spec/timeline.md`, `routines.md`, `notes.md`,
  `auth.md` (new); `home.md`, `artifacts.md`, `notifications.md`, `agent.md`
- `product/improvements/2026-11-03-cut-design-cost/results-85.md` (corrected)
- Here: `code/runs.mjs`, `code/week-rate.sh`, `code/split-dry-run.mjs`,
  `code/simulate.sh` + `code/sim/`, `code/trim-agents.py` + `code/pointers.json`;
  `data/runs-85-89.md`, `data/week-rate.txt`, `data/split-85.md`, `data/simulate.txt`

Related: [2026-11-03-cut-design-cost](../2026-11-03-cut-design-cost/README.md)
(thumbnails, read caps; its #85 results), [2026-10-21-skill-flow](../2026-10-21-skill-flow/)
(where the design/build split was first measured).

## 7. The first real issue (#91), and the fix

> omg i ask to implement just a few of them, and it just responds by adding more issues facepalm https://github.com/pietroid/lunna/issues/91

> Please consider my first response, and remove the other issues. Also you can push any improvement to main if needed.

The split itself worked (1 turn, $0.14, six pieces, ~10 pt). But the
parent understood only "approve" (start everything) and "no"; any other
reply split it again. "build the first three for now" and "Start with
the first three high impact" each closed the proposed pieces and opened a
new, differently cut set: #92–#97, then #98–#104, then #105–#113.

**Fixed:** a reply on the parent now goes to the split run with the
current pieces listed, and comes back as decisions on them: `start`,
`backlog`, `drop` (only for a piece a new one replaces), and `children`
only for new pieces asked for. Nothing the reply doesn't name changes.
The skill gains "A reply on the parent", requires `after` for a build that
implements a mockup (#95 lacked it), and drops the summary's own total
(it said 11.1 pt where the pieces summed to 10.0).

Verified for real on #91's pieces (`split-dry-run.mjs … pieces.txt
reply`, `data/reply-91.txt`), 2 turns and ~$0.09 each:

| Reply | start | backlog | drop | new |
|-------|-------|---------|------|-----|
| build the first three for now | 92, 93, 94 | | | 0 |
| Start with the first three high impact. | 92, 93, 94 | | | 0 |
| not the calendar one, and also add dark mode to the composer | | 97 | | 1 |

The first try of the third reply started five pieces nobody asked for and
dropped #97 instead of shelving it; the second added no piece for "add
dark mode". Each was a sentence in the skill; the table is the third try.
`simulate.sh` gains the scenario (a reply starts the first piece, the
other stays proposed, no new split): 16 checks pass.

On #91 itself, by hand: #92, #93, #94 reopened and started; #105–#113
closed as not planned.

## 8. Cost and time

This `/improve` run (from the request above): 56 turns, 15.5M tokens in
(15.2M cache read), 86k out, peak context 344k (`.tool/cost b0027a4a`),
about $7–8 API-equivalent priced from those tokens (the usage-bars total
was another session's). The watching of #85 before it, in the same
session: 87 turns, 8.1M in. Wall time ~80 minutes, most of it in
`claude -p` measurements, the preview build and the simulation.
