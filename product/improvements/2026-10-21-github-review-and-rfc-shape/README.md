# Review RFCs on GitHub, and RFCs that teach

2026-10-21 · /improve · issue #5, run unattended by the queue

## In one minute

- **To comment on an RFC from the phone, use GitHub's own line comments.**
  The RFC is already the PR description. In the PR's **Files changed**,
  tap a line of the README and comment (`Q:`, `Learn:`, `Decision:`,
  `Note:`). Until now the queue read only plain comments, so a line
  comment never reached the agent. Now it does, with the line it was
  left on, and the agent's answer is posted under your comment.
- **RFCs are shorter, and come in layers:** *In one minute* (under 200
  words), then *Ideas to keep* (3–5 sentences worth remembering, each
  with a source), then *The change*, then the evidence under *Deeper*.
- **Learning carries over from one RFC to the next.** A new file,
  [`product/research/concepts.md`](../../research/concepts.md), lists the
  14 ideas the RFCs so far taught. The next RFC gives a known idea one
  line and goes a level deeper on it.

## 1. The request

> Improve GitHub flow and RFCs
>
> - now that we are using GitHub issues as to communicate with the system, I want to find ways to have the same features working for reading and commenting RFCs.
>
> - preferably using the system from GitHub to tag, comment.
>
> - we could for example upload an artifact online, the only challenge would be to save comments to it
>
> Get the simples path and more effective also considering sometimes I will be on the phone
>
> Also shorten the structure of RFC so it goes straight to the point and make it favor more the learning process of mine (references and sentences that stick for a person learning much of ai engineering). Like progressive disclosure, start small and then when we move on to next topics it's deeper.

### Decided unattended

Each fork below went to the option I recommend. To change one, reply on
the issue.

1. **Where to comment: PR line comments**, *not* a hosted copy (GitHub
   Pages with giscus, a Claude Doc, or `.tool/doc` exposed through a
   tunnel). Line comments need nothing new to host, work in the GitHub
   app, and can be read through the API the queue already calls. A hosted
   copy would have to map each comment back to a line of the file, and
   that mapping is the hard part you pointed out.
2. **Where the answer goes: in both places.** The agent writes the note
   and its answer into the RFC (as `> **Q:**` / `> **A:**`, so
   `.tool/doc notes` and git keep the record), and the queue posts a short
   reply under your comment, which is where you will read it.
3. **What the tags are:** a prefix at the start of the comment (`Q:`,
   `Learn:`, `Decision:`, `Note:`), the same four kinds `.tool/doc` uses.
   I did not use GitHub labels, because a label goes on a whole PR, not
   on a line.
4. **A line comment never counts as approval**, even if it says "ok". To
   approve, comment `approve` alone, on the issue or as the text of a
   review.
5. **Depth comes in order, not hidden.** Each layer is a section further
   down the page, and I did not use `<details>` to fold them. Folded text
   is easy to skip when commenting on lines.
