# The queue runs what is merged, and its PRs are short

**Nothing to do on the Mac.** The queue moves itself onto the new runner
once this PR merges: a one-off launchd job is already waiting for it. After
that, every merge to main reaches the queue by itself, so you never run
`setup` again (see "It moves itself", below).

## 1. The request

Issue #15, verbatim:

> General improvements to the workflow
>
> - RFCs are not linking to the proper RFC published html (it is not even publishing)
> - RFCs have a lot of content in the PR but it should be just a simple description and the heavy one should be on the html.
> - When approving RFC it just closes the PR but does not proceed with implementation (as it did with posthgo

Reply to the first version of this report, which asked for `.tool/queue
setup` by hand:

> Why Do this once, on the Mac: cd lunna && git pull && .tool/queue setup.
> The queue running now is the stale copy this report is about. It merges
> this PR, but it won't run it until setup points the LaunchAgent at the
> new runner.
>
> Cant the job do by itself? Everytime I update somehting here I need to do this?

No, and no. Once is the most it ever needed, because from the runner every
merge reaches the queue by itself. This round makes the one time automatic
too.

### Decided unattended

- **Where the queue runs from:** its own worktree of `origin/main`
  (`<worktrees>/.runner`), moved to main's tip after every pass. The other
  option was to fast-forward the main checkout from the daemon, and I
  turned it down because that checkout is the one you work in.
- **PR description:** short for every kind (create, research, improve), not
  only RFCs, so all PRs have one shape. A create PR keeps its board image.
- **The handover was started for real** on this Mac (`.tool/queue adopt`),
  so the move needs no one. It does nothing until this PR is on main.
- **PostHog's build issue was not opened.** That would publish an issue the
  queue then builds, which is your call. The command is under "Not done".

## 2. What changed

| Area | Before | After |
|------|--------|-------|
| What the LaunchAgent runs | `lunna/.tool/queue.mjs` in the main checkout: 579 lines, 5 commits behind main, no `implement` and no `reviewUrl` | `<worktrees>/.runner/.tool/queue.mjs`, detached at `origin/main` and moved to its tip after every pass. A changed file restarts it, using the mtime check that was already there |
| PR description | ~20k chars: the summary, then the whole usage table, then the whole README pasted in | ~2k chars: the summary, **📝 Read it as a page** plus a link to the README at that commit, the board (create only), open questions, and the usage folded into a `<details>` |
| The page link on a new PR | Missing from the first body, because `reviewUrl` needs the PR number and the PR didn't have one yet | The PR is created, then edited again with the link |
| Moving onto the runner | `.tool/queue setup` by hand on the Mac | `adopt` loads a one-off launchd job that waits for main to have the runner, then moves the LaunchAgent and unloads itself. Started here already, and by any queue that starts outside the runner |
| Env files for issue worktrees | Copied from `root` | Copied from the main checkout, found from `.git/queue`, since the runner has none |
| `.tool/queue ls` | Issues only | First prints `✓ runner at <sha> (origin/main <sha>)`, `… handover waiting`, or ✗ followed by what to run |
| Docs | `.tool/README.md` and the research skill said "the PR description is the README" | Both say the README is read on the page. `.tool/README.md` also has **It runs what is merged** and **It moves onto the runner by itself** |

### It moves itself

1. `.tool/queue adopt` (run by this session, and by any `queue.mjs` that
   starts outside the runner) copies itself to `.git/queue/handover.mjs`,
   since this worktree is deleted when the PR merges, and loads it as its
   own launchd job, `dev.pietroid.lunna-queue-handover`. It has to be its
   own job: launchd kills whatever a job leaves behind when it exits, so a
   child of the old queue would die with it. That is what killed the first
   try.
2. The job checks `origin/main` every 2 minutes. Once main has the
   handover, it brings the runner to main and hands off to main's copy.
3. It writes the lock, so the copy launchd restarts exits at once, and
   touches the old script. The old queue then finishes its pass (no run is
   cut off) and exits on its own mtime check.
4. It rewrites the LaunchAgent onto the runner, keeping its node and PATH,
   reloads it, sends a push ("Lunna queue moved to its runner") and
   unloads itself. The log is `.git/queue/handover.log`.

From then on, the runner moves to main after every pass, and a changed
`queue.mjs` restarts it.

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
- ✓ body 2731 chars (the old queue has since written 26847 on #16)
- ✓ runner created at origin/main (296705a)
- ✓ runner is detached
- ✓ a second sync moves it back to the tip
- ✓ `isRunner` is false from an issue worktree
- ✓ `.tool/queue ls` prints `… handover waiting to move the LaunchAgent onto …/.runner`
- ✓ `.tool/queue implement product/research/2026-10-21-posthog/README.md --dry-run` titles it `Implement: PostHog: users, errors and replays`
- ✓ `node --check .tool/queue.mjs`

**The handover, end to end** (`bash product/improvements/2026-10-21-queue-runs-main/code/handover-test.sh`,
about 4 minutes, output in `data/handover.txt`). It sets up a throwaway
LaunchAgent that runs the stale `queue.mjs` (5daf05d, the same one the real
LaunchAgent runs) from a checkout behind its own bare origin. It runs `adopt`
from an issue worktree before the merge, then pushes the PR to that
origin's main:

- ✓ one handover job, its own launchd job (a second `adopt` starts nothing)
- ✓ handed over 178 s after the merge, without cutting off the stale pass
- ✓ the stale pid is gone, and launchd runs `<worktrees>/.runner/.tool/queue.mjs`
- ✓ the runner is at origin's main, and the new daemon is alive
- ✓ the handover job unloaded itself and its plist is gone
- ✓ the checkout was not touched
- ✓ `ls` from the runner: `✓ runner at 73a8017 (origin/main 73a8017)`

**For real, on this Mac:** `.tool/queue adopt` loaded
`dev.pietroid.lunna-queue-handover` (state running). Its log says
`handover: waiting for origin/main to have the runner`, and `.tool/queue
ls` prints `… handover waiting to move the LaunchAgent onto …/.runner`.

**Bugs found on the way:**

- The first try at a handover was a detached child of the queue. launchd
  killed it when the queue that started it exited. It is now a launchd job
  of its own.
- The real job then exited at once with `78: EX_CONFIG`, writing nothing.
  The cause was an old `handover.log`, left by that first try and created
  from a sandboxed session, which launchd couldn't open as the job's
  output. I checked this with a job identical except for its label: it got
  78 with that log and ran with a log in `/tmp`. `adopt` now deletes the log
  before loading the job. The test writes such a log first, and passes.

**Not verified here:**

- The real move itself. It happens when this PR merges, and the push
  "Lunna queue moved to its runner" tells you it did. If it doesn't come,
  `.tool/queue ls` and `.git/queue/handover.log` say where it stopped, and
  `.tool/queue setup` is still the manual way.
- A real pass from the runner, and the PR body as GitHub renders it. You'll
  see both on the next issue after the move.

## 5. Not done

- **PostHog's build.** It still needs its issue:
  `.tool/queue implement product/research/2026-10-21-posthog/README.md`
  (or answer the question on #15).
- **Shorebird (#3/#4).** That PR was closed rather than approved, so no
  build was due.
- **The other RFC (#8).** `Implement: A reliable Lunna assistant` has no
  `create` label, so the queue ignores it.

## 6. References

- `.tool/queue.mjs`: `syncRunner`, `isRunner`, `runnerDir`, `prBody`, `syncPr`, `setup`, `ls`, `loop`, `adopt`, `handover`, `plist`
- `.claude/settings.json`: allows `.tool/queue adopt`
- `code/handover-test.sh`, `data/handover.txt`: the handover on a copy
- launchd's `KeepAlive`/`SuccessfulExit` and its cleanup of a job's leftover processes: `man launchd.plist` (AbandonProcessGroup)
- `.tool/README.md`: the queue section
- `.claude/skills/research/SKILL.md`: Phase 3's first line
- Related: `product/improvements/2026-10-21-github-review-and-rfc-shape/` (#5, which added the page and `implement`; this report is why they never ran)

## 7. Cost and time

Measured by the queue: see the pull request.
