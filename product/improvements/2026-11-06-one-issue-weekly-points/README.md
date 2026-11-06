# One issue, priced in % of the week, with its scope planned first

2026-11-06. The 2026-11-05 orchestrator split each `create` issue into a
tree of child issues. In use it was more to follow, not less. This run brings it back to **one
issue**. A cheap plan estimates the ask in **% of the weekly window**. It
keeps the most impactful slice up to 3 % and sends the rest to one backlog
issue. It also pins the **scope** (the files to touch, the screen to look
like), so the mockup and the build stop searching for them.

## 1. The request

> not very happy with the current way of creating issues. I thought it was gonna simplify but just complicated. Lets stick to just one issue. I think what we can do is the following: have an estimate of cost/time (this part the skill does still), and based on the ask, if it is above a certain threshold (TBD), it will take the most impactful stuff of the ask, and then proceed with the mockup and build in the same issue. The rest will be left to another issue in the backlog. If its below a certain threshold, it will be done anyway.
>
> Now, about time and consumption: I didnt like the fact that it used pts, I think it used the pts per 5h window which is different from the weekly. I want explicit weekly. Daily pts consumption would be around 14%, I think a good sized medium task (which is avg one), would need to consume around 2 pts, so with that we could deliver 7 medium sized things per day. In terms of time, I dont think it factors much and is correlated to pts
>
> Also consider any optimization on the repo we can do in terms of structure to accomodate that, usage of vgv plugins (there is a new version out today), the principle is that as less surface contact that we have the better, so there could be a part of the skill that plans the domains folders classes etc to be changed beforehand so the agent just focus on this instead of searching every place.
>
> About mockup: I liked that, it consumes much less tokens, but also is less consistent with the existing design, take that in account (to consider consistency with current app ui)

Decided without asking (the user can change them):

