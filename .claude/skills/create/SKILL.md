---
description: /create - plan a Lunna/Focus feature request as ONE piece of work, fast - estimate it in % of the WEEKLY window (a day ≈ 14 %, a medium ask ≈ 2 %); over 3 % keep the most impactful slice that fits and open the rest as one backlog issue; pin the scope (the files, classes and routes to touch, the screen it must look like) so the mockup and the build read nothing else; then /mockup (when there is something to see) and /build do it in the same issue. Use for any feature, design proposal, mockup, "prints", "how would X look", a piece of tooling, or an approved RFC from product/research/.
---

# Create: plan one piece

`/create` does no design and no building. It reads the ask and returns
**one plan**: what this issue does, what it costs, and the only files the
next sessions open. A plan costs a few cents; the work costs % of the week.

| Step | Skill | Makes | Ends at |
|------|-------|-------|---------|
| plan | `/create` | estimate, slice, scope map | (no gate: goes straight on) |
| mockup | `/mockup` | a strip of 2–5 screens drawn by the real app | the person approves it |
| build | `/build` | the feature, proved by prints or commands | the person approves the PR, which merges |

All three happen **in one issue, on one branch**. Whatever doesn't fit is
**one** backlog issue, not a tree of pieces.

**Why the slice and the scope.** Cost is turns × a context that only
grows: one 212-turn build used ~5.5 % of the week by itself, while builds
held to one coherent change cost 1.3–1.7 %. And ~60 % of a build's tool
calls were greps looking for where things are
([report](../../../product/improvements/2026-11-06-one-issue-weekly-points/README.md)).
The plan finds them once.

## Points: % of the week

Always the **weekly** window (`/usage`, "Current week"), never the 5-hour
one. A day is ~14 %; a medium ask ~2 %, so about 7 a day.

| Work | % of the week |
|------|---------------|
| mockup, 2–3 screens | 0.5 |
| mockup, 4–5 screens | 0.8 |
| build S: one widget or one route, ≤ 5 files | 1 |
| build M: server and app, ≤ 15 files | 1.5 |
| build L: a new module, package or tab, > 15 files | 3 (alone, it is the slice) |
| each revision round you expect | +0.3 |

A medium ask (mockup + build M) ≈ 2. **The issue does at most 3 %**
(`SLICE_MAX` in `.tool/queue.mjs`).

## The plan

Read the ask and only what the plan needs: `AGENTS.md` is in context.
**No builds, no previews, no whole files**: aim for under 10 turns.

1. **What was asked.** The distinct changes, one line each.
2. **Estimate** the whole ask from the table.
3. **Slice.** At or under 3 %: do it all. Over: keep the changes with the
   most impact per point, in an order that leaves something whole and
   shippable, up to 3 %; things that touch the same widgets stay together.
   The rest is **one** backlog issue (`rest`: a title and its changes, one
   line each, as an ask a later `/create` can plan).
4. **Mockup or not.** A mockup only when there is a layout to approve: a
   new screen, sheet or card, a gesture, a placement. A copy change, a fix
   of something that exists, a server rule, tooling: build alone.
5. **Scope map**, the point of the plan. Run `.tool/map <words>` once
   (the files and what each declares, for the words of the ask), then at
   most a few `grep -n` for the exact spots. Write, one line each:
   - every file to change: `path:line`, the class or route, what changes;
   - **looks like**: the existing screen or widget the change copies
     (its file), so the mockup stays in the app's design;
   - the `product/spec/<feature>.md` to read, if any.

   The mockup and the build open these and nothing else; anything outside
   is read only when a compile error or a test points there.
6. **From an RFC** (an `Implement: …` issue): its Rollout phases are the
   changes, Phase 0 (the measuring) first; a `> **Decision**` note is
   binding, otherwise take the option marked *(recommended)*.

**Unattended** (`LUNNA_QUEUE=1`): return it as `plan` in the structured
output (`ask`, `estimate`, `mockup`, `does`, `scope`, and `rest` only when
sliced); the summary is a sentence on why the slice is cut there. Write
nothing in the tree. The queue opens the backlog issue, posts the plan,
and starts the mockup or the build.

**In a terminal.** Show the plan. On the person's go, either open the
issue (`gh issue create --label create`, the ask as its body) and let the
queue do it, or run `/mockup` and then `/build` here with the plan as
their brief (`/clear` between them), and open the rest as an issue
labelled `backlog`.
