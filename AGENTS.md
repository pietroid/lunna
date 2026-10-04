# Agent Notes

## Project

Focus is a personal productivity system with three parts:

1. **Flutter app** in `app/` — cross-platform control center (iOS, Android, Web).
2. **NestJS backend** in `server/` — REST API, Firebase Auth, Firestore.
3. **AI agent** in `agent/` — separate TypeScript service that runs the model
   and its tools. It has no UI opinions and no access to the thread files.

### Language

Everything the user reads is in Brazilian Portuguese: app strings, the trees
the server builds, the tool summaries a proposal reads back, and the model's
own replies. Code, comments, commits and this file stay in English. A new
user-facing string in English is a bug.

## Stack

- Frontend: Flutter + BLoC + go_router + Firebase Auth (Google Sign-In).
- Backend: NestJS + TypeScript + Firebase Admin SDK + Firestore.
- Agent: Express + TypeScript, internal HTTP service (no public exposure).
- Deployment: Docker on a Raspberry Pi (not Google Cloud Run).

## Firebase

- Production project: `focus-production`
- Dev project: `focus-local-dev` (used for local development with a localhost backend)
- Bundle IDs:
  - Production: `com.pietroid.focus`
  - Dev: `com.pietroid.focus.dev`

## Deployment Overview

Deployment is fully SSH-based. Everything is built on an x64 machine (your dev
machine or a GitHub Actions runner) and transferred to the Pi over SSH.

There are two ways to deploy:

1. **GitHub Actions (recommended)** — push to `main` and let GitHub build the
   Docker images and the Flutter web bundle, then copy them to the Pi over SSH.
2. **Manual / local** — build on your dev machine and copy to the Pi with the
   same scripts the workflows use.

Flutter web **cannot** be built on a Raspberry Pi (the Flutter toolchain is not
available or too slow for ARM). Because of this, the web app is always built on
an x64 machine and the resulting static files are copied to the Pi.

The backend and agent are also built on the x64 runner as ARM64 Docker images
and transferred to the Pi as gzipped `docker save` archives.

## GitHub Actions Deployment

Three separate workflows run on pushes to `main`:

- `.github/workflows/deploy-server.yml` — builds `focus-backend` for ARM64,
  exports it, copies it to the Pi, loads it, and restarts the backend and nginx.
- `.github/workflows/deploy-agent.yml` — same for `focus-agent`.
- `.github/workflows/deploy-app.yml` — builds the Flutter web app, rsyncs the
  static files to the Pi, and reloads nginx.

All three can also be triggered manually from the GitHub Actions tab
(`workflow_dispatch`).

### How it works

1. **Server and agent images** are built on GitHub's `ubuntu-latest` runner as
   ARM64 images (`linux/arm64`) using Docker Buildx + QEMU. They are saved with
   `docker save`, gzipped, and copied to the Pi with `scp`.
2. On the Pi, the archive is loaded with `docker load`, and the relevant
   container is restarted with `docker compose up -d`.
3. **Flutter web** is built with the stable Flutter SDK on the same GitHub
   runner. It produces a static `build/web/` directory, which is rsynced to
   `/opt/focus/web/` on the Pi.
4. The app workflow tells the running `focus-web` nginx container to reload.

> **Performance note:** building ARM64 images on an x64 runner via QEMU is
> slower than building natively. If your repository is public, you can switch
> the workflows to `runs-on: ubuntu-24.04-arm` to build natively on ARM64 and
> skip QEMU.

### SSH key setup

The same SSH key is used by GitHub Actions and by your local machine. For
stronger security you can create a separate key for GitHub Actions, but one key
is enough for a personal project.

On your local machine:

```bash
# Generate a dedicated key pair (no passphrase, or use ssh-agent to cache it)
ssh-keygen -t ed25519 -C "focus-deploy" -f ~/.ssh/focus_pi

# Copy the public key to the Pi so passwordless login works
ssh-copy-id -i ~/.ssh/focus_pi.pub pi@<pi-ip>

# Add a convenient SSH config entry
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat >> ~/.ssh/config <<EOF
Host focus-pi
    HostName <pi-ip>
    User pi
    IdentityFile ~/.ssh/focus_pi
    StrictHostKeyChecking accept-new
EOF
chmod 600 ~/.ssh/config

# Test passwordless login
ssh focus-pi
```

