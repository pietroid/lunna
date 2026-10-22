# Multica on the Mac, beside the GitHub queue

2026-10-21 · RFC · revised 2026-10-22 after review (issue #18) · deep-research pass not run

## In one minute

**Run Multica on the Mac as a second, separate queue: its own backlog,
its own agent, the same repo. Each issue lives in one queue only, so the
two never run the same work. Compare them for two weeks.**

- **Do:** the [setup list](#the-setup-list) below: about an evening, no
  code in this repo.
- **Do:** run Multica's daemon as a separate macOS user (`multica`), not
  as you. It starts `claude` with permission checks off.
- **Do:** keep a short [scorecard](#the-scorecard) for both, so "who wins"
  has an answer.
- **Not needed:** the mirror from the first draft (ruled out by your
  decision), Multica's GitHub App, a public URL.
- **You decide:** what Multica's agent hands back: **a PR on GitHub**
  (recommended) or only a local branch.

> **Decision (2026-10-22):** Write succint command to use multica in
> parallel with github. We will test both and see who wins. No problem of
> having separate backlogs and ticketing system. Just write me a list of
> what I need to setup

## Ideas to keep

1. **"One queue, one writer."** Separate backlogs keep that true: an
   issue is in GitHub *or* in Multica, never both, so no run happens
   twice. See [one writer per queue](../concepts.md#one-writer-per-queue).
   *Deeper:* the shared thing left is the Claude subscription. Both
   queues spend the same weekly limit, so cap Multica at one run at a
   time.
2. **"The boundary is the daemon user."** Multica,
   [Security model](https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/security-model.mdx):
   "a run can read your SSH keys, edit your shell profile, and delete your
   documents". It recommends "a dedicated Unix user" as the lightest fix.
   *For us:* a `multica` user with its own `claude` login and a GitHub
   token for `pietroid/lunna` only. *Deeper than*
   [skip permissions only inside a box](../concepts.md#skip-permissions-only-inside-a-box).
3. **"A gate in code can't be skipped; a gate in a prompt can."** This is
   now what the trial measures. The queue's "approve" is a regex
   (`queue.mjs:44`). In Multica, stopping for you is a line in the agent's
   instructions. See [workflow before agent](../concepts.md#workflow-before-agent).
4. **"Reach it privately before you open a port."** Tailscale Serve: only
   your devices can open it. See
   [private network before public port](../concepts.md#private-network-before-public-port).

## The setup list

`you$` is your account; `multica$` is the agent's (`sudo -iu multica`).

**1. Docker and Tailscale (you)**

```bash
you$ brew install --cask orbstack tailscale    # open both once; sign in to Tailscale
```

Install Tailscale on the phone too, with the same account.

**2. The server (you, once)**

```bash
you$ git clone https://github.com/multica-ai/multica.git ~/multica && cd ~/multica
you$ cp .env.example .env
```

In `.env`, set:

```
JWT_SECRET=<output of: openssl rand -hex 32>
MULTICA_IMAGE_TAG=v0.6.5
ALLOWED_EMAILS=<your email>
DO_NOT_TRACK=1
```

Then start it:

```bash
you$ docker compose -f docker-compose.selfhost.yml up -d
you$ tailscale serve --bg 3000
```

The second command gives you `https://<mac>.<tailnet>.ts.net`.

**3. First sign-in (you)**

- Open `http://localhost:3000` and enter your email. With no email
  service set up, the code shows up in the server log:
  `docker compose -f docker-compose.selfhost.yml logs backend | grep "Verification code"`.
- Create the workspace, then a project `Lunna`.
- Set `ALLOW_SIGNUP=false` in `.env` and run `up -d` again.
- In **Settings → API Token**, make a token for the daemon (`mul_…`).

**4. The agent's macOS user (you, once)**

```bash
you$ sudo sysadminctl -addUser multica -fullName "Multica agent" -password '<pick one>'
you$ sudo -iu multica
```

**5. Tools and credentials for that user (`multica$`)**

```bash
multica$ curl -fsSL https://claude.ai/install.sh | bash   # then run `claude` once and /login
multica$ gh auth login              # paste a fine-grained token: pietroid/lunna only,
                                    # Contents + Pull requests: read and write
multica$ gh auth setup-git
multica$ git config --global user.name "Multica agent"
multica$ git config --global user.email "<your noreply address>"
```

`brew`, `gh` and `node` from `/opt/homebrew/bin` work as they are. The
repo needs `flutter` and `npm` on that user's `PATH` too.

**6. The daemon (`multica$`)**

```bash
multica$ brew install multica-ai/tap/multica    # if `multica` isn't there yet
multica$ multica config set server_url http://localhost:8080
multica$ multica config set app_url http://localhost:3000
multica$ multica login --token                  # the mul_ token from step 3
multica$ MULTICA_DAEMON_MAX_CONCURRENT_TASKS=1 multica daemon start
multica$ multica daemon status
```

**After a reboot**, run `sudo -iu multica` and the last two commands
again. `daemon autostart` installs a LaunchAgent, which only starts when
that user logs in, and the `multica` user never does.

**7. The agent and the repo (web app)**

- **Settings → Runtimes**: the Mac should show up, as user `multica`.
- **Settings → Code**: add `https://github.com/pietroid/lunna.git`.
- Add it to the project `Lunna` as a resource (GitHub repository). Each run
  then gets its own worktree and its own branch, `agent/<agent>/<issue>`.
  Multica never merges it.
- **Settings → Agents**: create `lunna` with the Claude Code runtime, and
  set its concurrency to 1. Give it these instructions:

  > Read AGENTS.md first. For an issue that asks for research, use
  > /research; for a feature, use /create. Stop at each gate the skill
  > names and wait for my comment. When I say "approve", push the branch
  > and open a PR with `gh pr create`, labelled `multica`. Never merge.

**8. The phone**

Open the `ts.net` address in Safari and add it to the home screen.

**9. Try it**

Create an issue in Multica, assign it to `lunna`, and answer it from the
phone. Leave GitHub issues to the queue, and never file the same work in
both.

## The scorecard

Two weeks, one row per issue, kept in `data/scorecard.md`:

| Issue | Queue | Ask → PR (hours) | Your comments | Rounds | Merged as is? | Went wrong |
|---|---|---|---|---|---|---|

At the end, also check: did Multica ever skip a gate, did a run touch
anything outside its worktree, and which app you opened more on the phone.
The queue writes each run's cost in its PR. For Multica, read it from the
run details if they show it (not checked).

## Decisions for you

1. **What Multica's agent hands back.**
   - (a) **A PR on GitHub, labelled `multica`** *(recommended)*: CI runs
     and you merge in the same place, so the comparison is fair. Cost: one
     extra token, scoped to the repo.
   - (b) Only the local `agent/…` branch. You review with `git diff` on
     the Mac and merge by hand.
2. **Where the daemon runs.**
   - (a) **A `multica` macOS user** *(recommended)*: the lightest
     boundary the docs offer.
   - (b) As you. Cost: runs can reach your keys, `~/.claude` and every
     other repo you have.
3. **Which phone app.** (a) **The web app on the home screen**
   *(recommended)*. (b) The iOS app built in Xcode: it expires after 7
   days with a free Apple ID.

## Decided unattended

- **The mirror is gone.** You chose separate backlogs, so the first
  draft's mirror (status, gate comment and answers kept in sync between
  the two) is no longer needed. Its dry run and script were removed from
  the folder; they are still in the branch history.
- **The agent's instructions name the skills.** Multica reads skills from
  `.claude/skills/` (ref 9), so `/research` and `/create` work there. The
  gates are only as strong as the prompt (idea 3), which is part of what
  the trial tests.
- **One run at a time**, on both the daemon and the agent, because the
  queue uses the same Claude subscription.
- **v0.6.5 is pinned** (released 2026-10-21; Multica releases "most
  weekdays"). Upgrade on purpose.
- **Nothing was installed.** Every command comes from Multica's docs at
  commit `fd6fc2c` (2026-10-23) and was not run on the Mac.

## Deeper

### How the two run side by side

```
GitHub issue ──▶ .tool/queue (you, auto mode) ──▶ PR
Multica issue ─▶ multica daemon (user multica, bypassPermissions)
                   └▶ worktree of pietroid/lunna ─▶ agent/lunna/<issue> ─▶ PR (label multica)
both: one Claude subscription · phone: GitHub app + ntfy | Multica web over Tailscale
```

### Multica, as read for this RFC

| | What it does | Ref |
|---|---|---|
| Server | Go API `:8080`, Next.js `:3000`, Postgres 17, bound to 127.0.0.1 | 2, 3 |
| Repo | Repository resource: a worktree per run, a branch per issue, never merged | 19 |
| Daemon | `claude --permission-mode bypassPermissions`, as the user who starts it | 6 |
| Limits | 20 runs per daemon and 6 per agent by default; `MULTICA_DAEMON_MAX_CONCURRENT_TASKS` | 8 |
| Login | `multica login --token` for a user with no browser | 12 |
| Phone | Web app; iOS from source; no Android | 10 |

### Still unverified (check on install)

- Whether Tailscale Serve on `:3000` alone is enough, or the websocket
  also needs `:8080`.
- Whether the web app works well on a phone screen.
- Whether the `multica` user can clone with `gh auth setup-git`, or the
  repository resource needs an SSH deploy key.
- Whether a daemon started from `sudo -iu multica` keeps running after
  that shell closes.
- How much memory the stack uses at idle on the 16 GB Air (`docker stats`).

### Rollout

| Phase | Ships | Size |
|-------|-------|------|
| 0 | Setup list, steps 1 to 8, and the checks above | evening |
| 1 | Two weeks: new research goes to one queue or the other; fill in the scorecard | n/a |
| 2 | Keep the winner. If it is GitHub, run `make selfhost-stop` and delete the user. If it is Multica, reopen this RFC to move the backlog over | XS |

## References

1. multica-ai/multica, README. https://github.com/multica-ai/multica: Go, Next.js, Postgres; the daemon spawns agent CLIs; "We release most weekdays".
2. Multica, `docker-compose.selfhost.yml`. https://github.com/multica-ai/multica/blob/main/docker-compose.selfhost.yml: ports bound to 127.0.0.1; `ALLOWED_EMAILS`, `ALLOW_SIGNUP`, `DO_NOT_TRACK`, `MULTICA_IMAGE_TAG`.
3. Multica, SELF_HOSTING.md. https://github.com/multica-ai/multica/blob/main/SELF_HOSTING.md: `JWT_SECRET` required; the login code goes to the backend log when there is no email; `multica config set server_url`, `daemon start`.
6. Multica docs, *Security model*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/security-model.mdx: `bypassPermissions`; no sandbox; dedicated user, container or VM.
8. Multica docs, *Daemon and runtimes*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/daemon-runtimes.mdx: 20 runs per daemon, 6 per agent; `MULTICA_DAEMON_MAX_CONCURRENT_TASKS`.
9. Multica docs, *AI coding tools comparison*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/providers.mdx: skills from `.claude/skills/`; session resumed per issue.
10. Multica docs, *Mobile app (iOS)*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/mobile-app.mdx: not on the App Store; 7-day free signing.
12. Multica docs, *CLI*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/cli.mdx: `login --token` for a machine with no browser; `repo add`.
14. Claude Code, *Permission modes*. https://code.claude.com/docs/en/permission-modes: `bypassPermissions` for "isolated containers and VMs only".
16. M. Thompson, *Single Writer Principle*. https://mechanical-sympathy.blogspot.com/2011/09/single-writer-principle.html: one execution context owns all mutations.
17. Tailscale, *Serve*. https://tailscale.com/kb/1312/serve: shares with your tailnet only, over HTTPS.
19. Multica docs, *Project resources*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/project-resources.mdx: repository resources run in worktrees; branch `agent/<agent>/<issue>`; "Multica never merges it for you".
20. Multica, CLI_AND_DAEMON.md, *Boot autostart*. https://github.com/multica-ai/multica/blob/main/CLI_AND_DAEMON.md: autostart is a LaunchAgent, so it only runs when that user logs in.
