# Cut design-session cost by ~10×

2026-11-03. Three changes to the `/create` mockup track and the queue runner,
driven by the observation that recent design sessions were burning through
Claude Code's 5-hour window in minutes.

## 1. The request

User messages, verbatim:

> if you see in the logs at main, we consumed the 5 hours limits of claude code session in just less than 20 mins!!! that's a really bad smell.
>
> Also, the skill of design consumes a lot of tokens (3 dollars equivalent), cant we have a 10th of this just to produce mockups after all? And the rest I guess is more about IO and project structure
>
> also, target the build change not just design
>
> if you want to say me a set of recommendations with some graphs statstics etc and then explain to me the intendede changes and their estimated impact
>
> yes

## 2. What changed

| Area | Before | After |
|------|--------|-------|
| Screenshots in design context | Agent read full-resolution `board.png` / `strip.png` / `screenN.png` (~500k chars of base64 each) | `.tool/preview` and `.tool/mockup/board.mjs` generate 240 px-wide `-thumb.png` files; the skill tells the agent to read `board-thumb.png` only |
| Design-phase model | `claude-opus-5-5` for every queue phase | `.tool/queue.mjs` passes `--model sonnet` for `create:design`; build/fix/conflicts stay on `opus` |
| Tool-output discipline | Agent often `cat`ed whole Dart files and re-read them | Skill now caps reads: use `Read(offset/limit)` or `grep`, never re-read a file in the same session, keep any single result under ~20k chars |
| Documentation | `preview` and `create` skill didn't mention thumbnails or caps | `.tool/README.md` and `.claude/skills/create/SKILL.md` document the new conventions |

Files changed:

- `.tool/mockup/shoot-flutter.sh` — generates `<scene>-thumb.png` and `strip-thumb.png`
- `.tool/mockup/board.mjs` — generates `board-thumb.png` and `screenN-thumb.png`
- `.tool/queue.mjs` — `--model sonnet` for `create:design`
- `.claude/skills/create/SKILL.md` — thumbnail-first review, context-budget rules, build hand-off discipline
- `.tool/README.md` — thumbnail and output-cap conventions
- `product/improvements/2026-11-03-cut-design-cost/code/` — the analysis scripts (`analyze-queue.mjs`, `report.mjs`, `queue-cost.mjs`)

## 3. Evidence

Measured from 107 unattended queue logs (`code/analyze-queue.mjs`):

| Phase | Runs | Median wall min | Median turns | Median peak context | Median tokens in | API-eq USD |
|-------|------|-----------------|--------------|---------------------|------------------|------------|
| design | 27 | 9 | 79 | 136k | 7.8M | $6.82 |
| build | 29 | 14 | 144 | 176k | 17.7M | $15.60 |
| revise | 21 | 3 | 29 | 75k | 1.7M | $1.53 |
| fix | 30 | 3 | 33 | 74k | 1.9M | $1.69 |

Worst recent runs:

- **#83 design**: 12.6M tokens in 10 min; 5-hour window **50% → 85%**.
- **#77 build**: 38.6M tokens in 23 min; 5-hour window **28% → 89%**.

Root cause: **screenshots in context**. In #83 design, tool results totalled 2.35M chars; **2.22M (94%)** were image reads. Each PNG is ~300k–560k chars of base64 and stays in context for every turn.

## 4. Verified

- ✓ `node --check .tool/mockup/board.mjs`
- ✓ `node --check .tool/queue.mjs`
- ✓ `bash -n .tool/mockup/shoot-flutter.sh` and `bash -n .tool/preview`
- ✓ `.tool/preview composer 1 2 --out /tmp/lunna-preview-test` built and produced:
  - `1.png` 226k chars base64 → `1-thumb.png` 74k chars
  - `2.png` 187k chars base64 → `2-thumb.png` 66k chars
  - `strip.png` 168k chars base64 → `strip-thumb.png` 44k chars
- ✓ `node .tool/mockup/board.mjs /tmp/test-board.json /tmp/lunna-preview-test/board` produced:
  - `board.png` 495k chars base64 → `board-thumb.png` 44k chars (**11× smaller**)
  - `screen1.png` 288k chars base64 → `screen1-thumb.png` 65k chars
  - `screen2.png` 178k chars base64 → `screen2-thumb.png` 43k chars

## 5. Estimated impact

For a design session like #83 (12.6M tokens in, ~$11):

- **Thumbnails alone**: reading `board-thumb.png` (44k) and `strip-thumb.png` (44k) instead of full screenshots (~500k each) cuts the image portion of context by roughly **10–12×**. Image-related tokens dominate ~60% of the session, so this removes ~$5–6 of API-equivalent spend.
- **Sonnet for design**: mockups are layout + project navigation + image review; Sonnet is 3–5× cheaper than Opus for this work.
- **Smaller reads + no re-reads**: trims the remaining non-image context by ~1.5–2×.

**Combined target:** median design session drops from **~$6.80** to **~$0.80–$1.50**, close to the 10× ask. Build sessions should fall from **~$15.60** to **~$4–$6** once the same output-cap discipline is applied there.

## 6. Not done

- Project widget index (`.tool/index.mjs`): would cut exploration turns further, but left for a follow-up; the three changes above are the cheapest wins.
- Build-phase model switch: kept on `opus` because build engineering still benefits from stronger reasoning; cost reduction comes from hand-off discipline and output caps.
- No real unattended design session has run with these changes yet, so the actual dollars will be measured on the next queued `/create` design.

## 7. References

- Report with charts: `/tmp/queue-cost-report.html` (also generated by `code/report.mjs`)
- Analysis scripts: `code/analyze-queue.mjs`, `code/report.mjs`, `code/queue-cost.mjs`
- Related improvement: `product/improvements/2026-10-21-skill-flow/` (where the design/build split and its cost were first measured)