Then add the **private key** to GitHub:

1. Open the repository on GitHub → **Settings → Secrets and variables → Actions**.
2. Click **New repository secret**.
3. Name: `PI_SSH_PRIVATE_KEY`
4. Value: the full contents of `~/.ssh/focus_pi` (the private key, not `.pub`).

### Harden SSH on the Pi

Because the Pi is reachable over SSH, disable password authentication so only
keys can log in.

On the Pi:

```bash
sudo nano /etc/ssh/sshd_config
```

Set or ensure these lines:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
```

Then restart the SSH service:

```bash
sudo systemctl restart ssh
# or on older systems: sudo systemctl restart sshd
```

Keep your existing terminal open while testing login from another window, so
you don't lock yourself out.

Optional extras:

- **fail2ban**: bans IPs after repeated failed login attempts.
  ```bash
  sudo apt install fail2ban
  sudo systemctl enable --now fail2ban
  ```
- **Non-default SSH port**: changes the SSH port from 22 to something else in
  `/etc/ssh/sshd_config`. Remember to update the `PI_HOST` / SSH config on your
  machines accordingly (e.g., `HostName <pi-ip>:2222`).
- **Firewall**: allow only SSH, HTTP, and HTTPS.
  ```bash
  sudo apt install ufw
  sudo ufw default deny incoming
  sudo ufw allow 22/tcp    # or your custom SSH port
  sudo ufw allow 80/tcp
  sudo ufw enable
  ```

### Required GitHub configuration

Repository secrets:

| Secret | Purpose |
|--------|---------|
| `PI_SSH_PRIVATE_KEY` | SSH private key that can log in to the Pi as `PI_USER`. |

Repository variables (Settings → Secrets and variables → Actions):

| Variable | Purpose | Example |
|----------|---------|---------|
| `PI_HOST` | Hostname or IP of the Pi. | `192.168.1.42` or `pi.local` |
| `PI_USER` | SSH user on the Pi. | `pi` |
| `PI_REPO_PATH` | Path where this repo is cloned on the Pi. Defaults to `/home/<PI_USER>/focus`. | `/home/pi/focus` |
| `GOOGLE_SIGN_IN_CLIENT_ID` | Firebase web client ID used by the Flutter web build. | `123-abc.apps.googleusercontent.com` |
| `PROJECT_ID` | Firebase project ID. | `focus-production` |
| `BACKEND_SERVICE_ACCOUNT` | Service account email for the backend. | `focus-backend@focus-production.iam.gserviceaccount.com` |

### Required Pi setup

1. Clone the repo on the Pi at `PI_REPO_PATH`.
2. Place the Firebase service account key on the Pi:
   ```bash
   sudo mkdir -p /opt/focus/secrets
   # copy focus-backend-prod.json to /opt/focus/secrets/
   ```
3. Create the backend environment file:
   ```bash
   cd server
   cp .env.example .env.production
   # fill in the production values
   ```
4. Place the Google Calendar service account key on the Pi:
   ```bash
   # copy focus-calendar-prod.json to /opt/focus/secrets/
   ```
   Then set `GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/focus-calendar-prod.json`
   in `agent/.env.production`.
5. Create the agent environment file:
   ```bash
   cd agent
   cp .env.example .env.production
   # fill in the production values
   ```
6. Ensure the SSH user can write to `/opt/focus/web`:
   ```bash
   sudo mkdir -p /opt/focus/web
   sudo chown -R "$USER:$USER" /opt/focus/web
   ```
7. Create the data directories: the backend's threads, and the agent's map of
   which calendar belongs to which person.
   ```bash
   sudo mkdir -p /opt/focus/data/threads /opt/focus/data/agent
   sudo chown -R "$USER:$USER" /opt/focus/data
   ```
8. Install Docker and docker compose on the Pi.

After the first server deploy, the `focus-web` nginx container will be running.
Subsequent app deploys will sync new web files and reload nginx.

## Architecture: who owns what

The split is one sentence: **the agent gets reliable data, the server decides
what the user sees.**

```
app  ──POST /threads/:slug/messages──▶  server
                                        │ builds the prompt (persona, catalog,
                                        │ hygiene rules, thread history)
                                        ▼
                                       agent  POST /generate
                                        │ runs the model, executes every tool
                                        │ it asks for, loops until there is an
                                        │ answer; returns { raw, toolTrace }
                                        ▼
                                       server parses → validates → scrubs → stores
                                        │
