# Setup

Lunna (`lunna.pietroteruya.dev`): a Flutter app for iPhone, Android and
the web, and the backend it talks to.

## 1. Neon

Create a Neon project (region **AWS São Paulo, `sa-east-1`**, next to the Pi)
with two branches:

- `main` for production;
- `dev` for local work.

Copy each branch's connection string (it ends in `?sslmode=require`). The
schema is created by the server itself: migrations in `server/drizzle/` run on
every boot.

## 2. Google OAuth

One Google Cloud project, named Lunna, so the consent screen names the app.
Under **APIs & Services → Credentials**, create:

1. **Web client** (OAuth client ID, type *Web application*), origin
   `https://lunna.pietroteruya.dev`, redirect URI
   `https://lunna.pietroteruya.dev/api/auth/callback/google`. Keep its
   **client secret**; only the server gets it.
2. **iOS client** for `com.pietroid.lunna`.
3. **Android client** for `com.pietroid.lunna`, with your keystore's SHA-1.

For local work a second, **dev** project: one web client with origins
`http://localhost:5173` and `http://localhost:3000` and the redirect URI
`http://localhost:3000/api/auth/callback/google`, plus iOS and Android
clients for `com.pietroid.lunna.dev`.

Then:

- `server/.env*`:
  - `GOOGLE_CLIENT_IDS`: the web client first (its redirect flow), then
    every other client whose ID tokens the server accepts (the web client
    the phones' tokens are minted for, if another, and each iOS client),
    comma separated.
  - `GOOGLE_CLIENT_SECRET`: the web client's.
- `app/env/lunna.<env>.json`: `GOOGLE_WEB_CLIENT_ID` (the web client the
  phones' ID tokens are minted for) and `GOOGLE_IOS_CLIENT_ID`.
- `app/ios/Flutter/GoogleSignIn.xcconfig`: each iOS client ID reversed
  (`com.googleusercontent.apps.<id>`), which is the URL scheme Google
  returns to, one line per `[config=*-lunna<Env>]`.

## 3. Local development

```bash
# Server
cd server
cp .env.example .env.local      # fill DATABASE_URL (Neon dev), secrets, Google
npm install
npm run start:local             # http://localhost:3000/api

# App (another terminal)
cd app
cp env/lunna.dev.example.json env/lunna.dev.json
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define-from-file env/lunna.dev.json
flutter run --flavor lunnaDev --dart-define-from-file env/lunna.dev.json   # phone/simulator
```

The flavor picks the bundle ID, the launcher icon and the splash: keep it
in step with the env file (`--flavor lunnaDev` with `env/lunna.dev.json`).

The web template (`web/index.html`, `web/manifest.json`) carries
placeholders for the name and colours, which `tool/brand_web.sh lunna`
fills in on a build; `flutter run -d chrome` shows them unfilled, which is
harmless.

On the web the dev server must run on **5173**: it is the origin the server
trusts (`TRUSTED_ORIGINS`) and Google redirects back to.

On a physical phone, `API_BASE_URL` must be your machine's LAN address
(`http://192.168.x.x:3000/api`), not `localhost`.

Offline, or without a Neon branch: `npm run db:local` starts an in-memory
Postgres on port 5433, and
`DATABASE_URL=postgresql://postgres@localhost:5433/postgres?sslmode=disable`
points the server at it.

## 4. The Raspberry Pi

The Pi runs two containers from GHCR:

- `lunna-backend`: the API, on port 3004 (published on the Pi's loopback
  only, so `curl localhost:3004/api` works there and nothing outside sees it);
- `lunna-web`: nginx serving the Flutter web build and proxying `/api` to
  the backend.

It holds only two files, in `/opt/lunna`:

```bash
sudo mkdir -p /opt/lunna && sudo chown "$USER" /opt/lunna
# /opt/lunna/.env: the production server env (see server/.env.example):
#   DATABASE_URL=<Neon main>
#   BETTER_AUTH_URL=https://lunna.pietroteruya.dev
#   BETTER_AUTH_SECRET=<openssl rand -base64 32>
#   GOOGLE_CLIENT_IDS=<web>,<ios>
#   GOOGLE_CLIENT_SECRET=<web secret>
#   ALLOWED_EMAILS=you@gmail.com
#   LUNNA_TIMEZONE=America/Sao_Paulo
#   OPENROUTER_API_KEY=<key>    # the agent; empty turns it off
#   OPENROUTER_MODEL=<model with tool calls>
#   OPENROUTER_FALLBACK_MODELS=  # optional, comma-separated
#   OPENROUTER_REASONING=low     # optional
#   AGENT_SCHEMA=                # optional: flat (default) or variants
#   POSTHOG_KEY=<phc_…>          # analytics (section 6); empty turns it off
#   POSTHOG_HOST=https://us.i.posthog.com
#   LUNNA_HTTP_PORT=8080
chmod 600 /opt/lunna/.env
```

`docker-compose.yml` is copied over by every deploy. The deploying user must
be able to run `docker` without `sudo` (`sudo usermod -aG docker $USER`).

`LUNNA_HTTP_PORT` (default `8080`) is the port `lunna-web` listens on. Pick ones nothing else
on the Pi uses (other services hold 3000 to 3003). Do not set `PORT` in this
`.env`: the compose file pins the backend to 3004.

`BETTER_AUTH_URL` lists every public origin, the fallback first. Better
Auth then answers each request on its own host, so a Google sign-in comes
back to the host it left from and its cookie is set there.

### Cloudflare Tunnel

The same `cloudflared` tunnel that already exposes SSH for deploys gets a
public hostname for the app:

- `lunna.pietroteruya.dev` → `http://localhost:8080`

## 5. GitHub

`.github/workflows/deploy.yml` runs on every push to `main`: tests, builds
`lunna-backend` (ARM64 under QEMU on a standard x64 runner, which is free for
private repos) and `lunna-web` (Flutter on x64, stamped by `tool/brand_web.sh`, then an
ARM64 nginx image with no emulation), pushes both to `ghcr.io/<owner>/`, then SSHes to the Pi
through the tunnel and runs `docker compose pull && docker compose up -d`.
The Pi logs in to GHCR with the job's own short-lived token, so nothing
long-lived is stored there. Once the Pi is up, a last job prunes each image
down to its five most recent versions.

Keep the images **private**: check under your profile → Packages → each
image → Package settings after the first run. GitHub does not let a public
image go back to private. To roll back, set `LUNNA_TAG=<commit sha>` (one of
the five kept) in `/opt/lunna/.env` and run `docker compose up -d`.

Repository **secrets**:

| Secret | Purpose |
|--------|---------|
| `PI_SSH_PRIVATE_KEY` | SSH key that can log in to the Pi as `PI_USER` |
| `TUNNEL_SERVICE_TOKEN_ID` | Cloudflare Access service token id |
| `TUNNEL_SERVICE_TOKEN_SECRET` | Cloudflare Access service token secret |

Repository **variables**:

| Variable | Example |
|----------|---------|
| `PI_USER` | `pi` |
| `CLOUDFLARE_SSH_HOSTNAME` | `deploy.pietroteruya.dev` |
| `POSTHOG_KEY` | `phc_…`, PostHog's project key (section 6); unset, the web build sends nothing |

### Deploying by hand

```bash
# Images, from the repo root (needs buildx and a GHCR login with write:packages)
docker buildx build --platform linux/arm64 -t ghcr.io/<owner>/lunna-backend:latest --push server
# The web image (the web build calls /api, so use a copy of the env file
# with "API_BASE_URL": "/api")
(cd app && flutter build web --release --pwa-strategy=none --dart-define-from-file env/lunna.web.json && tool/brand_web.sh lunna)
docker buildx build --platform linux/arm64 -f deploy/web.Dockerfile -t ghcr.io/<owner>/lunna-web:latest --push .

# On the Pi
cd /opt/lunna && docker compose pull && docker compose up -d
```

## Mobile builds

```bash
cd app
flutter build ipa --flavor lunnaProduction --dart-define-from-file env/lunna.production.json
flutter build appbundle --flavor lunnaProduction --dart-define-from-file env/lunna.production.json
```

`env/lunna.production.json` points `API_BASE_URL` at
`https://lunna.pietroteruya.dev/api`.
Set `POSTHOG_KEY` in it too (section 6), or the build sends nothing.

## 6. PostHog

Usage, errors and session replays in **one** PostHog
project on the **US cloud** (`product/spec/analytics.md`). Everything is
off until its key is set, so dev, tests, CI and the previews send nothing.

1. Create the project at <https://us.posthog.com> and copy its **project
   key** (`phc_…`, Settings → Project → General). It is public by design:
   it ships inside every client.
2. Put it in three places:
   - the server: `POSTHOG_KEY` (and `POSTHOG_HOST=https://us.i.posthog.com`)
     in `/opt/lunna/.env`;
   - the web build: the repository **variable** `POSTHOG_KEY` (section 5),
     which `deploy.yml` writes into `env/web.json` and `tool/brand_web.sh`
     into the snippet in `index.html`;
   - the phones: `"POSTHOG_KEY"` in `app/env/lunna.production.json`.
3. In the project's settings:
   - **Session replay** → on, and **Canvas capture** on (Flutter web is one
     canvas; the app paints its masks into the frames before they leave).
   - **Heatmaps** → off. **Autocapture** → off (the app has no DOM to
     click).
   - **Error tracking** → on.

The web build sends through `/ingest` on its own origin, which
`deploy/nginx.conf` proxies to PostHog, so ad blockers let it through.

## Brand assets

Icons, splash screens and the web icons come from `app/brands/lunna/`;
[app/brands/README.md](./app/brands/README.md) says how to regenerate them.
