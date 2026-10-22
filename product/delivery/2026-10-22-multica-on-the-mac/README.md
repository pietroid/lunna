# Multica on the Mac, beside the GitHub queue

2026-10-22 · delivery · **built** · track: plan

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

## 3. What was built

Tooling only: no app, server, CI or deploy file changed. Phase 0 is now
`.tool/multica steps` (the list) plus a few commands; Phase 1 has its
empty scorecard and the tool that fills it; Phase 2's teardown is written
and was never run.

### The contract

**An issue lives in GitHub or in Multica, never both**, and only the
queue merges. Multica's agent stops at every gate by ending its run with a
comment (no one waits inside a run), goes on only on "approve", opens its
PR labelled `multica` and never merges. That last part is a prompt
(`.tool/multica-agent.md`), not code: it is what the trial measures.

### Files

| File | What it is |
|------|------------|
| `.tool/multica`, `.tool/multica.mjs` | `steps`, `env`, `daemon`, `check`, `score`, `down`, Node with nothing to install, like `queue` |
| `.tool/multica-agent.md` | The agent's instructions, pasted into Multica (step 8) |
| `product/research/2026-10-21-multica-on-the-mac/data/scorecard.md` | The RFC's table, empty, with what each column counts |
| `.tool/queue.mjs` | `LABELS` gets `multica`, so `queue setup` creates it |
| `.tool/README.md`, `AGENTS.md` | A `multica` section; "Two queues" and the Layout line |
| the RFC, step 2 | One key removed (see the differences below) |

### Proof

Nothing could run end to end here (no `multica` user, no Docker, no
tunnel), so each command ran as far as this Mac allows.

`.tool/multica env --dry-run` against Multica's `.env.example` fetched at
`v0.6.5` (into a temp dir, `--dir`):

```
/tmp/mc-env/.env would get, on top of .env.example:
  MULTICA_IMAGE_TAG=v0.6.5
  DO_NOT_TRACK=1
  APP_ENV=
  MULTICA_DEV_VERIFICATION_CODE=
  FRONTEND_ORIGIN=https://multica.pietroteruya.dev
  CORS_ALLOWED_ORIGINS=https://multica.pietroteruya.dev
  MULTICA_PUBLIC_URL=https://multica.pietroteruya.dev
  MULTICA_TRUSTED_PROXIES=127.0.0.1/32
  ALLOW_SIGNUP=false
  ALLOWED_EMAILS=pietrodomingues@gmail.com
  SMTP_HOST=smtp.gmail.com
  SMTP_PORT=587
  SMTP_USERNAME=pietrodomingues@gmail.com
  SMTP_FROM_EMAIL=pietrodomingues@gmail.com
  JWT_SECRET=(new, 64 hex)
  SMTP_PASSWORD=(asked when run)
```

Then for real in that temp dir, a fake app password piped in, twice:

```
✓ /tmp/mc-env/.env written (0600), a new JWT_SECRET: keep a copy, a moved server needs the same one
✓ /tmp/mc-env/.env written (0600), its JWT_SECRET kept
JWT kept
```

Every key was set on its own line of the example (nothing appended), the
file is `-rw-------`, and the spaces Google puts in an app password are
dropped.

`.tool/multica check` on this Mac, before any install (exit 1):

```
✗ docker compose: no stack
    → steps 1–2: OrbStack, then clone Multica into /Users/pietro/multica
✗ no /Users/pietro/multica/.env
    → .tool/multica env
✗ backend localhost:8080/healthz: ECONNREFUSED
    → step 2: docker compose logs backend
✗ web app localhost:3000: ECONNREFUSED
    → step 2: docker compose logs frontend
✗ cloudflared is not running
    → step 3: sudo cloudflared service install <token>
✗ https://multica.pietroteruya.dev/: ENOTFOUND
    → step 3: the hostname with an empty path → http://localhost:3000
✗ https://multica.pietroteruya.dev/ws: ENOTFOUND
    → step 3: the row with path ^/ws(/.*)?$ → http://localhost:8080, above the other one
✗ no daemon running as multica
    → step 7 (or after a reboot): .tool/multica daemon
```

The `/ws` probe's answer was read in Multica's source at `v0.6.5`: the
router serves `/healthz` and `/ws` (`server/cmd/server/router.go:1441`,
`:1465`), and a bare `/ws` gets `400 {"error":"workspace_id or
workspace_slug required"}` before any upgrade (`realtime/hub.go`), which
is what `check` looks for. The accounts line reads `select email from
"user"` (`migrations/001_init.up.sql`).

`.tool/multica score` on merged queue issues, from GitHub:

```
$ .tool/multica score 26 github --dry-run
| #26 → #27 | github | 4.1 | 3 | 3 |  |  |
$ .tool/multica score 18 github --dry-run
| #18 → #19 | github | 0.1 | 6 | 6 |  |  |
```