app  ◀──────── thread with a clean A2UI tree ─────────┘
```

### The server owns A2UI

Everything under `server/src/a2ui/` is the single source of truth:

- `a2ui.catalog.ts` — the components, colour roles, icon names and action
  types. The system prompt is **generated from** this file, so the prompt and
  the validator can never describe different catalogs.
- `a2ui-prompt.service.ts` — persona, catalog, the rules about what the user
  must never read, and the history (replayed as prose, not as stored JSON).
- `a2ui-parser.service.ts` — recovers a tree from whatever the model actually
  said: bare JSON, a code fence, JSON buried in prose, or plain prose. It
  reports which rung of that ladder it landed on as `parseStrategy`.
- `a2ui-validation.service.ts` — drops unknown components, strips unknown
  props, and scrubs user-facing strings of tool names, JSON, ids and markdown.
- `a2ui.builders.ts` — the few trees the server writes itself, for the turn
  where the model never answered at all.

The Flutter app implements the other half of the same catalog in
`packages/chat/lib/src/widgets/a2ui_renderer.dart` and
`packages/app_ui/lib/src/app_icons/a2ui_icons.dart`. The icon lists are checked
against each other by `packages/app_ui/test/a2ui_icons_test.dart`, which reads
the server's source directly.

### The agent owns tools

`agent/` no longer knows what A2UI is, has no prompt of its own, and no longer
reads the thread files. It exposes two routes on the private Docker network:

- `GET /tools` — name and description for each tool. The server asks rather
  than keeping a copy, so adding a tool is a one-file change.
- `POST /generate` — runs the prompt the server built, executing every tool the
  model calls inline and returning `{ raw, toolTrace }`.
- `GET /calendar/window`, `POST|PATCH|DELETE /calendar/events` — the calendar,
  with no model in the loop. They exist because the credentials do: the server
  owns the rules about time and the agent owns the connection to Google.

Each tool in `agent/src/services/tools/` carries its own OpenRouter definition,
its own `summarize()` (the line a proposal, a trace and a failure card all read
back in plain Portuguese), and its own `effect`.

### Reads run, writes are proposed

`effect` is the whole contract, and it is two rules rather than one:

- A **read** runs the moment the model asks for it. The agent can see the
  calendar, so making the user grant permission to look at it costs a turn and
  buys nothing. It looks, then answers with what it found.
- A **write** does not run until the user has authorised that specific change.
  The model describes it in full and offers one button carrying a `confirm`
  action; the turn that button starts is allowed to execute, once, without
  asking again.

`ToolExecutorService` enforces this, not the prompt. A write arriving on an
unconfirmed turn is refused before the tool is touched, and the model is handed
an instruction to propose instead. `api_call` decides per call, via `effectFor`:
a GET reads, everything else writes.

There is still no approval dialog. A proposal is an ordinary reply that the
model composes itself, and the app knows nothing about any of this: it posts the
action it was given, as it does for every other action.

### A turn cannot claim what it did not do

Two things stop the old failure, where the model announced an event that was
never created.

The gate is one: a write that never ran comes back as a refusal the model has to
answer. The other is in `ThreadsService`. If a turn attempted a write and none
succeeded, the server discards the model's prose and renders `writeFailedUi`
from the trace: what was attempted, in the tool's own words, why it broke, and a
retry that is still armed. A failed write is exactly where a model is most
tempted to write "pronto, agendei", so that is the one place its sentence does
not reach the user.

A blocked write is not a failed one. Nothing was attempted, so the proposal the
model wrote is exactly right and is shown as is.

### Events and threads

Two things, kept apart on purpose.

An **event** is a block of time. It lives on Google and nowhere else, it is
addressed by its Google id, and everything about when it happens is its own.
`server/src/events/` owns the day: `GET /events` draws it, `POST /events`
writes something down with an hour, `POST /events/:id/move` drags a card,
`POST /events/:id/done` takes a block off the day.

A **thread** is a conversation. It lives in a markdown file, it has a name, a
day it started, its messages and whether the user has closed it, and it has no
hour. `server/src/threads/` owns it: `GET /threads` is the Conversas list,
`GET /threads/solved` the concluded one, and the rest of the routes are the
conversation itself.

**The link lives on the event.** Most blocks never have a thread — a day is
mostly hours, not discussions. `POST /events/:id/thread` starts one when
somebody taps into a block, names it after the block and writes the slug into
the event's `extendedProperties.private.focusThread`. Read back on every
timeline build, that is the only record of the pairing, which is why a thread
file never has to remember an hour and nothing has to be kept in step.
`threads` therefore does not import `calendar`; `events` imports both.

#### The thread store

```
<FOCUS_DATA_DIR>/<userId>/<DD-MM-YYYY>/<thread-slug>.md
<FOCUS_DATA_DIR>/<userId>/traces/<thread-slug>/<traceId>.json
<FOCUS_DATA_DIR>/<userId>/calendar-cache.json
```

A folder is a day and a file is a conversation, whole: front matter
(`created`, `solved`) and every message, however many days it runs over. The
day is the day it **started**, so a thread is written once and never moves,
and a month of folders reads as an archive of what was talked about when.
Traces sit beside the days rather than inside them, which leaves a day folder
readable as the list of conversations that started that day. A file with no
front matter still parses, because hand-editing one is a thing this format is
meant to allow.

### The timeline

**Everything on the timeline is a calendar event.** There is one list, in
clock order, and the headings are cut out of it by the clock rather than
stored anywhere. A card is under "Amanhã" because it starts tomorrow, and the
only way to move it is to change when it happens. `sectionOf` in
`events/event-sections.ts` is the whole filing system:

| Section | What falls in it |
|---------|------------------|
| `agora` | the hour being lived through right now |
| `hoje` | later today |
| `amanha` | the next day |

**An hour that has run out is not a section.** A block booked 11:20 to 11:25
is finished at 11:26: that was its hour, the hour is gone, and leaving it on
screen would make "Agora" mean "now, and also everything now used to be".
Nothing marks it or sweeps it: the clock decides what is drawn on every read,
the app asks again on each minute boundary, and the event stays on Google
because the hour happened. Only finishing something *early* takes the event
off, since that frees an hour still ahead.

Anything further out than tomorrow is not drawn. The three sections are meant
to become one per day, which is why nothing stores one.

**A card shows when it starts and nothing else.** The card after it says when
it ends, near enough. Between cards the app draws the **free stretches** of the
working day: any gap longer than the five-minute pause, plus the edges, from
now or 07:00 to the next card and from the last card to 22:00. They are worked
out on the phone by `TimelinePlan.freeSlots` and are drop targets. A card let
go over one is posted as a move with `after` (where the stretch really starts,
pause included) so the layout puts it at the start of that stretch and not
earlier. A card longer than the room there asks to be cut to fit and posts
`minutes` as well. A no leaves the day alone.

A fixed card, a routine's day included, only lands in empty room. It goes
where its top edge is, on the nearest quarter of an hour that keeps it whole
(`TimelineScale.landingIn`), and `after` carries that hour. The room draws the
block there, hours and all, while it is aimed at. Let go between two cards it
keeps its hour. Empty room is cut at its hour lines, and each part ripples on
its own when tapped. A tap opens the creation sheet. In the first part, up to
the first full hour, the block is flexible and posts `notBefore`, the start of
the room, so `create` looks for a slot from there and keeps it as the block's
floor. In any hour after that, the block is fixed at that hour. A first part
shorter than a quarter of an hour runs on into the next hour, so it can be hit.

### The time system

Three files hold every rule about when things happen, and all three are on the
server.

- `time/work-hours.ts` — the working day runs **07:00 to 22:00** and blocks are
  spaced **5 minutes** apart. Both are constants here and nowhere else, along
  with slot-finding and conflict detection.
- `time/scheduling.ts` — `relayout`, which is the scheduler entire.
- `time/zone.ts` — wall-clock arithmetic in the calendar's own timezone.
  The zone travels with the events, from the agent, and **`FOCUS_TIMEZONE`
  (or `TZ`) on the agent overrules what Google says a calendar's zone is.**
  These calendars are created by a container inside a service account, so the
  zone Google holds on them is the container's rather than the user's;
  believing it is how the working day started at 04:00 in São Paulo and how
  an evening block got pushed to tomorrow. When the deployment names a zone
  the calendar is patched to agree with it.
- `events/event-layout.service.ts` — what adding, dragging and finishing do to
  the day.

#### One rule

The day is a queue of **flexible** blocks flowing around a handful of **fixed**
ones, packed as close to now as they will go. Flexible is the default and
means "in that order, whenever it fits". Fixed means the hour is the point of
it: the block is an anchor, never moved, and everything else flows around it,
including into the gap before it.

`relayout` is one pass down the queue. Each flexible block takes the first slot
that fits after the cursor, the cursor moves past it, and the next one starts
looking from there. Anchors are never assigned anywhere — they are only
obstacles.

Three things anchor, and the third is the subtle one:

- a meeting Focus did not book, which is somebody else's hour;
- a fixed card, whose hour is the point of it, routines included;
- **a block that has already started**, which keeps the hour it started at.

**A flexible block does not start because its hour came.** It waits for the
user (`awaitsStart` in `event-sections.ts`), and until they say so `catchUp`
slides it to the current minute on every tick and repacks what follows, so
the whole day moves a minute at a time. `POST /events/:id/start` writes
`focusStarted` on the event and from then on it anchors like any running
block. `POST /events/:id/snooze` writes `focusNotBefore` fifteen minutes out
and the block waits there. A waiting block is not an anchor and is never the
running block the guard asks about. Dropping a card at the top of the day
counts as starting it. A started block that the layout moves again has to be
started again. Fixed blocks, routines and meetings never wait.

**`focusNotBefore` is a floor.** `relayout` never starts a block earlier than
it, which is what keeps a snoozed block, or one dropped into a gap further
down the day, from being pulled back to now by the next repack. A drop
between two cards lifts it.

That last one is why rearranging the afternoon does not rewrite what you are
in the middle of. "Agora" says what the user is working on, not that they
began it this second, so a block running since eleven goes on saying eleven.
Its start is a fact by then, not a plan. The one exception is a block the user
just asked to move — the card under their finger, or the running one they
chose to push down — because being asked beats every reason to hold still.

Two operations use it:

- **Adding** (`POST /events`) drops something into the first gap that fits
  *without disturbing anybody*. A fixed block instead takes the hour it was
  given. This is the one write that waits for Google: an event has no id until
  it is booked, and a block Google refused is a block that does not exist.
- **Dragging** (`POST /events/:id/move`, one `index` into the one list)
  rewrites the queue order and lets the whole thing repack.
- **Finishing** (`POST /events/:id/done`) takes the event off Google and
  repacks the queue without it, and closes the conversation about it if there
  was one. Finishing something early is the day getting shorter, not the day
  growing a hole. Closing a *conversation*
  (`POST /threads/:slug/solved`) does none of this: a thread you are done with
  is not an hour given back.

So all three are `relayout` with a different queue, which is why there is no
second copy of the rules anywhere and no guard that has to agree with them.

**The cached day goes first and Google follows.** A drag has to land under the
finger, and waiting for Google to agree before the card settles is what made
it feel like a form. So a move writes the reader's cache, answers the request,
and pushes to Google from a queue behind the response.

What makes that safe is that the queued jobs are not instructions but
**reconciliations**: each one pushes the hour the cache now holds rather than
the hour it was queued with. Two drags of the same card queue two jobs and
both end at the same place, so there is no order to get wrong and nothing to
undo. `CalendarSyncService` runs them one at a time per person, one job per
event.

The cache is a cache and never a second copy of the truth. It holds what was
pushed so the next layout prices the day the user can see, and the next read
from Google overwrites it whatever it said. There is no state to reconcile
between two stores, because there is only one store.

Two writes are awaited rather than queued, and both for the same reason —
the app needs the answer before it can draw anything: booking a block, which
has no id until Google gives it one, and linking a conversation to one, which
would otherwise start a second thread on the next tap.

Thread writes are serialised per thread and written through a temp file and a
rename. Read-modify-write on a thread file is not atomic and no longer has the
luxury of being the only thing running: interleaved, a torn read parses as a
conversation missing its last turn.

When a job does fail, nothing is rolled back. The day on screen is the user's
and it is right; it is the copy on Google that fell behind. `GET /events/sync`
waits for the queue and answers `{ ok: true }` or with the popup to draw —
the app calls it after every change, off the path the finger is on, so there is
no polling and no window where a failure is known and not yet on screen.
`POST /events/sync` is the retry button behind it.

The first block of a day starts at *this minute* rather than the next multiple
of five. That is what makes "Agora" ever contain anything; everything after it
reads off a tidy five minutes.

#### One source

**The calendar is the database.** Nothing about when something happens is
stored anywhere else: no mirror in the thread files, no table of hours,
nothing to reconcile. An hour exists because Google holds an event for it, and
the only way to change one is to change the event.

A card Focus did not book is a meeting: it is drawn, because the hour is not
free, and it cannot be dragged or finished, because none of that is Focus's to
do with it. Focus stamps the events it books (`focusOwned`), so the two are
told apart by the event itself rather than by anything remembered here.

The agent holds the credentials and the server asks for what it needs.
`CalendarReaderService` pulls `GET /calendar/window` when it builds a timeline
or prices a slot, **caches the answer per person** for thirty seconds, and
falls back to the last good read when the agent is unreachable: a timeline
half a minute stale is a small lie, one that says the afternoon is free
because Google timed out is a large one. The cache is a cache and never a
copy — writes push into it so a drag lands under the finger, and the next read
from Google overwrites whatever it said. Moves write through
`POST|PATCH|DELETE /calendar/events` on the same surface.

**One calendar per person, inside one Google account.** The agent resolves a
secondary calendar **named after the person's first name**, creates it on
first use and shares it with their address so they can open it in Google.
That is what keeps one person's afternoon out of another's timeline while
leaving Focus a single account that can see across all of them.
`GOOGLE_CALENDAR_ID` still wins when it is set, which is the single-person
deployment.

`GOOGLE_CALENDAR_MAP` comes next and assigns a Google address to a calendar
somebody chose, as `email=calendar` pairs. A value with an `@` is a calendar
id, typically one another account owns and shared with the service account.
Anything else is a name, looked up in the service account's list and created
there if missing. The assignment is also written into the uid map, because
the model's tools call with a uid and no address.

The name is a title somebody reads, so the uid lives in the calendar's
**description** instead, and that is what a lookup matches on when the
uid-to-calendar map is lost. A calendar still carrying the old `Focus · <uid>`
title is renamed in place on the next read rather than duplicated; one
somebody has renamed by hand is left alone. The name reaches the agent as
`userName` on every call, because the agent holds no user table and knows
nothing about anyone the request does not tell it.

**Every call runs server to agent.** The agent never calls back, holds no
address for the server and no key: these routes are reached exactly the way
`/generate` is, on the private Docker network, and nothing about the calendar
is exposed through nginx. Sections are computed from the clock on every read
and the timeline refetches on the minute, so a card walks into Agora when its
hour arrives without anything having pushed it there.

None of these routes run a model.

#### The one guard

Dragging a card to the top of the day while something else is already running
is the only move that destroys something, so it is the only one that asks:

| Answer | What happens |
|--------|--------------|
| `solve_current` | the running block is finished and gives its hour away |
| `postpone_current` | it is kept, further down the day |

Everything the old guards asked — how long is this, may I book it, that hour is
taken, shall I unbook it — was the screen asking the user to do arithmetic it
could do itself. The duration is answered in the creation sheet, and the rest
is `relayout`.

The guard is an A2UI tree built by `a2ui/a2ui.guards.ts` and drawn by the
renderer that draws replies. The app knows none of the rules; it draws the
buttons and posts the one that was tapped to `POST /events/timing`. Every
button carries the whole move plus one `decision`, so no pending state exists
on either side and a guard abandoned halfway leaves nothing behind.

The `timing` action type is deliberately absent from `MODEL_ACTION_TYPES`. A
model cannot emit one, and the validator drops it out of a reply along with the
button carrying it.

#### Routines

A routine is **one recurring Google event**, stamped `focusRoutine` with
`daily`, `weekdays` or `weekend`. Google does the repeating. Focus keeps no
list of routines and no logic about days. The menu's Rotina screen reads the
recurring events back through `GET /calendar/routines` on the agent, and
`server/src/routines/` turns a wall-clock hour and a length into the first
occurrence in the calendar's zone. Changing the hour, length or days starts
the series again from today, so the first instance always lands on a day the
rule covers.

On the timeline each day of a routine is a fixed, managed block with a
`routine` field. It gets a faint `routineFill` and a repeat mark. The card is
one instance of the recurring event, so it moves, renames and finishes like
any fixed block, and Google keeps the change as an exception for that day
alone. The routine as a whole is edited only from the menu. The reader's
cache is invalidated after a routine write, because only Google knows which
days the new series lands on.

#### Coisas and Conversas

The four tabs are **Tempo**, **Coisas**, **Conversas** and **Menu**.

**Coisas** is the timeline with the clock taken out: things with a title and a
length and no hour, in the order the user drags them into. It lives in
`server/src/things/`, one JSON file per person beside the day folders
(`<root>/<userId>/things.json`), because a thing has no day and is not a
calendar event. Right swipe is done, left swipe deletes after asking, and each
row has one button, `POST /things/:id/schedule`, which books it as a flexible
block through the same `create` the orb uses and then takes it off the list.

**Conversas** is the thread list that used to be called Coisas, unchanged.

#### The orb

One button, three meanings, decided by the tab under it. On **Tempo** it opens
the creation sheet: a line of text, flexible or fixed, a duration, and a line
saying what hour that works out to. A fixed block picks a day as well as an
hour, each its own pill, the day from a wheel a year long. No model runs and nothing is proposed. The card is on the timeline by
the time the sheet closes. On **Coisas** the same sheet opens without the
clock: text and a duration. On **Conversas**, and everywhere else, it starts a
conversation.

#### Reminders

`notifications.service.ts` plans them from the calendar. A flexible block gets
a `confirmStart` reminder at its hour that asks rather than announces, and
carries the event id. Tapping it opens a popup in the app with *Começar agora*
and *Esperar 15 min*, which post `start` and `snooze`. Opening the app or
bringing it back while a block is still waiting opens the same popup, once
per opening. Dismissed, the card in Agora is the running card paused at its
first minute: play starts it and +15 snoozes it. A fixed block or a
routine gets the plain `starting` reminder instead, since it starts
regardless. Blocks the user already started are not asked about again.

The sheet's preview is computed on the phone by `TimelinePlan` in the chat
package, deliberately the same arithmetic the server uses. A round trip per
keystroke would be a spinner where a number should be, and the only way it can
be wrong is something booked on another device since the last load.

### Actions

A rendered component fires an action; the app posts it verbatim to
`POST /threads/:slug/actions` and renders the thread that comes back. The app
interprets exactly two of them itself — `dismiss` and `openUrl` — because
neither needs the server.

| Action | Who handles it |
|--------|----------------|
| `reply` | Server: appends the text as a user message and answers it. |
| `confirm` | Server: the same, and the turn it starts may run writes. |
| `thread` (`solve`/`reopen`/`rename`/`delete`) | Server alone. No agent call. |
| `timing` | Server alone, on `POST /events/timing`. Guards only; a model may not emit one. |
| `sync` | App: posts `POST /events/sync`. The retry on the sync popup; a model may not emit one either. |
| `dismiss`, `openUrl` | App only. The server 400s if one arrives. |

An action type outside the catalog is dropped by the validator, taking its
component with it, so a button a model invented cannot fire anything.

A `confirm` arms exactly one turn. The server also arms the turn that answers a
proposal by typed message, because someone who reads "posso agendar quinta às
10?" and types "pode" has said yes as clearly as someone who tapped it.

Only the last turn's actions are live. The app disables buttons on every
message above it: they belong to a moment the conversation has already moved
past.

### Observability

Every turn gets a trace id (`t_<base36>_<hex>`), minted in the controller and
passed to the agent in the `x-focus-trace-id` header. Both containers log
one-line JSON under it, so one command replays a whole turn in order:

```bash
docker logs focus-backend & docker logs focus-agent | grep t_mu7hizeb_65a155d1
```

The turn is also written to
`<thread>/traces/<traceId>.json` and readable at
`GET /threads/:slug/traces/:traceId`. The trace id is stored on the message
itself and logged by the app, so a screenshot is enough to find the turn
behind it.

Events worth knowing: `prompt.built` (with `allowWrites`),
`agent.generate.start/ok/fail`, `tool.start/ok/fail`, `tool.blocked` (a write on
an unconfirmed turn), `a2ui.parse`, `a2ui.repaired` (every repair and rejection,
in full), `a2ui.validated`, `turn.proposedWrite`, `turn.writeFailed`,
`turn.unavailable`.

### Integrations

- Replies are generated via the [OpenRouter](https://openrouter.ai/) API.
  Configure `OPENROUTER_API_KEY` and `OPENROUTER_MODEL` in
  `agent/.env.production`. Without a key the agent returns 502 and the server
  shows a written "could not reach my brain" message rather than a blank turn.
- **Google Calendar** connects via a service account JSON key file pointed to
  by `GOOGLE_APPLICATION_CREDENTIALS` in `agent/.env.production`, matching the
  backend's Application Default Credentials style. Each person gets their own
  secondary calendar in that account, created on first use and mapped in
  `AGENT_DATA_DIR/calendars.json`. Set `GOOGLE_CALENDAR_ID` to put everyone on
  one named calendar instead, which is the single-person deployment.
- **Web Search** works best with **Serper.dev** or the **Brave Search API**.
  Set `WEB_SEARCH_API_KEY` and `WEB_SEARCH_API_BASE_URL`. Without a key it
  falls back to scraping DuckDuckGo's HTML, which is fine locally and brittle
  in production.

Integration secrets live only in `agent/.env.production`. The server never
holds them and never executes an integration.

## Manual / Local Deployment

These commands are useful for testing or when you do not want to use GitHub
Actions.

### Backend + agent (build locally on your dev machine)

Build the images on your machine and copy them to the Pi:

```bash
cd server
# Build ARM64 image
docker buildx build --platform linux/arm64 -t focus-backend:latest .
docker save focus-backend:latest | gzip > focus-backend.tar.gz
scp focus-backend.tar.gz pi@<pi-ip>:/tmp/

