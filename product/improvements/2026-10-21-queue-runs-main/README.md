# The queue runs what is merged, and its PRs are short

**Do this once, on the Mac:** `cd lunna && git pull && .tool/queue setup`.
The queue running now is the stale copy this report is about. It merges
this PR, but it won't run it until `setup` points the LaunchAgent at the
new runner.

## 1. The request

Issue #15, verbatim:

> General improvements to the workflow
>
> - RFCs are not linking to the proper RFC published html (it is not even publishing)
> - RFCs have a lot of content in the PR but it should be just a simple description and the heavy one should be on the html.
> - When approving RFC it just closes the PR but does not proceed with implementation (as it did with posthgo

### Decided unattended

- **Where the queue runs from:** its own worktree of `origin/main`
  (`<worktrees>/.runner`), moved to main's tip after every pass. The other
  option was to fast-forward the main checkout from the daemon, and I
  turned it down because that checkout is the one you work in.
- **PR description:** short for every kind (create, research, improve), not
  only RFCs, so all PRs have one shape. A create PR keeps its board image.
- **PostHog's build issue was not opened.** That would publish an issue the
  queue then builds, which is your call. The command is under "Not done".

## 2. What changed

| Area | Before | After |
|------|--------|-------|
| What the LaunchAgent runs | `lunna/.tool/queue.mjs` in the main checkout: 579 lines, 5 commits behind main, no `implement` and no `reviewUrl` | `<worktrees>/.runner/.tool/queue.mjs`, detached at `origin/main` and moved to its tip after every pass. A changed file restarts it, using the mtime check that was already there |
| PR description | ~20k chars: the summary, then the whole usage table, then the whole README pasted in | ~2k chars: the summary, **📝 Read it as a page** plus a link to the README at that commit, the board (create only), open questions, and the usage folded into a `<details>` |
| The page link on a new PR | Missing from the first body, because `reviewUrl` needs the PR number and the PR didn't have one yet | The PR is created, then edited again with the link |
| Env files for issue worktrees | Copied from `root` | Copied from `cfg.checkout` (the main checkout, recorded by `setup`), since the runner has none |
| `.tool/queue ls` | Issues only | First prints `✓ runner at <sha> (origin/main <sha>)`, or ✗ followed by what to run |
| Docs | `.tool/README.md` and the research skill said "the PR description is the README" | Both say the README is read on the page. `.tool/README.md` also has a new **It runs what is merged** paragraph |

## 3. Evidence

There was one cause behind all three complaints. The LaunchAgent ran the
**main checkout's** `queue.mjs`, and nothing ever pulls that checkout: the
queue merges PRs through the GitHub API. So every change that #5, #6 and
#10 made to the queue was on main but had never run (`data/stale.txt`):

```
<string>/Users/pietro/Documents/pietroid.dev/lunna/.tool/queue.mjs</string>
main checkout: 5daf05d, 5 behind origin/main; queue.mjs 579 lines, 'implement' 0x, 'reviewUrl' 0x
origin/main queue.mjs: 683 lines, 'implement' 10x
```

- **"Not linking / not publishing":** the page **is** published.
  `curl https://pietroteruya.dev/lunna/review.html` returns 200, last
  modified 2026-10-21 15:09, which is the deploy of #7. The stale queue just
  never wrote the link. PRs #11 and #13 have 0 links to `review.html`, and
  #16's only links are inside the RFC's own text, none in the header. This
  run's own system prompt lacks the line-comment rule that #7 added, which
  is more proof the daemon is old.
- **No build after PostHog's approval:** `implement()` is called from
  `merge()` on main, but the daemon that merged #11 (18:30) didn't have it.
  No `Implement: PostHog…` issue exists (`gh issue list --search Implement`).
- **Heavy PRs:** the bodies the stale queue wrote are 17,532 (#11),
  24,184 (#13) and 20,283 (#16) characters. The new body for #16's real
  state is 2,030 (`code/verify.mjs`).

## 4. Verified

`node product/improvements/2026-10-21-queue-runs-main/code/verify.mjs`
imports the real `queue.mjs` (output in `data/verify.txt`):

- ✓ review link for #16: `https://pietroteruya.dev/lunna/review.html?repo=pietroid/lunna&pr=16&path=…`
- ✓ the body links the page
- ✓ body 2030 chars (the old queue wrote 20286 on #16)
- ✓ runner created at origin/main (296705a)
- ✓ runner is detached
- ✓ a second sync moves it back to the tip
- ✓ `isRunner` is false from an issue worktree
- ✓ `.tool/queue ls` prints `✗ no runner: run .tool/queue setup` (correct until you run setup)
- ✓ `.tool/queue implement product/research/2026-10-21-posthog/README.md --dry-run` titles it `Implement: PostHog: users, errors and replays`
- ✓ `node --check .tool/queue.mjs`

**Not verified here:**

- `setup` itself. It reloads the LaunchAgent, which would kill the daemon
  running this session.
- A real pass from the runner.
- The PR body as GitHub renders it.

You'll see all three on the next issue after `setup`.

## 5. Not done

- **PostHog's build.** It still needs its issue:
  `.tool/queue implement product/research/2026-10-21-posthog/README.md`
  (or answer the question on #15).
- **Shorebird (#3/#4).** That PR was closed rather than approved, so no
  build was due.
- **The other RFC (#8).** `Implement: A reliable Lunna assistant` has no
  `create` label, so the queue ignores it.

## 6. References

- `.tool/queue.mjs`: `syncRunner`, `isRunner`, `runnerDir`, `prBody`, `syncPr`, `setup`, `ls`, `loop`
- `.tool/README.md`: the queue section
- `.claude/skills/research/SKILL.md`: Phase 3's first line
- Related: `product/improvements/2026-10-21-github-review-and-rfc-shape/` (#5, which added the page and `implement`; this report is why they never ran)

## 7. Cost and time

Measured by the queue: see the pull request.
