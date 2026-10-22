# Multica on the Mac, beside the GitHub queue

2026-10-22 · delivery · **plan, awaiting approval** · track: plan

## 1. The prompt

From [issue #30](https://github.com/pietroid/lunna/issues/30):

> **Implement: Multica on the Mac, beside the GitHub queue**
>
> Build what the RFC [product/research/2026-10-21-multica-on-the-mac/README.md](https://github.com/pietroid/lunna/blob/main/product/research/2026-10-21-multica-on-the-mac/README.md) recommends, approved in #18 and merged in #19.
>
> - Read it as the research (see "From an RFC" in the /create skill): what it recommends, in its priority order, and its Rollout are the spec.
> - A `> **Decision**` note in it is binding; every other decision takes the option marked *(recommended)*.
> - The plan (or the board, if it changes what the person sees) says which rollout phases this PR ships, Phase 0 first.

The research is the RFC
[product/research/2026-10-21-multica-on-the-mac](../../research/2026-10-21-multica-on-the-mac/README.md).
Its binding decisions: run Multica **in parallel** with the GitHub queue,
separate backlogs; serve it at `multica.pietroteruya.dev`; sign in with
the **email code only**; the **native iPhone app built in Xcode** plus the
web app; **the Mac alone** runs the server and the one agent. Its one open
decision takes the recommended option: Multica's agent hands back **a PR
on GitHub, labelled `multica`**.

## 2. The plan

**Track: plan.** Nothing in Lunna or Focus changes; the work is tooling on
the Mac. This delivery ships **rollout Phase 0** (the setup list, steps 1
to 10, and the checks the RFC left unverified), as scripts in the repo so
the evening is a few commands and the checks can be re-run. **Phase 1**
(two weeks, both queues, the scorecard) starts when this merges: the PR
ships the empty scorecard and the tool that adds its rows, not the rows.
**Phase 2** (keep the winner) is a later issue; its teardown is one
command written here (`down`), never run.

### Approach

1. **`.tool/multica` (+ `multica.mjs`)**, Node, nothing to install, like
   `queue`. Subcommands, each the RFC's step it replaces:
   - `env` (step 2): writes `~/multica/.env` from Multica's
     `.env.example` with the RFC's values (pinned `v0.6.5`, sign-up off,
     `ALLOWED_EMAILS` = the git user's email, a fresh `JWT_SECRET` only if
     there is none), asks for the Gmail app password on the terminal,
     never prints it. Refuses to overwrite a `JWT_SECRET` already there.
   - `daemon` (step 7 and "after a reboot"): run as `multica$`, sets
     `server_url`/`app_url` and starts the daemon with
     `MULTICA_DAEMON_MAX_CONCURRENT_TASKS=1`, then prints `daemon status`.
   - `check` (the RFC's *Still unverified*, one ✓/✗ line each): the
     stack's containers are up; the backend answers `localhost:8080/healthz`;
     `https://<host>/` is the web app and `https://<host>/ws` reaches the
     Go backend through the tunnel (an upgrade request answered by the
     backend, not by Next's 404); the daemon runs as `multica` with no
     shell open (`ps -U multica`); memory of the containers and the daemon
     (`docker stats --no-stream`, `ps -o rss`); every sign-in in the
     backend log is the allowed address.
   - `score <issue> <queue>` (Phase 1): appends a row to the scorecard,
     filling *Ask → PR (hours)*, *Your comments* and *Rounds* from
     GitHub (`gh pr view --json`, the PR's creation against the issue's
     or the Multica issue's time given by hand), leaving *Merged as is?*
     and *Went wrong* for the person.
   - `down` (Phase 2, if GitHub wins): `docker compose down`, the
     tunnel's LaunchDaemon, the `multica` user, printed first and run only
     with `--yes`.
   Steps that are clicks (3 the tunnel's hostnames, 4 first sign-in, 8
   runtimes/repo/agent, 9 Xcode) stay as the RFC's list; the script
   prints them in order (`.tool/multica steps`) with the host filled in.
2. **The agent's instructions in the tree**: `.tool/multica-agent.md`,
   the RFC's step 8 text plus what a run under Multica needs that the
   queue gives its runs: no `AskUserQuestion` (stopping is ending the run
   with the question as a comment; the next comment resumes it), the
   branch `agent/lunna-mac/<issue>`, `gh pr create --label multica`,
   never merge. Pasted into **Settings → Agents**; versioned so the two
   queues' rules can be compared.
3. **The `multica` label** on GitHub, added to the queue's `LABELS`
   (`queue.mjs`), so `.tool/queue setup` creates it. The queue lists only
   issues, so a `multica` PR is never picked up by it.
4. **The scorecard**:
   `product/research/2026-10-21-multica-on-the-mac/data/scorecard.md`,
   the RFC's table, empty, where the RFC put it.
5. **Docs**: a `multica` row and section in `.tool/README.md`; one short
   section in `AGENTS.md` ("Two queues": an issue lives in GitHub *or*
   Multica, never both; Multica's runs follow `.tool/multica-agent.md`);
   `.tool/` line in the Layout block.

### References

- Multica, [CLI_AND_DAEMON.md](https://github.com/multica-ai/multica/blob/main/CLI_AND_DAEMON.md):
  `daemon start` runs in the background by default, `daemon status
  [--output json]` shows "PID, uptime, detected agents, and watched
  workspaces", `MULTICA_DAEMON_MAX_CONCURRENT_TASKS` (default 20).
- Multica, [SELF_HOSTING.md](https://github.com/multica-ai/multica/blob/main/SELF_HOSTING.md):
  `/healthz` answers `{"status":"ok","checks":{"db":"ok","migrations":"ok"}}`
  (shown for Kubernetes; the same backend on `:8080` is assumed and
  checked on install); never set `MULTICA_DEV_VERIFICATION_CODE` on a
  public instance.
- Multica, [SELF_HOSTING_ADVANCED.md, same origin](https://github.com/multica-ai/multica/blob/main/SELF_HOSTING_ADVANCED.md#same-origin-recommended):
  `/ws` must reach `:8080` directly, which is what `check` probes.
- The RFC's own references (security model, mobile app, auth setup,
  Cloudflare Tunnel) stand as cited there.

### Decisions

| # | Decision | Chosen | Why |
|---|----------|--------|-----|
| 1 | What Multica hands back | a PR labelled `multica` *(RFC, recommended)* | CI and merging in one place, so the comparison is fair |
| 2 | Code in the repo at all | a small `.tool/multica`, no app or server code | The RFC says "no code in this repo" for the product; the steps that are commands, and the unverified checks, are worth one re-runnable call each |
| 3 | Where the scorecard lives | the RFC's `data/scorecard.md` | Where the RFC put it, next to the question it answers |
| 4 | Secrets | none in the tree: `.env` stays in `~/multica`, the app password is typed, `JWT_SECRET` generated on the Mac | Same rule as the queue's `cfg` |
| 5 | Run anything on the Mac in this PR | no | Creating a user, `sudo`, a tunnel and an Apple signing are the person's; the run here is unattended |
| 6 | Autostart after reboot | not built; `daemon` is re-run by hand, as the RFC says | A LaunchDaemon running as `multica` is possible but untested by Multica; revisit if reboots hurt in Phase 1 |
| 7 | Phase 2 teardown | written (`down`, behind `--yes`), not run | Phase 2 is a later issue |

### How it will be proved

Nothing here can be run end to end from this worktree (no `multica`
user, no tunnel, no Multica server on this machine), so:

- `node --check .tool/multica.mjs` and `.tool/multica --help`.
- `.tool/multica env --dry-run` against a copy of Multica's
  `.env.example` (fetched at `v0.6.5`): prints the `.env` it would write,
  with the password and secret masked.
- `.tool/multica check` on this Mac **before** any install: every line ✗
  with the step that fixes it, which shows each probe runs and fails
  cleanly.
- `.tool/multica score --dry-run` on a merged queue PR (e.g. #27): prints
  the row it would add, with the hours and comment count from GitHub.
- `.tool/check` for whatever it touches (none of the app or server).
- Section 4 names what was **not run**: the setup itself, the tunnel's
  `/ws` rule, the daemon after the shell closes, the memory figure. The
  person's first `.tool/multica check` after the evening is the proof.

## Build brief

Starts in the same session on approval (a plan doesn't split).

- **Write:** `.tool/multica` (shell wrapper, like `.tool/queue`),
  `.tool/multica.mjs` (`env`, `daemon`, `check`, `steps`, `score`, `down`,
  each with `--dry-run`), `.tool/multica-agent.md`,
  `product/research/2026-10-21-multica-on-the-mac/data/scorecard.md`.
- **Change:** `.tool/queue.mjs` (`LABELS` gets `multica`),
  `.tool/README.md`, `AGENTS.md` (Two queues; Layout).
- **No** app, server, CI or deploy change.
- **Decided unattended:** track plan; this PR ships Phase 0 as tooling and
  the empty scorecard for Phase 1, and only writes Phase 2's teardown;
  everything else as the Decisions table.
- **Open questions:** none blocking. Whether to try a boot LaunchDaemon
  for the `multica` user (decision 6) is left for Phase 1's experience.
- **Cost:** measured by the queue and written in the PR.