6. **The concepts ledger is one file**, seeded with the 14 ideas from the
   three merged RFCs. The Shorebird RFC (#3) is not merged yet; its next
   round will add its own ideas.
7. **Old RFCs are not rewritten.** They are records of how each argument
   went, and their notes point at their lines.

## 2. What changed

| Area | Before | After |
|---|---|---|
| Queue: what it reads | Comments on the issue and the PR | Also the text of PR reviews, and comments on lines of the PR's files, each with its file, line, the line's text and its thread |
| Queue: answers | Only in the files | The run returns `replies` (thread → answer), and the queue posts each one under your comment |
| Queue: approval | Every comment says `approve` | The same, and no comment on a line |
| Queue: gate comment | "Reply approve … or write what to fix." | "…: here, or on any line of the PR's **Files changed**." |
| `/research` RFC shape | 8 sections: Thesis, How it works today, Diagnosis, Literature, Recommendations, Decisions, Rollout, References | *In one minute*, *Ideas to keep*, *The change*, *Decisions for you*, then *Deeper* (today, diagnosis, literature, rollout) and *References*. Word budgets: under 200 for the first section, under ~2,500 for the whole RFC |
| `/research` learning | None | `product/research/concepts.md`: read it before writing, add to it after; a known idea gets one line plus a level deeper |
| `/research` notes | Only from `.tool/doc open` | Also from GitHub line comments; `Learn` asks to go deeper; "deeper on X" goes under *Deeper*, not into the first section |
| Docs | | `.tool/README.md` (commenting on a line), the Research and Improve issue templates, the layout block in `AGENTS.md` |

### How to review an RFC from the phone

1. Open the PR from the ntfy push and read the description, which is the
   RFC.
2. Go to **Files changed**, tap the line, and choose **Start a review**.
   Add as many comments as you like (`Q: why not X?`,
   `Learn: more real cases`, `Decision: B`).
3. **Submit** the review. Submitted together, they make one round. A
   single comment sent on its own starts a round at the queue's next
   minute.
4. The answers show up under each comment, and the RFC is updated. When
   you're done, reply `approve` alone.

## 3. Evidence

**RFCs are long, and the action comes late.** Measured with
[`code/rfc-shape.mjs`](./code/rfc-shape.mjs) (200 words a minute,
[`data/rfc-shape-before.md`](./data/rfc-shape-before.md)):

| RFC | Words | Minutes | Words before what to do | Minutes |
|---|---|---|---|---|
| agent-reliability | 6,109 | 31 | 1,448 | 7 |
| agent-queue | 3,630 | 18 | 1,659 | 8 |
| agent-ui | 9,406 | 47 | 3,034 | 15 |
| shorebird (PR #4, unmerged) | 2,638 | 13 | 1,352 | 7 |

**The questions ask to learn.** 29 of the 31 notes on the RFCs are `Q`
(`.tool/doc notes <rfc>`). The ones that drive the new shape:
*"I need more real cases on this"* (agent-reliability L113), *"I have no
idea on what you are saying. I want to understand a bit more about
evals"* (L300). Their answers taught by example first, and those are the
answers the new *Ideas to keep* and the ledger are modelled on.

**Line comments were lost.** `answers()` in `.tool/queue.mjs` read only
`issues/<n>/comments`. GitHub keeps PR line comments in
`pulls/<n>/comments` and review text in `pulls/<n>/reviews`, so a
review left on the RFC's lines never started a round. Reading all three on
the real PRs ([`data/review-comments.txt`](./data/review-comments.txt)):
#1 + PR #2, 4 comments (*"Remove mark as done."*, *"Great. Build it"*,
two *"Approve"*); #3 + PR #4, none so far.

## 4. Verified

- ✓ `node --check .tool/queue.mjs`; `.tool/queue ls` and a bad command
  behave as before (the file now runs only as a command, so a test can
  import it).
- ✓ [`code/review-comments.mjs`](./code/review-comments.mjs), 8 checks on
  comments shaped like GitHub's answers: a line comment quotes its line,
  a reply goes to the root of its thread, a two-line comment quotes both,
  a comment on the whole file and an outdated one, the text the prompt
  gets, approval on the issue or a review, a line comment never approving.
- ✓ The same script reads the real endpoints (issue, PR, reviews, line
  comments) on #1/PR #2 and #3/PR #4 through `answers()`.
- ✓ `.tool/doc ls concepts` finds the ledger, and `.tool/check` has
  nothing to run (no app or server change).
- ✗ Not verified: posting a reply under a comment
  (`POST pulls/<pr>/comments/<id>/replies`). It writes to a public PR, so
  the first real review will be the test. The call is `trySh`, so a
  failure loses only the reply, never the round.
- ✗ Not verified: the new RFC shape on a real topic. The next `/research`
  run is the test, and the budgets are in the skill so that run can
  measure itself with `code/rfc-shape.mjs`.
- ✗ Not verified: commenting from the GitHub app on a phone. GitHub
  documents it, but I could not try it here.

## 5. Not done

- Comments sent while a run is working are dropped: the next gate only
  reads comments made after it opens. This was already the case before
  this change. The fix is to read from when the run started.
- "Great. Build it" (#1) was treated as feedback and not as approval,
  because the approval words must stand alone. Allowing an approval word
  followed by a short tail is possible, but a looser rule risks
  approving something by mistake.
- The thread is not marked resolved after it is answered. That needs
  GraphQL (`resolveReviewThread`). It is easy to add if the open threads
  get noisy.
- The three merged RFCs keep their old shape.

## 6. References

- Changed: [`.tool/queue.mjs`](../../../.tool/queue.mjs),
  [`.tool/README.md`](../../../.tool/README.md),
  [`.claude/skills/research/SKILL.md`](../../../.claude/skills/research/SKILL.md),
  [`product/research/concepts.md`](../../research/concepts.md) (new),
  [`.github/ISSUE_TEMPLATE/research.md`](../../../.github/ISSUE_TEMPLATE/research.md),
  [`.github/ISSUE_TEMPLATE/improve.md`](../../../.github/ISSUE_TEMPLATE/improve.md),
  [`AGENTS.md`](../../../AGENTS.md).
- GitHub REST, [Pull request review comments](https://docs.github.com/en/rest/pulls/comments):
  `line`, `start_line`, `original_line`, `diff_hunk`, `in_reply_to_id`,
  `subject_type`, and the `…/replies` endpoint, which takes only a
  top-level comment.
- GitHub REST, [Pull request reviews](https://docs.github.com/en/rest/pulls/reviews):
  a review's `body` and `submitted_at`. You can't approve your own PR,
  which is why approval stays a comment.
- Anthropic, [Equipping agents with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills):
  progressive disclosure, the idea behind the layers.
- Related: [`2026-10-17-docs-tooling-tokens`](../2026-10-17-docs-tooling-tokens/README.md)
  (`.tool/doc` and its notes), and
  [`2026-10-17-agent-queue`](../../research/2026-10-17-agent-queue/README.md)
  (the queue's design).

## 7. Cost and time

Measured by the queue: see the pull request.
