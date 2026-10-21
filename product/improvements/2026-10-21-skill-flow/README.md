# A plan track for /create, and research that flows into a build

2026-10-21. Worked unattended by the Lunna queue for issue
[#6](https://github.com/pietroid/lunna/issues/6). `/create` now picks a
track first: a **mockup** when the feature changes the screen, a one-page
**plan** when there's nothing to draw (Shorebird, CI, a server rule). An
RFC approved on its issue is merged and opens its own `create` issue
(`Implement: …`), which the queue plans and turns into a PR. Nobody has to
write the prompt.

## 1. The request

Issue #6, "Improve flow of skills", verbatim:

> - not all creation requires a heavy amount of design. Imagine if I wanted to implement shorebird it would create nothing about design. Consider that on the skill
>
> - after finishing a research I would like to implement that easily without needing to manually do that. Consider that at the end of the skill, but in a way that if I say approve it gets merged, and then proceeds to create a PR automatically

### Decided unattended

| # | Fork | Chosen | Why |
|---|------|--------|-----|
| 1 | Does a plan-track feature still stop at a gate before building? | **Yes, a "Plan ready" gate**, same as the design gate | One "approve" is cheap. A wrong build of release tooling costs more, and the plan is where the person sees which rollout phases a PR ships |
| 2 | How does an approved RFC become a build? | **A new `create` issue** (`Implement: <RFC title>`), opened by the queue right after the merge | Reuses the existing flow (one issue, one branch, one PR, its gates) and gives the build its own thread. Any other way would need a second branch on the same issue |
| 3 | What the build of an RFC covers | The plan (or board) **names the rollout phases this PR ships**, Phase 0 first | RFC rollouts run to 3+ phases; the plan gate is where scope is agreed |
| 4 | Undecided *Decisions for you* in the RFC | `> **Decision**` notes are binding; **every other decision takes the option marked *(recommended)***, as the queue already does elsewhere | Approving the RFC approves its recommendations |
| 5 | Interactive sessions (not the queue) | "approve" on an RFC = land it (branch, PR, squash merge) and run `.tool/queue implement` | The request says approve means merge, then a PR. The build's worktree starts from main, so the RFC has to be there first |
| 6 | The plan track's session split | **No split**: on approval the same session builds | The split exists to drop ~100k of design context (`create` SKILL); a plan never builds that up |

## 2. What changed

| Area | Before | After |
|------|--------|-------|
| `/create` | Always Phase 1: a preview entry point, `.tool/preview`, a pinned board | **Phase 0 picks the track.** Mockup: as before. Plan: **Phase 1P**, a one-page plan (approach, the vendor docs, decisions, *how it will be proved*) in the delivery README, with no preview and no board. Phase 3 gets a **Tooling** step (secrets, dry runs). Phase 4 proves a feature with no screen by the commands it ran, not by prints |
| `/create` from an RFC | Not covered | **"From an RFC"**: the RFC is the research; read its summary, recommendations, decisions (with notes) and rollout, and don't research again |
| `/research` ending | "Don't commit unless asked"; approve on the issue merged the RFC and stopped | **"Approval: from RFC to build"**: in the queue, approve merges and opens the build issue; in a session, approve lands the RFC and runs `.tool/queue implement`. Every decision needs a *(recommended)* option |
| `.tool/queue` | `create:design` prompt required a board; research merge ended the run | The prompt picks the track (Phase 1P on the plan track); the gate is **📝 Plan ready** when there's no board, **RFC ready** on research; **after a research merge it opens `Implement: …`** (a failure there is reported in the merge comment along with the command to run by hand). New `implement <rfc> [--dry-run]` command. State is found from a worktree too (`git rev-parse --git-common-dir`; `.git` is a file there) |
| Issue templates | Create: "designs it"; Research: "approve to merge the RFC" | Create mentions the plan; Research says approve also queues the build |
| Harness | — | `.tool/queue ls` and `.tool/queue implement` allowed in `.claude/settings.json` |

The new command:

```bash
.tool/queue implement product/research/<topic>/README.md --dry-run   # prints title, label, body
.tool/queue implement product/research/<topic>/README.md             # ✓ <issue URL>; refuses if not on origin/main
```

The flow, for a research issue:

```
research issue ─▶ RFC ─▶ "approve" ─▶ squash into main ─▶ issue closed
     ─▶ new create issue "Implement: <title>" (queue, next pass)
     ─▶ Plan ready (or Design ready) ─▶ "approve" ─▶ build ─▶ "approve" ─▶ merged
```

## 3. Evidence

- **The board was forced on every feature.** The `create:design` prompt
  asked for `img/mockup-board.png` unconditionally (`.tool/queue.mjs:149`
  before), and the skill had no path without `.tool/preview`. The
  Shorebird RFC waiting on #3
  (`product/research/2026-10-20-shorebird-mobile-deploy/`, on its branch)
  recommends a release from the Mac, a `patch` job in `deploy.yml`, a
  patch-or-release rule and server compatibility: nothing to draw. Its P3
  "let the app know a patch is waiting" is the small UI touch the plan
  track covers with one Phase 4 shot.
- **What a design session costs**, for the six deliveries that recorded one
  ([data/design-sessions.md](./data/design-sessions.md), from
  `node code/design-sessions.mjs`): median **17.5 min and $3.33**
  (2.13–8.29), 3.3–16.5M tokens in. For a feature with no screen, all of
  that bought a board of screens that don't change.
- **Research stopped at the merge.** `merge()` closed the issue and set
  `done` (`.tool/queue.mjs:407–414` before); to build an RFC the person had
  to open a new issue and write its prompt by hand.

## 4. Verified

- ✓ `node --check .tool/queue.mjs`.
- ✓ `.tool/queue ls` from this worktree lists #1, #3, #5, #6 (before the
  fix it would have looked for `.git/queue` inside a file).