# On the Pi, load and start
ssh pi@<pi-ip> "docker load < /tmp/focus-backend.tar.gz && cd /home/pi/focus/server && docker compose up -d focus-backend focus-web"
```

For the agent, do the same from the `agent/` directory with `focus-agent:latest`
and `docker compose up -d focus-agent`.

### Web app (from your dev machine)

Because Flutter web cannot be built on the Pi, build it locally and rsync it:

```bash
cd app
./scripts/deploy-web.sh pi@<pi-ip>
# or, if you created the SSH config entry above:
./scripts/deploy-web.sh focus-pi
```

This builds `build/web/` on your machine and copies it to `/opt/focus/web/` on
the Pi, then reloads nginx.

## Image transfer options

The current workflows use **`docker save | gzip` + `scp` + `docker load`**.
This avoids any container registry but transfers the whole image every deploy.
For these small Node images that is fine over a home network.

The alternative is a **registry pull** (`ghcr.io`, Docker Hub, etc.): push the
image from the runner, then run `docker compose pull` on the Pi. This is faster
and cache-friendly, but requires a registry and possibly authentication.

For Flutter web there is no image; the static files are copied with `rsync`.

## Web / nginx routing

The Pi exposes port `80` via nginx. Static files are served from
`/opt/focus/web`, and requests to `/api/` are proxied to the
`focus-backend:3000` container.

Mobile production builds use `API_BASE_URL=http://<pi-ip>/api/`; web builds use
the relative `/api/` and are served from the same origin. Both hit nginx on
port `80`, which strips the `/api/` prefix and proxies the requests to the
NestJS backend.

