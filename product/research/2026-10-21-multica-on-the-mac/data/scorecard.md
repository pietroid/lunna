# Scorecard: the GitHub queue against Multica

Phase 1 of the [RFC](../README.md): two weeks, one row per issue, each
issue in one queue only. `.tool/multica score <issue> <github|multica>`
adds a row; fill *Merged as is?* and *Went wrong* by hand.

- **Ask → PR**: from the issue's creation to its PR being ready for review
  (the queue's PR leaves draft after the build; Multica's opens after your
  last "approve").
- **Your comments**: yours on the issue and the PR (line comments and
  review bodies too), not the queue's or the agent's. A Multica issue's own
  comments are in Multica: pass `--comments N --rounds N`.
- **Rounds**: the times you answered (a review of many line comments is one).

| Issue | Queue | Ask → PR (hours) | Your comments | Rounds | Merged as is? | Went wrong |
|---|---|---|---|---|---|---|

At the end, also check: did Multica ever skip a gate, did a run touch
anything outside its worktree, which app you opened more on the phone, and
whether any sign-in arrived that wasn't you (`.tool/multica check`).