#26 was opened at 14:55 and #27 left draft at 19:01 (4.1 h); its three
comments are the two "approve" and a "proceed", the queue's own four left
out. Run without `--dry-run` it added the row under the table's header
(then removed, so the scorecard ships empty).

`.tool/multica daemon --dry-run` and `.tool/multica down`:

```
  sudo -iu multica sh -lc 'multica config set server_url http://localhost:8080'
  sudo -iu multica sh -lc 'multica config set app_url https://multica.pietroteruya.dev'
  sudo -iu multica sh -lc 'MULTICA_DAEMON_MAX_CONCURRENT_TASKS=1 multica daemon start'
  sudo -iu multica sh -lc 'multica daemon status'

Phase 2, if GitHub wins. Would run, in order:
  sudo -iu multica sh -lc 'multica daemon stop'
  docker compose -f /Users/pietro/multica/docker-compose.selfhost.yml down
  sudo cloudflared service uninstall
  sudo sysadminctl -deleteUser multica
then by hand: Cloudflare → Tunnels → delete "mac" (and its two hostnames); the app off the iPhone; the Postgres volume stays until docker volume rm
Run again with --yes to do it.
```

`node --check` passes on `multica.mjs` and `queue.mjs`. `.tool/check`:
`nothing changed (pass --all to check everything)`, exit 0: it checks the
app and the server, and neither changed.

### Where the build differs from the plan

- **`WORKSPACE_CREATION_ALLOWED_EMAILS` is gone.** Multica `v0.6.5`'s
  `.env.example` and `docker-compose.selfhost.yml` have no such key (the
  nearest is `DISABLE_WORKSPACE_CREATION`, all or nothing). With one
  allowed address nobody else can sign in to make a workspace, so nothing
  replaces it. The RFC's step 2 is corrected, with a note. `env` reports
  any key a future `.env.example` lacks instead of writing it silently.
- **`env` also blanks `APP_ENV` and `MULTICA_DEV_VERIFICATION_CODE`**:
  compose reads an empty `APP_ENV` as production, which ignores a fixed
  code, and a fixed code on a public URL would be an open door. `check`
  turns either into a ✗.
- **`daemon` runs from your account**, each command through
  `sudo -iu multica` (or directly when already `multica`), so after a
  reboot it is one command, and the shell it opened is gone when it ends,
  which is what `check` then proves.
- **Step 2 checks out `v0.6.5`** in `~/multica` (`steps`), so the compose
  file matches the pinned images.
- **`check` does more than the plan listed**: the `.env` lock (sign-up off,
  one address, the public origin for CORS, the pinned tag), `cloudflared`
  running, the accounts in Postgres, and a daemon running as *you* (the
  boundary broken) as a ✗.
- **`score` measures to "ready for review"**, not to the PR's creation:
  the queue opens a draft PR at its design gate, Multica only after your
  last "approve", so creation would favour the queue. It finds the PR by
  branch (`queue/<n>-…`, or `agent/…<issue>…`), and a Multica issue's own
  comments, which live in Multica, are added with `--comments` and
  `--rounds`. The agent marks what it posts on GitHub with
  `<!-- multica -->` so it is never counted as yours, as the queue does.

### Not run

The setup itself; the tunnel's `/ws` row in front of a live backend; the
daemon outliving the `sudo` shell; the memory figure on the Air; `env`
against the real `~/multica`; the hidden password prompt on a terminal
(only the piped path ran); `daemon`, `down --yes`; `score` on a Multica
issue (none exists). Your first `.tool/multica check` after the evening
is the proof of all of them.

## 4. How to turn it on

On the Mac, from the lunna repo, after this merges:

```bash
gh label create multica --color 5319e7   # or .tool/queue setup, which now makes it too
.tool/multica steps      # the list; each "you$ .tool/multica …" line is one of the commands below
.tool/multica env        # step 2, asks for the Gmail app password
.tool/multica daemon     # step 7, and after every reboot
.tool/multica check      # step 10: every line ✓
```

Step 8 pastes `.tool/multica-agent.md` (below the line) into the agent.
Nothing needs a new secret in the repo or in GitHub: the app password and
`JWT_SECRET` stay in `~/multica/.env`, the daemon's tokens with the
`multica` user. Without any of it, nothing changes: the queue works as
before, and `check` lists what is missing.

Phase 1 then: new work goes to one queue or the other, and each finished
issue gets `.tool/multica score <issue> <github|multica>`.

## 5. Cost and time

Measured by the queue: see the pull request. No spend outside Claude: no
OpenRouter call, nothing installed, only `gh` reads of this repo and of
Multica's public files.

## Decided unattended

- Track plan; this PR ships Phase 0 as tooling and the empty scorecard for
  Phase 1, and only writes Phase 2's teardown.
- The key the RFC named and `v0.6.5` lacks is dropped, and the RFC
  corrected, rather than left for you.
- `score` counts to "ready for review" (above), and the agent marks its
  GitHub comments.
- No boot LaunchDaemon for the daemon (decision 6): `daemon` is re-run
  after a reboot.