## Security

- Never commit Firebase service account JSON keys.
- `app/env/production.json` is gitignored; use `production.example.json` as a template.
- `agent/.env.production` is gitignored; use `agent/.env.example` as a template.
- The SSH deploy key can log in to the Pi. Keep the private key safe and limit
  what the Pi user can do (do not give it root unless necessary).
- `app/lib/firebase_options_production.dart` and `app/lib/firebase_options_dev.dart` are tracked (they only contain public Firebase client API keys). Other generated Firebase config files (`google-services.json`, `GoogleService-Info.plist`) remain gitignored and must be regenerated with `./app/update_firebase_config.sh` after Firebase changes.
- `app/env/dev.json`, `app/env/production.json` and `app/env/*.local.json` are gitignored; use `app/env/dev.example.json` and `app/env/production.example.json` as templates.

## Common Commands

```bash
# App local dev (uses dev Firebase + localhost backend)
cd app
flutter pub get
flutter run --flavor dev --dart-define-from-file env/dev.json

# Backend local dev (uses dev Firebase + localhost agent)
cd server
npm install
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/focus/focus-backend-dev.json"
npm run start:local

# Agent local dev (uses dev calendars + local data)
cd agent
npm install
npm run start:local

# Web deploy from your dev machine (production)
cd app
./scripts/deploy-web.sh focus-pi
```