- ✓ `.tool/queue implement <agent-reliability RFC> --dry-run` printed
  `Implement: A reliable Lunna assistant`, label `create`, and the body.
- ✓ On the Shorebird RFC (copied from #3's branch, then removed): `--dry-run`
  gives `Implement: Instant deploys on the phone with Shorebird`; without it,
  `… is not on origin/main yet: merge the RFC first.`, exit 1, no issue.
- ✓ Bad input: a missing file, no argument, an unknown command each print
  their usage line.
- ✓ `headline()`: create + board → Design ready; create, no board → Plan
  ready; create review → Ready for review; research → RFC ready; improve →
  Ready for review.
- ✓ `.tool/check`: nothing in `app/` or `server/` changed.
- ✗ **A mistake on the way:** a run of `implement` without `--dry-run` on the
  agent-reliability RFC (which *is* on main) opened a real issue,
  [#8](https://github.com/pietroid/lunna/issues/8). I removed its `create`
  label and closed it as not planned within a minute, with a comment saying
  why. The queue was busy with this run and never queued it (no `8.json`).
- **Not verified:** the post-merge path itself (it needs a real approval
  on a research issue) and a real plan-track `/create` session. The first
  real test is #3: once this PR is merged, approving #3 should open
  `Implement: Instant deploys on the phone with Shorebird` and its plan.
  If #3 is approved **before** this is merged, the daemon runs the old
  `queue.mjs`: run `.tool/queue implement product/research/2026-10-20-shorebird-mobile-deploy/README.md`
  after it lands.
- **Conflicts ahead:** PR #7 (issue #5) also edits `.tool/queue.mjs`
  (HEADLINE, the usage line) and rewrites `/research` (RFC shape: *In one
  minute*, *The change*). "From an RFC" and the `implement` body name both
  shapes. Whichever merges second goes through the queue's conflicts run.

## 5. Not done

- Skipping the plan gate for a plan-track build of an approved RFC (a
  `built` field in the queue's output would send it straight to review).
  Declined for now (fork 1).
- Letting "approve" carry a scope ("approve, phase 1 only"): today any
  extra text is feedback for another round.
- A `research → improve` route for RFCs about the harness rather than the
  product: today every RFC becomes a `create` issue.

## 6. References

Files changed:

- `.claude/skills/create/SKILL.md`: Phase 0 (tracks, From an RFC), Phase 1P, Tooling step, Phase 4 without prints, description
- `.claude/skills/research/SKILL.md`: Approval: from RFC to build, description, Delivering
- `.tool/queue.mjs`: track-aware prompts, `headline()`, `implement()`, the follow-up after a research merge, `home` from the git common dir
- `.tool/README.md`, `.github/ISSUE_TEMPLATE/{create,research}.md`, `.claude/settings.json`

Related:

- `product/improvements/2026-10-17-docs-tooling-tokens/`: where the
  design/build session split and its cost came from.
- `product/research/2026-10-17-agent-queue/`: the queue's design.
- `product/improvements/2026-10-21-github-review-and-rfc-shape/` (PR #7):
  the RFC shape this change has to coexist with.

## 7. Cost and time

Measured by the queue: see the pull request.
