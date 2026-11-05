---
description: /create - turn a feature request for Lunna/Focus into small, self-contained pieces of work, fast - read the ask, split it into mockup and build pieces (a mockup only where there is something to see), each with a two-line brief, its impact and its estimated cost in points of the weekly window, ordered by impact per point; on GitHub the queue opens each piece as a child issue of the request, and /mockup and /build do them. Use for any feature, design proposal, mockup, "prints", "how would X look", a piece of tooling, or an approved RFC from product/research/.
---

# Create: split the ask

`/create` does no design and no building. It reads the ask and returns the
pieces of work, cheaply: **a split costs a few cents, a piece costs points
of the week.** The pieces are done by two self-contained skills, each in a
fresh session that starts from its brief:

| Piece | Skill | Makes | Ends at |
|-------|-------|-------|---------|
| **mockup** | `/mockup` | a step-by-step strip of 2–5 screens drawn by the real app, one line each | the person approves the strip |
| **build** | `/build` | the feature in the server and the app, proved by prints or commands | the person approves the PR, which merges |

**Why split.** One long session re-reads its whole context on every turn,
so its cost grows with the square of its length: #85 ran 212 turns over a
context that grew to 328k and used 63 points of the 5-hour window in one
build ([report](../../../product/improvements/2026-11-05-create-orchestrator/README.md)).
Small pieces start small and stay small.

## How it runs

**On GitHub (the queue).** An issue labelled `create` is the parent. The
queue runs this skill on it (Sonnet, low effort) and opens each piece as a
child issue (`mockup` or `build`) with its brief, impact and estimate,
then lists them on the parent. The person answers on each child, or once
on the parent for all of them:

- **approve** starts it; a build that follows a mockup starts once that
  mockup is approved, from the mockup's branch;
- **no** (or *depois*, *backlog*) moves it out of the parent into the
  backlog: it stays open as its own issue, labelled `backlog`, and nobody
  works it;
- anything else is a note the piece starts with.

An approved mockup closes its child; a merged build closes its child; the
parent closes when no child is left open. Feedback on the parent itself
splits again.

**In a terminal.** Split the same way and show the pieces. On the
person's go, open the parent issue (`gh issue create --label create`, the
ask as its body) and the queue does the rest; or, if they'd rather do it
here, run `/mockup` and then `/build` for each piece in order, `/clear`
between pieces.

## The split

Read the ask and only what the split needs: `AGENTS.md` is in context
(which package owns what), plus at most a few `grep -n` calls to see
whether a widget or route exists. **No builds, no previews, no reading
whole files**: aim for under 10 turns.

1. **What was asked.** List the distinct changes in the ask, one line
   each. A list of fixes in one issue ("part 4") is several pieces.
2. **Group them** into pieces a fresh session can finish alone: one
   flow or one screen per mockup; one coherent change per build, about
   ≤ 15 files. Things that touch the same widgets go together.
3. **Mockup or not.** A piece gets a mockup only when there is a layout
   to approve: a new screen, sheet or card, a gesture, a placement. A
   copy change, a fix of something that exists, a server rule, tooling
   (CI, release, deploy, a migration) is a build alone, whose brief is
   its plan.
4. **Estimate** each piece in **points of the weekly window** (1 point ≈
   $2.70 of API-equivalent tokens; a full week is ~$270):

   | Piece | Points |
   |-------|--------|
   | mockup, 2–3 screens | 0.5 |
   | mockup, 4–5 screens | 1 |
   | build S: one widget or one route, ≤ 5 files | 1 |
   | build M: server and app, ≤ 15 files | 2.5 |
   | build L: more than that | split it |

   Add 0.3 per revision round you expect.
5. **Impact**, high / medium / low: what the person gains, and whether
   later pieces need it. Order the pieces by impact per point; a piece
   that depends on another comes after it.
6. **From an RFC** (an `Implement: …` issue): its Rollout phases are the
   pieces, Phase 0 (the measuring) first; a `> **Decision**` note is
   binding, otherwise take the option marked *(recommended)*.

Each piece has:

- **title**: what changes, in the ask's language, ≤ 60 characters;
- **body**: two to six lines for the session that does it: what to
  change, where (package, widget, route), and the rule that matters. No
  background the session can read in `AGENTS.md`;
- **kind** (`mockup` or `build`), **estimate** (points), **impact**;
- **after**: the piece it starts from (a build after its mockup), if any.

**Unattended** (`LUNNA_QUEUE=1`): return the pieces as `children` in the
structured output, the summary saying the total and what was left out.
Write nothing in the tree. On a reply to an earlier split, return the
whole new list; pieces already started keep going.
