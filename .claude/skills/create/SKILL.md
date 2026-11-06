---
description: /create - grill and plan a Lunna feature request as ONE lean piece of work - first question the ask (the decisions that could make it smaller or lighter, each with a recommended answer, "yes" takes them all), then estimate it in % of the WEEKLY window (a day ≈ 14 %, a medium ask ≈ 2 %); over 3 % keep the most impactful slice and open the rest as one backlog issue; pin the scope (files, classes, routes, the screen it must look like) and what it will NOT do, so the mockup and the build read and write nothing else. Use for any feature, design proposal, mockup, "prints", "how would X look", a piece of tooling, or an approved RFC from product/research/.
---

# Create: grill, then plan one lean piece

`/create` does no design and no building. It questions the ask, then
returns **one plan**: what this issue does, what it leaves out, what it
costs, and the only files the next sessions open. A plan costs a few
cents; the work costs % of the week, so **every token saved is saved
here**, by making the work smaller before it starts.

| Step | Skill | Makes | Ends at |
|------|-------|-------|---------|
| grill | `/create` | the open decisions, each with a recommended (lighter) answer | the person says yes, or answers (skipped when nothing is worth asking) |
| plan | `/create` | estimate, slice, scope map, not doing | (no gate: goes straight on) |
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

## Be lazy

The cheapest change is the one not made. Default to the **least work that
gives the person what they asked for**, and say so in the plan:

- **Reuse before writing**: an existing widget, sheet, route or rule,
  even if it is not quite the shape you would design. A new package,
  table, route or screen only when nothing existing can carry it.
- **App-only when the app can do it**; a server change only when the data
  or a rule has to live there.
- **No mockup** unless there is a new layout to approve. 2 screens over 5.
- **No polish, no edge cases nobody asked for, no refactor on the way**:
  they go in **Not doing**, which the mockup and the build must not add.
- **Tests**: the one spec that proves the rule; not a suite.

## The grill

Before planning, question the ask, like a reviewer who wants it smaller.
Model it as a tree of decisions; the **frontier** is every decision whose
prerequisites are settled. Ask the whole frontier in one round, at most
~5 questions, the ones whose answer **changes the cost or the shape**:

- could it be simpler? ("Reusing `PendingCard` as is, with only the
  minutes added, is enough?")
- could part of it wait? ("The streak chart can go to the backlog?")
- what does the ask leave open that the plan would otherwise guess?

Each question has the answer you **recommend, the lighter one**, and is
worded so **yes accepts it**. Facts are not questions: find them in the
repo (`.tool/map`, a `grep -n`), never ask the person where code is.
Ask nothing only when the ask is small (about 1 % or less) and leaves
nothing open. Anything bigger has a lighter version worth offering:
offer it.

**The plan assumes every recommendation**, so "yes" needs no new run. An
answer re-plans with it, and may open one more round for what depended on
it (at most 2 rounds; then decide the rest with your recommendation).

Format, always in English (the issue is English; only what the app shows is Portuguese):

```
❓ **Q1: <title>**: <question, yes = the recommendation>
➡ <recommended answer>
```

**In a terminal**: ask with AskUserQuestion (recommended option first),
then plan. Don't act on the plan until the answers are in.

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
   line each, as an ask a later `/create` can plan). Sliced means `rest`,
   always: Not doing is for what nobody needs, not for what waits.
4. **Mockup or not.** A mockup only when there is a layout to approve: a
   new screen, sheet or card, a gesture, a placement. A copy change, a fix
   of something that exists, a server rule, tooling: build alone.
5. **Grill** (above): the questions, and the plan written as if each
   recommendation were taken. **Not doing**: what you left out to stay
   light, one line each.
6. **Scope map**, the point of the plan. Run `.tool/map <words>` once
   (the files and what each declares, for the words of the ask), then at
   most a few `grep -n` for the exact spots. Write, one line each:
   - every file to change: `path:line`, the class or route, what changes;
   - **looks like**: the existing screen or widget the change copies
     (its file), so the mockup stays in the app's design;
   - the `product/spec/<feature>.md` to read, if any.

   The mockup and the build open these and nothing else; anything outside
   is read only when a compile error or a test points there.
7. **From an RFC** (an `Implement: …` issue): its Rollout phases are the
   changes, Phase 0 (the measuring) first; a `> **Decision**` note is
   binding, otherwise take the option marked *(recommended)*.

**Unattended** (`LUNNA_QUEUE=1`): return it as `plan` in the structured
output (`questions`, `ask`, `estimate`, `mockup`, `does`, `notDoing`,
`scope`, and `rest` only when sliced); the summary is a sentence on why
it is cut there. Write nothing in the tree. With questions, the queue
posts them and waits; on "yes" (or with none) it opens the backlog
issue, posts the plan and starts the mockup or the build. When the prompt
carries the person's answers, plan with them and ask only what they
opened.

**In a terminal.** Show the plan. On the person's go, either open the
issue (`gh issue create --label create`, the ask as its body) and let the
queue do it, or run `/mockup` and then `/build` here with the plan as
their brief (`/clear` between them), and open the rest as an issue
labelled `backlog`.