| Fork | Taken |
|------|-------|
| The threshold ("TBD") | **3 % of the week** (`SLICE_MAX`): one and a half medium asks, ~a fifth of a day. Builds held under it cost 1.3–1.7 %; the one that ran away (#85) cost ~5.5 % |
| A gate after the plan? | **No.** The plan is posted and the mockup (or the build) starts at once, as asked ("then proceed") |
| Install the VGV plugin? | **No** (see Evidence). One idea taken from it, a check that runs without adding anything to context |

## 2. What changed

| Area | Before | After |
|------|--------|-------|
| `create` issue | parent → split → one child issue per piece (`mockup`, `build`), each approved, parent closed when no child is open | **one issue**: `plan` → mockup (if there's something to see) → approve → build on the same branch → approve → merge |
| Too big an ask | more child issues | the most impactful slice up to **3 %**; the rest is **one** issue labelled `backlog` (label it `create` to plan it later) |
| `/create` | a splitter returning pieces with points | a planner returning `plan`: `ask`, `estimate`, `mockup`, `does`, **`scope`**, `rest` |
| Units | "pt": $2.70 per point, plus "week +N pts" summed per run, plus a 5-hour column | **"% of the week"** everywhere: the issue's own tokens at **$2.40 per 1 %** (measured), beside the account's `/usage week a→b%` read before the first run and after the last. The 5-hour column is gone |
| Scope | the build searched (~60 % of its calls were greps) | the plan writes a **scope map** (`path:line`, class or route, what changes, the looks-like widget, the spec). The mockup and the build read only that |
| `.tool/map` | | **new**: each source file and what it declares (Dart classes, Nest routes, TS exports), filtered by words, in one call (~5k characters for three words, 23k for all) |
| `/mockup` consistency | real widgets, but drawn in a scaffold of its own | drawn **inside the real screen** (`DemoApp` or the real page on fakes), copying the plan's looks-like widget, tokens only. Scene 1 may be today's screen. `.tool/preview` prints `⚠ off-token file:line` for literal colours, font sizes, paddings, radii and `TextStyle(` the branch added |
| `/build` | "don't explore", budget in points | the scope is the reading list (outside it only when a compile error or a test points there); budget in % of the week |
| Queue labels | `create`, `mockup`, `build`, `research`, `improve` | `create`, `research`, `improve` (+ `backlog`) |
| Queue code | 1067 lines | 987 lines: `split`, `finish`, `accept`, `pieceList` and the `after`/`base` chaining are gone. `planned` posts the plan and opens the rest. The server's packages are installed on the first phase that needs them |
| Docs | | `.tool/README.md` (queue flow, `map`, the off-token check), the Create issue template, `.tool/multica-agent.md`, `AGENTS.md` (`map` in the layout), memory (`weekly-points`, `plan-limit-size`) |

**How a `create` issue runs now:**

```
create issue ─▶ plan (/create, Sonnet low, ~$0.15, ~20 s)
            ─▶ 📐 comment: ~X % of the week, what it does, the scope
               (over 3 %: the slice, and the rest opened as #M, backlog)
            ─▶ mockup (if any) ─▶ 🎨 approve / no (backlog) / what to change
            ─▶ build on the same branch ─▶ .tool/check ─▶ ✅ approve
            ─▶ merged, "planned ~X %, used ~Y %"
```

The open `create` issues from before the split (#63 and #75 at the mockup
gate, #81 and #83 paused) keep working: their gate is `design`, whose
approval now goes to `build` on the same branch, as it did then.

## 3. Evidence

**The "pts" that looked like the 5-hour window.** #91's closing comment
said "2.9 pt used" and "week +8 pts". Both were misleading
(`.git/queue/issues/9[1-5].json`):

- **"+8" summed each run's own before/after.** #92 and #93 ran side by
  side (21:12–21:31), and each counted the same 67→70 % (+3 twice). The
  account went from 67 % to 72 % over the issue.
- **"pt" was a conversion of priced tokens**, not a reading. Beside a
  5-hour column that moved 36→74 % in one run, it read like that window.

So every figure now says "% of the week". Per issue it is one number from
its own tokens, and beside it the one weekly reading the account showed.

**The calibration** (`code/calibrate.mjs`, `data/calibrate.txt`):

| Runs | $ API-eq | /usage week | $ per 1 % |
|------|----------|-------------|-----------|
| all 158 | 367 | +172 | 2.14 (runs side by side counted twice: low) |
| 74 over $1 with nothing alongside | 263 | +110 | **2.39** |

**Correction:** mid-session I told the user that $2.70 was ~2.5× too high.
That was wrong. It came from #91's summed "+8". The clean figure, $2.39,
is ~12 % under $2.70, the 2026-11-05 fit over the whole account. Kept:
**$2.40**.

At $2.40, the user's numbers hold: #92–#95's builds cost 1.3–1.7 %, the
mockup with three revisions 0.55 %. So a medium ask (mockup + build) is
~2 %, and 14 % a day is ~7 of them.

**Where builds spend their calls** (`code/surface.mjs`, `data/surface.txt`):

| Run | Tool calls | Bash | of which searching | Files read, never edited | Files edited |
|-----|-----------|------|--------------------|--------------------------|--------------|
| #92 build | 81 | 68 | 52 | 5 | 2 |
| #93 build | 75 | 52 | 40 | 3 | 7 |
| #95 build | 54 | 38 | 23 | 4 | 4 |
| #94 mockup | 37 | 33 | 23 | 1 | 1 |

About half to two-thirds of each run's calls were `grep`/`sed -n`/`ls`
finding where things are. Each one adds its result to a context every
later turn re-reads. The plan now finds them once, in a ~$0.15 Sonnet
session, with `.tool/map`.

**The VGV plugin, 0.1.0 (released today).** It brings 15 skills, a
`flutter-reviewer` agent, two MCP servers (`dart`, `very-good-cli`), a
SessionStart hook that syncs VGE standards over the network, and
PostToolUse hooks that run `dart analyze` and `dart format` on every
edited `.dart` file. Against "less contact surface":

- the skills' descriptions and the two servers' tool schemas would sit in
  every turn, and its skills say to "Read the matching VGE Standards file
  before writing code", which means more reads;
- `analyze.sh` prints the analyzer's whole output into context on any
  issue, after every edit, at up to 30 s each;
- the queue runs with `--setting-sources project,local
  --strict-mcp-config`, so a user-scoped install wouldn't reach it anyway.

Taken from it: the idea of a cheap deterministic check. It became the
off-token check in `.tool/preview`, which prints nothing when the code is
clean. Not taken: the format hook. #92–#95's builds formatted by hand only
2–6 times (`grep -c "dart format"` over their logs).

## 4. Verified

- ✓ `node --check` on `queue.mjs` and `map.mjs`.
- ✓ `prompt()` for `plan`, `design`, `build` (with and without a mockup),
  and `usageLine`/`usageTable` on #95's real runs: "~1.7% of the week ·
  … · /usage week 72→77%".
- ✓ **Two real plan runs**, the queue's own args (schema, rules, LEAN,
  Sonnet low; `data/plan-run*.json`):
  - a 5-change app ask: **6 turns, $0.16, 18 s**, 2.6 %, not sliced, a
    scope of 7 `path:line` entries plus a looks-like and specs;
  - a habits feature: **6 turns, $0.13, 24 s**, ask 5 %, slice 3 % (tab,
    CRUD, check-off on Plano, streak chart), the rest "Hábitos: lembretes
    e agente" ~2 %, its scope naming `routines/` and `packages/cycle/` as
    the shapes to copy.
- ✓ `.tool/queue ls` over the 50 stored issues prints the new line.
- ✓ `.tool/map task card pendentes` (38 files, 5.4k chars); `.tool/map`
  (23k); a word that matches nothing says so.
- ✓ `.tool/preview` end to end (worktree at `e8e1a98`, 34 s build): it
  shot the scene and printed `⚠ off-token app/lib/preview.dart:31: final
  _probe = EdgeInsets.all(13);` for a planted line. On the last 30
  commits it flags 4 real lines (an `AnimatedDefaultTextStyle` false hit
  was fixed).
- **Found on the way:** `main` doesn't build. `app_pt.arb` declares
  `confirmDeleteTaskBody` twice (lines 104 and 133; #114 and #117 each
  added one), so `flutter build web` fails with "already declared".
  **Fixed** on the user's ask: kept #117's line (the newer copy, with its
  description), removed #114's, regenerated l10n. `.tool/check` ✓ and
  `flutter build web` ✓.
- ✗ Not verified: a full queue pass on GitHub (plan comment, backlog
  issue, mockup → build). It runs when this lands on main and the runner
  picks it up.

## 5. Not done

- **A plan gate.** The plan comment carries the estimate. If the person
  wants to say no before the mockup, a `plan` gate is one line in `GATE`.
- **The threshold is a guess** at 3 %. After ~10 issues, compare "planned"
  with "used" in the merge comments and move `SLICE_MAX` or the table.
- **Sonnet low under-estimated a large slice**: a new module plus a new
  package at exactly 3 %. A "build L … 3" row was added to the table.
  Watch it.
- **A token lint in `.tool/check`.** It would catch off-token code in
  builds too. The 16 + 17 existing offenders would need fixing first.

## 6. References

Files: `.claude/skills/create/SKILL.md`, `.claude/skills/mockup/SKILL.md`,
`.claude/skills/build/SKILL.md`, `.tool/queue.mjs`, `.tool/map`,
`.tool/map.mjs`, `.tool/preview`, `.tool/README.md`,
`.tool/multica-agent.md`, `.github/ISSUE_TEMPLATE/create.md`,
`.claude/settings.json`, `AGENTS.md`.

- [vgv-ai-flutter-plugin 0.1.0 changelog](https://github.com/VeryGoodOpenSource/vgv-ai-flutter-plugin/blob/main/CHANGELOG.md): what the release adds (skills, hooks, MCP servers, the VGE standards sync).
- `product/improvements/2026-11-05-create-orchestrator/`: the flow this replaces, and the $2.70 fit.
- `product/improvements/2026-11-03-cut-design-cost/`: the earlier cuts (thumbnails, read caps).

## Addendum: the grill, a lazier /create, and four skills removed

> ok a bit more changes: remove any skills not used in this repo and infuse the same idea around grill me https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md to the create skill. So before planning everything, the agent will try to question everything, but most importantly anything that makes the task simpler and lighter, so we also can push the create skill to be a bit "lazy" to consume less tokens possible in the design and build part.

| Area | Before | After |
|------|--------|-------|
| Skills | 9 in `.claude/skills/` | **5**: `advanced-evaluation`, `context-degradation`, `evaluation`, `tool-design` removed (~264 KB, generic, their descriptions in every session). One load in 132 transcripts and every queue log (`tool-design`, research run #20) |
| `/create` | plan straight away | **grill first**, after Matt Pocock's *grilling*: the frontier of open decisions in one round, ≤ ~5, each with a recommended answer **that is the lighter one**, worded so "yes" takes it; facts come from the repo, never the person; at most 2 rounds |
| Laziness | | a **Be lazy** section (reuse before writing, app-only when possible, no mockup without a new layout, 2 screens over 5, no polish/edge cases/refactors, one spec per rule) and a **Not doing** list in the plan, binding on `/mockup` and `/build` |
| Queue | plan → mockup | plan run returns `questions` + the plan **as if every recommendation were taken** → `grill` gate: **"yes" goes on with that plan, no new run**; answers re-plan (~$0.15) with them; "no" sends to the backlog. `yes`/`y`/`s` now count as approval |
| Sliced, no `rest` | (would lose the rest) | the queue opens the backlog issue from Not doing |

**Verified** (the habits ask, the queue's args, Sonnet low; `data/plan-run-grill.json` is the last):

| Run | Turns | $ | Questions | `rest` | Language |
|-----|-------|---|-----------|--------|----------|
| 1 | 4 | 0.17 | 4, each lighter (no custom weekdays, no hour yet, no chart package, out of the timeline) | ✗ missing | ✗ English |
| 2 (rules for rest and language) | 3 | 0.15 | ✗ none ("an empty grill is the best grill" read too strongly) | ✓ | pt-BR (then the rule) |
| 3 (ask nothing only when ≤ ~1 % and clear) | 3 | 0.11 | 4, each lighter (a strip with the streak and 7 squares instead of a chart) | ✗ missing: covered by the queue's fallback | pt-BR (then the rule) |

✓ `prompt()` for a second round (carries the questions and the answers),
the last round (questions must be empty), and a build carrying *Not
doing* and *Decided with the person*. ✗ Not verified: the `grill` gate on
GitHub (posting, "yes", answers): it runs when this reaches main.

**Language:** the user corrected it mid-run: the conversation on an issue (questions, plan, backlog issue) is **always English**; only what the app shows is Portuguese. The prompt, the schema and the skill now say English; runs 2–3 above followed the earlier "language of the issue" rule.

**Not done:** the model still drops `rest` about half the time; the
fallback covers it, but if backlog titles read badly, make `rest`
required by the schema when sliced (a check in `planned` that re-asks).

## 7. Cost and time

This session: ~25 minutes, **~$4.4 API-eq ≈ 1.8 % of the week**
(`mcp__usage-bars__session_cost`), including the two plan runs ($0.29) and
one web build.
