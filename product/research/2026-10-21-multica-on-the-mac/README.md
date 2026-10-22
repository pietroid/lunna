# Multica on the Mac, beside the GitHub queue

2026-10-21 · RFC · revised 2026-10-22 four times after review (issue #18) · deep-research pass not run

## In one minute

**Run Multica as a second, separate queue, served at
`multica.pietroteruya.dev` through a Cloudflare tunnel, signed in with
your email only. The Mac hosts the server and the one agent, and nothing
else does.**

- **Do:** the [setup list](#the-setup-list): about an evening, no code in
  this repo.
- **Do:** run the daemon as a separate `multica` user on the Mac.
  It starts `claude` with permission checks off, and on a public URL your
  login is the only thing between the internet and that shell.
- **Do:** lock sign-in to one address (`ALLOWED_EMAILS`, no sign-up) and
  send the codes by email (Gmail SMTP), so the iPhone can sign in away
  from the Mac.
- **Do:** keep a [scorecard](#the-scorecard) for both queues for two weeks.
- **Do:** build the iPhone app in Xcode from Multica's source, pointed
  at that address; the web app is the same account in a browser.
- **Not needed:** Tailscale, a password, Google sign-in, Cloudflare
  Access, opening a port, another server.
- **You decide:** only what Multica's agent hands back (recommended: a
  PR on GitHub).

> **Decision (2026-10-22):** Write succint command to use multica in
> parallel with github. We will test both and see who wins. No problem of
> having separate backlogs and ticketing system. Just write me a list of
> what I need to setup

> **Decision (2026-10-22):** proceed with that and I want to use the
> iphone and the webapp. I can serve it on multica.pietroteruya.dev for
> example, and it should have authentication with a password or account
> (if that's possible). Consider that I will run multica on other places

> **A:** Done, with one correction: **Multica has no password login.**
> It signs in with an account, two ways: a 6-digit code sent to your
> email, or Google on the web ([auth setup](https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/auth-setup.mdx)).
> The iPhone app only does the email code (`apps/mobile/app/(auth)/login.tsx`),
> so the setup uses the code everywhere and adds Google as an option.
> The code is a fair lock for one person: it lives 10 minutes, dies after
> 5 wrong tries, and one is sent per minute
> (`server/internal/handler/auth.go:362`, `verification_code.sql:11`), and
> only your address can ever get an account. Serving it publicly replaces
> Tailscale (steps 1, 2 and 8 changed), and "other places" became
> *Running it elsewhere* (deleted in the fourth revision, below): more
> machines as agents, or the server itself moved.

> **Decision (2026-10-22):** native app built in xcode! / yep, can be the
> simples, email code / no, run multica in my own mac.

> **A:** Done: decisions 2, 3 and 4 are taken and gone from the list.
> Step 9 now builds the native app, and the web app is still there for the
> browser. Sign-in is the email code only, so Google is out. There is no
> Cloudflare Access, and the server stays on your Mac, so "the server
> moved" is down to one line. One correction to the earlier draft: **the
> iPhone app has no push notifications.** It has no notification library,
> and nothing in the server sends to Apple (`apps/mobile/package.json` at
> `fd6fc2c`). It refreshes live while it is open, the same as the web app.
> The open question about the app's websocket is settled: the server lets
> a native client through, since it sends no `Origin` or its own host
> (`server/internal/realtime/hub.go:165`).

> **Decision (2026-10-22):** (on the issue, asked whether to delete
> *Running it elsewhere* if Multica runs on the Mac and nothing else)
> Yeah you can delete it

> **A:** Deleted. Multica now runs on the Mac alone: one server, one
> daemon, one agent (`lunna-mac`). Everything that only served other
> machines went with it: the second agent, "on every machine", the
> remote-daemon check in *Still unverified*, and the diagram's other
> machine. Idea 5 is now about the tunnel alone (no port opens on the
> Mac). The steps themselves did not change; only the comment on step 7.
> If you ever do want a second machine, the earlier revision in this
> PR's history has the four commands.

## Ideas to keep

1. **"One queue, one writer."** Separate backlogs keep that true: an
   issue is in GitHub *or* in Multica, never both. See
   [one writer per queue](../concepts.md#one-writer-per-queue). The
   shared thing left is the Claude subscription: the queue and the
   daemon spend the same weekly limit, so cap the daemon at one run.
2. **"The boundary is the daemon user."** Multica,
   [Security model](https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/security-model.mdx):
   "a run can read your SSH keys, edit your shell profile, and delete your
   documents"; the lightest fix is "a dedicated Unix user". *For us:* a
   `multica` user on the Mac, with its own `claude` login and a
   GitHub token for `pietroid/lunna` only. *Deeper than*
   [skip permissions only inside a box](../concepts.md#skip-permissions-only-inside-a-box).
3. **"A gate in code can't be skipped; a gate in a prompt can."** What
   the trial measures. The queue's "approve" is a regex (`queue.mjs:44`);
   in Multica, stopping for you is a line in the agent's instructions. See
   [workflow before agent](../concepts.md#workflow-before-agent).
4. **"On a public URL, the login is a shell."** Anyone who signs in can
   assign an issue to an agent that runs code on the Mac with no
   questions asked. So the login gets the care a shell would: one
   allowed address, no sign-up, codes that only your inbox receives.
   *Deeper than* [private network before public port](../concepts.md#private-network-before-public-port),
   which this RFC first followed and you overrode: a public port is fine
   once you know what it opens.
5. **"The tunnel dials out, so no port opens."** The connector on the
   Mac opens its own connection to Cloudflare
   ([Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/):
   "outbound-only connections"), and requests come back down it. Nothing
   listens on the Mac's network, and the router is never touched. *New.*

## The setup list

`you$` is your account; `multica$` is the agent's (`sudo -iu multica`).
`<host>` is `multica.pietroteruya.dev`.

**1. Docker and the tunnel connector (you)**

```bash
you$ brew install --cask orbstack       # open it once; it starts at login
you$ brew install cloudflared
```

**2. The server (you, once)**

```bash
you$ git clone https://github.com/multica-ai/multica.git ~/multica && cd ~/multica
you$ cp .env.example .env
```

In `.env`, set:

```
JWT_SECRET=<output of: openssl rand -hex 32>
MULTICA_IMAGE_TAG=v0.6.5
DO_NOT_TRACK=1

FRONTEND_ORIGIN=https://multica.pietroteruya.dev
CORS_ALLOWED_ORIGINS=https://multica.pietroteruya.dev
MULTICA_PUBLIC_URL=https://multica.pietroteruya.dev
MULTICA_TRUSTED_PROXIES=127.0.0.1/32

ALLOW_SIGNUP=false
ALLOWED_EMAILS=<your email>

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=<your gmail>
SMTP_PASSWORD=<a Gmail app password>
SMTP_FROM_EMAIL=<your gmail>
```

`.tool/multica env` writes all of this (corrected on the build, #30:
v0.6.5 has no `WORKSPACE_CREATION_ALLOWED_EMAILS`; with one allowed
address nobody else can make a workspace anyway). The app password comes from Google Account → Security → App passwords
(it needs 2-step verification on). Keep `JWT_SECRET` somewhere safe: it
signs every session and token, and a moved server needs the same one.

```bash
you$ docker compose -f docker-compose.selfhost.yml up -d
```

**3. The tunnel (Cloudflare dashboard, you)**

Zero Trust → Networks → Tunnels → **Create a tunnel** → Cloudflared, name
it `mac`. It shows an install command; run it on the Mac:

```bash
you$ sudo cloudflared service install <token>   # a LaunchDaemon: starts at boot
```

Then add two public hostnames, **in this order** (the first match wins):

| Subdomain | Domain | Path | Service |
|---|---|---|---|
| `multica` | `pietroteruya.dev` | `^/ws(/.*)?$` | `http://localhost:8080` |
| `multica` | `pietroteruya.dev` | (empty) | `http://localhost:3000` |

The web app sends `/api` to the backend by itself; only the websocket
needs the first row
([same-origin layout](https://github.com/multica-ai/multica/blob/main/SELF_HOSTING_ADVANCED.md#same-origin-recommended)).
This is a second tunnel; the Pi's stays as it is.

**4. First sign-in (you)**

- Open `https://<host>`, enter your email, type the code from your inbox.
- Create the workspace, then a project `Lunna`.
- In **Settings → API Token**, make a token for the Mac's daemon (`mul_…`).

**5. The agent's macOS user (you, once)**

```bash
you$ sudo sysadminctl -addUser multica -fullName "Multica agent" -password '<pick one>'
you$ sudo -iu multica
```

**6. Tools and credentials for that user (`multica$`)**

```bash
multica$ curl -fsSL https://claude.ai/install.sh | bash   # then run `claude` once and /login
multica$ gh auth login              # paste a fine-grained token: pietroid/lunna only,
                                    # Contents + Pull requests: read and write
multica$ gh auth setup-git
multica$ git config --global user.name "Multica agent"
multica$ git config --global user.email "<your noreply address>"
```

The repo also needs `flutter` and `npm` on that user's `PATH`.

**7. The daemon (`multica$`)**

```bash
multica$ brew install multica-ai/tap/multica    # if `multica` isn't there yet
multica$ multica config set server_url http://localhost:8080   # straight to the backend, not through the tunnel
multica$ multica config set app_url https://multica.pietroteruya.dev
multica$ multica login --token                  # the mul_ token from step 4
multica$ MULTICA_DAEMON_MAX_CONCURRENT_TASKS=1 multica daemon start
multica$ multica daemon status
```

**After a reboot**, run `sudo -iu multica` and the last two commands
again. `daemon autostart` installs a LaunchAgent, which only starts when
that user logs in, and the `multica` user never does.

**8. The agent and the repo (web app)**

- **Settings → Runtimes**: the Mac shows up, as user `multica`.
- **Settings → Code**: add `https://github.com/pietroid/lunna.git`, and
  add it to the project `Lunna` as a repository. Each run gets its own
  worktree and branch, `agent/<agent>/<issue>`; Multica never merges.
- **Settings → Agents**: create `lunna-mac` on the Mac's runtime, with the
  Claude Code tool and concurrency 1. Its instructions:

  > Read AGENTS.md first. For an issue that asks for research, use
  > /research; for a feature, use /create. Stop at each gate the skill
  > names and wait for my comment. When I say "approve", push the branch
  > and open a PR with `gh pr create`, labelled `multica`. Never merge.

**9. The iPhone app (you, Xcode)**

Multica isn't on the App Store. It is built from source on the Mac and
installed on the phone over USB
([Mobile app](https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/mobile-app.mdx)).
First, once:

- Xcode → Settings → Accounts: sign in with your Apple ID.
- iPhone → Settings → Privacy & Security → **Developer Mode** on.
- `brew install node pnpm` if they are missing.

```bash
you$ cd ~/multica && pnpm install
you$ printf 'EXPO_PUBLIC_API_URL=https://multica.pietroteruya.dev\nEXPO_PUBLIC_WEB_URL=https://multica.pietroteruya.dev\n' \
       > apps/mobile/.env.production.local
you$ export EXPO_BUNDLE_IDENTIFIER_PROD=dev.pietroteruya.multica
you$ pnpm ios:mobile:device:prod:release
```

- If the phone won't open it: Settings → General → VPN & Device
  Management → trust your certificate.
- Sign in with the email code.
- **Every 7 days** (free Apple ID) it stops opening. Plug the phone in
  and run the last two lines again. Your data lives on the server, so
  nothing is lost. To update, `git pull` and run them again.
- The app finds its websocket from the API address (`wss://<host>/ws`,
  `apps/mobile/data/realtime/realtime-provider.tsx:54`), so step 3's
  first row serves it too.
- No push notifications: open the app to see what changed.

The web app is the same account: `https://<host>` in any browser.

**10. Try it**

Create an issue in Multica, assign it to `lunna-mac`, answer it from the
phone. Leave GitHub issues to the queue; never file the same work in both.

## The scorecard

Two weeks, one row per issue, in `data/scorecard.md`:

| Issue | Queue | Ask → PR (hours) | Your comments | Rounds | Merged as is? | Went wrong |
|---|---|---|---|---|---|---|

At the end, also check: did Multica ever skip a gate, did a run touch
anything outside its worktree, which app you opened more on the phone,
and whether any sign-in arrived that wasn't you (the backend log).

## Decisions for you

1. **What Multica's agent hands back.**
   - (a) **A PR on GitHub, labelled `multica`** *(recommended)*: CI runs
     and you merge in the same place, so the comparison is fair.
   - (b) Only the local `agent/…` branch, reviewed with `git diff`.

Decided on 2026-10-22: the native iPhone app (built in Xcode), email
code only, no Cloudflare Access, the server on your Mac.

If the free 7-day signing gets old, the $99/year Apple Developer Program
makes a build last a year and allows TestFlight. That is not needed to
start.

## Decided unattended

- **Same host for app and API** (`multica.pietroteruya.dev`, the
  websocket by path), not `api.` + `app.`. Multica calls it the layout
  "least likely to break and the safer one": the session cookie stays on
  one host.
- **Gmail SMTP for the codes**, not Resend: Resend needs a verified
  sending domain; your Gmail needs one app password. Without either, the
  code only appears in the server log on the Mac.
- **Sign-up off from the start.** `ALLOWED_EMAILS` lets your address in
  even with `ALLOW_SIGNUP=false` (`auth.go:264`), so there is no window
  where anyone can register.
- **The Mac's daemon talks to `localhost`**, so it keeps running when
  the tunnel or the internet is down.
- **One run at a time** on the daemon and the agent: they share one
  Claude subscription with the GitHub queue.
- **v0.6.5 is pinned** (released 2026-10-21; Multica releases "most
  weekdays"). Upgrade on purpose.
- **The mirror from the first draft is gone** (separate backlogs); it is
  in the branch history.
- **Mac only** (your answer on the issue): *Running it elsewhere* is
  deleted, along with every mention of other machines. Moving the server
  later is not written up either; it would be the database, `.env` with
  the same `JWT_SECRET`, and a connector under the same name.
- **The app's bundle id is `dev.pietroteruya.multica`**, a name under
  your domain. Multica's default id may belong to their Apple team, and
  then Xcode refuses to sign it.
- **Phase 4 (deep research) was not run**: the review didn't ask for it,
  and every claim was read in Multica's source at commit `fd6fc2c`. The
  fourth revision only removed text.
- **Nothing was installed or run on the Mac.**

## Deeper

### How it runs

```
iPhone (web or app) ─┐
browser anywhere ────┴─ https://multica.pietroteruya.dev ─ Cloudflare ─┐
                                                                       │ tunnel (dials out)
                                         Mac: cloudflared ─┬─ /ws → :8080 backend (Go)
                                                           └─ /*  → :3000 web (Next; /api → :8080)
                                         Mac: daemon (user multica) ─ localhost:8080
GitHub issue ─▶ .tool/queue ─▶ PR        Multica issue ─▶ agent/lunna-mac/<issue> ─▶ PR (label multica)
```

### Multica, as read for this RFC

| | What it does | Ref |
|---|---|---|
| Server | Go API `:8080`, Next.js `:3000`, Postgres 17, bound to 127.0.0.1 | 2, 3 |
| Same origin | Next rewrites `/api`, `/auth`, `/uploads` to the backend; `/ws` is not rewritten | 21 |
| Origins | `CORS_ALLOWED_ORIGINS` also gates the websocket; default is localhost only (403 otherwise) | 21 |
| Login | Email code (6 digits, 10 min, 5 tries) or Google on web; no password | 22, `auth.go` |
| Sign-up | `ALLOWED_EMAILS` wins over `ALLOW_SIGNUP=false`; existing users can always sign in | `auth.go:253` |
| iPhone | Built from source; API address baked in by `.env.production.local`; email code only; no push notifications | 10, `apps/mobile/package.json` |
| Websocket origin | No `Origin`, or one equal to the host, always passes: native clients are let in | `realtime/hub.go:165` |
| Daemon | `claude --permission-mode bypassPermissions`, as the user who starts it | 6 |
| Agents | Each bound to one runtime (one machine) | 23 |
| Limits | 20 runs per daemon, 6 per agent by default | 8 |

### Still unverified (check on install)

- The tunnel's path rule: that the dashboard keeps the `/ws` row first,
  and live updates arrive on the phone (a comment shows without reload).
- That a daemon started from `sudo -iu multica` keeps running after that
  shell closes, and what the stack costs in memory on the 16 GB Air.

### Rollout

| Phase | Ships | Size |
|-------|-------|------|
| 0 | Setup list, steps 1 to 10, and the checks above | evening |
| 1 | Two weeks: new work goes to one queue or the other; scorecard | n/a |
| 2 | Keep the winner. If GitHub: `docker compose down`, delete the tunnel, the user and the app. If Multica: move the backlog | XS |

## References

1. multica-ai/multica, README. https://github.com/multica-ai/multica: Go, Next.js, Postgres; the daemon spawns agent CLIs; "We release most weekdays".
2. Multica, `docker-compose.selfhost.yml`. https://github.com/multica-ai/multica/blob/main/docker-compose.selfhost.yml: ports bound to 127.0.0.1; the env names used in step 2.
3. Multica, SELF_HOSTING.md. https://github.com/multica-ai/multica/blob/main/SELF_HOSTING.md: `JWT_SECRET` required; `setup self-host --server-url`.
6. Multica docs, *Security model*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/security-model.mdx: `bypassPermissions`; no sandbox; dedicated user, container or VM.
8. Multica docs, *Daemon and runtimes*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/daemon-runtimes.mdx: 20 runs per daemon, 6 per agent.
9. Multica docs, *AI coding tools comparison*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/providers.mdx: skills from `.claude/skills/`.
10. Multica docs, *Mobile app (iOS)*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/mobile-app.mdx: built from source; Developer Mode; 7-day free signing; `EXPO_BUNDLE_IDENTIFIER_PROD` when signing fails; `.env.production.local` for a self-hosted server.
12. Multica docs, *CLI*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/cli.mdx: `login --token` for a machine with no browser.
14. Claude Code, *Permission modes*. https://code.claude.com/docs/en/permission-modes: `bypassPermissions` for "isolated containers and VMs only".
16. M. Thompson, *Single Writer Principle*. https://mechanical-sympathy.blogspot.com/2011/09/single-writer-principle.html: one execution context owns all mutations.
19. Multica docs, *Project resources*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/project-resources.mdx: worktree per run; "Multica never merges it for you".
20. Multica, CLI_AND_DAEMON.md. https://github.com/multica-ai/multica/blob/main/CLI_AND_DAEMON.md: autostart is a LaunchAgent.
21. Multica, SELF_HOSTING_ADVANCED.md, *Reverse proxy* and *Same origin*. https://github.com/multica-ai/multica/blob/main/SELF_HOSTING_ADVANCED.md#reverse-proxy: `/ws` must reach `:8080` directly; set `CORS_ALLOWED_ORIGINS` to the public origin.
22. Multica docs, *Auth setup*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/auth-setup.mdx: email codes by Resend or SMTP, Google on top.
23. Multica docs, *Agents*. https://github.com/multica-ai/multica/blob/main/apps/docs/content/docs/agents.mdx: an agent "drives an AI coding tool through its bound runtime".
24. Cloudflare, *Cloudflare Tunnel*. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/: outbound-only connector; no inbound port.
25. Google, *Sign in with app passwords*. https://support.google.com/accounts/answer/185833: app passwords for SMTP; need 2-step verification.
