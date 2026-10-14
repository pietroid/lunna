# Setup

One codebase builds two apps: **Focus** (dark, `focus.pietroteruya.dev`)
and **Lunna** (light, `lunna.pietroteruya.dev`). They are the same features
in two skins, with their own names, icons and bundle IDs, and they share one
backend and one database. Moving an existing install to this layout is
[MIGRATION.md](./MIGRATION.md).

## 1. Neon

Create a Neon project (region **AWS São Paulo, `sa-east-1`**, next to the Pi)
with two branches:

- `main` for production;
- `dev` for local work.

Copy each branch's connection string (it ends in `?sslmode=require`). The
schema is created by the server itself: migrations in `server/drizzle/` run on
every boot.

## 2. Google OAuth

Each brand is its own product to Google: **two Google Cloud projects**, one
named Lunna and one named Focus, so the consent screen names the app being
signed into. Both talk to the one server, and the same Google account is the
same user in both apps (Better Auth links them by the verified email).

In **each** project, under **APIs & Services → Credentials**, create:

1. **Web client** (OAuth client ID, type *Web application*), for that
   brand's host only. Keep its **client secret**; only the server gets it.

   | | Lunna project | Focus project |
   |---|---|---|
   | JavaScript origin | `https://lunna.pietroteruya.dev` | `https://focus.pietroteruya.dev` |
   | Redirect URI | `https://lunna.pietroteruya.dev/api/auth/callback/google` | `https://focus.pietroteruya.dev/api/auth/callback/google-focus` |

2. **iOS client** for the brand's bundle ID (`com.pietroid.lunna`,
   `com.pietroid.focus`).
3. **Android client** for the brand's package, with your keystore's SHA-1.

For local work a third, **dev** project serves both brands: one web client
with origins `http://localhost:5173` and `http://localhost:3000` and the
redirect URI `http://localhost:3000/api/auth/callback/google`, plus iOS and
Android clients for `com.pietroid.lunna.dev` and `com.pietroid.focus.dev`.
Locally both brands sign in through `google`.

Then:

- `server/.env*`:
  - `GOOGLE_CLIENT_IDS`: Lunna's web client first (its redirect flow), then
    Focus's web client and every iOS client, comma separated. Every phone's
    ID token is checked against this list, whichever project minted it.
  - `GOOGLE_CLIENT_SECRET`: Lunna's web client's.
  - `FOCUS_GOOGLE_CLIENT_ID`, `FOCUS_GOOGLE_CLIENT_SECRET`: Focus's web
    client, which the `google-focus` provider signs in with. Empty locally.
- `app/env/<brand>.<env>.json`: `GOOGLE_WEB_CLIENT_ID` (the brand's own web
  client, which the phones' ID tokens are minted for),
  `GOOGLE_WEB_PROVIDER` (`google-focus` for Focus in production, `google`
  otherwise) and the brand's `GOOGLE_IOS_CLIENT_ID`.
- `app/ios/Flutter/GoogleSignIn.xcconfig`: each iOS client ID reversed
  (`com.googleusercontent.apps.<id>`), which is the URL scheme Google
  returns to, one line per `[config=*-<brand><Env>]`.

## 3. Local development

```bash
# Server
cd server
cp .env.example .env.local      # fill DATABASE_URL (Neon dev), secrets, Google
npm install
npm run start:local             # http://localhost:3000/api

# App (another terminal)
cd app
cp env/lunna.dev.example.json env/lunna.dev.json    # and focus.dev, likewise
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define-from-file env/lunna.dev.json
flutter run --flavor lunnaDev --dart-define-from-file env/lunna.dev.json   # phone/simulator
flutter run --flavor focusDev --dart-define-from-file env/focus.dev.json
```

The brand is the `BRAND` define in the env file: it picks the colours, the
theme, the mark and the name at compile time (`AppBrand` in `app_ui`). The
flavor picks the bundle ID, the launcher icon and the splash. Keep the two
in step: `--flavor lunnaDev` with `env/lunna.dev.json`. A build with no
`BRAND` (the tests, by default) is Focus.

The web template (`web/index.html`, `web/manifest.json`) carries
placeholders for the name and colours, which `tool/brand_web.sh <brand>`
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
- `lunna-web` and `focus-web`: nginx serving each brand's Flutter web
  build and proxying `/api` to the same backend.

It holds only two files, in `/opt/lunna`:

```bash
sudo mkdir -p /opt/lunna && sudo chown "$USER" /opt/lunna
# /opt/lunna/.env: the production server env (see server/.env.example):
#   DATABASE_URL=<Neon main>
#   BETTER_AUTH_URL=https://lunna.pietroteruya.dev,https://focus.pietroteruya.dev
#   BETTER_AUTH_SECRET=<openssl rand -base64 32>
#   GOOGLE_CLIENT_IDS=<web>,<ios>
#   GOOGLE_CLIENT_SECRET=<web secret>
#   ALLOWED_EMAILS=you@gmail.com
#   LUNNA_TIMEZONE=America/Sao_Paulo
#   LUNNA_HTTP_PORT=8080
#   FOCUS_HTTP_PORT=8081
chmod 600 /opt/lunna/.env
```

`docker-compose.yml` is copied over by every deploy. The deploying user must
be able to run `docker` without `sudo` (`sudo usermod -aG docker $USER`).

`LUNNA_HTTP_PORT` (default `8080`) and `FOCUS_HTTP_PORT` (default `8081`)
are the ports `lunna-web` and `focus-web` listen on. Pick ones nothing else
on the Pi uses (other services hold 3000 to 3003). Do not set `PORT` in this
`.env`: the compose file pins the backend to 3004.

`BETTER_AUTH_URL` lists every public origin, the fallback first. Better
Auth then answers each request on its own host, so a Google sign-in on
`focus.` comes back to `focus.` and its cookie is set there. The `.env`
also needs `FOCUS_GOOGLE_CLIENT_ID` and `FOCUS_GOOGLE_CLIENT_SECRET` (see
section 2).

### Cloudflare Tunnel

The same `cloudflared` tunnel that already exposes SSH for deploys gets a
public hostname for the app:

- `lunna.pietroteruya.dev` → `http://localhost:8080`
- `focus.pietroteruya.dev` → `http://localhost:8081`

## 5. GitHub

`.github/workflows/deploy.yml` runs on every push to `main`: tests, builds
`lunna-backend` (ARM64 under QEMU on a standard x64 runner, which is free for
private repos) and `lunna-web` and `focus-web` (Flutter on x64, branded by
`tool/brand_web.sh`, then an ARM64 nginx image with no emulation), pushes both to `ghcr.io/<owner>/`, then SSHes to the Pi
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

### Deploying by hand

```bash
# Images, from the repo root (needs buildx and a GHCR login with write:packages)
docker buildx build --platform linux/arm64 -t ghcr.io/<owner>/lunna-backend:latest --push server
# Each web image, one brand at a time (the web build calls /api, so use a
# copy of the env file with "API_BASE_URL": "/api")
(cd app && flutter build web --release --pwa-strategy=none --dart-define-from-file env/lunna.web.json && tool/brand_web.sh lunna)
docker buildx build --platform linux/arm64 -f deploy/web.Dockerfile -t ghcr.io/<owner>/lunna-web:latest --push .
(cd app && flutter build web --release --pwa-strategy=none --dart-define-from-file env/focus.web.json && tool/brand_web.sh focus)
docker buildx build --platform linux/arm64 -f deploy/web.Dockerfile -t ghcr.io/<owner>/focus-web:latest --push .

# On the Pi
cd /opt/lunna && docker compose pull && docker compose up -d
```

## Mobile builds

```bash
cd app
flutter build ipa --flavor lunnaProduction --dart-define-from-file env/lunna.production.json
flutter build appbundle --flavor lunnaProduction --dart-define-from-file env/lunna.production.json
flutter build ipa --flavor focusProduction --dart-define-from-file env/focus.production.json
flutter build appbundle --flavor focusProduction --dart-define-from-file env/focus.production.json
```

`env/<brand>.production.json` points `API_BASE_URL` at
`https://<brand>.pietroteruya.dev/api`; both reach the same backend.

## Brand assets

Icons, splash screens and the web icons come from `app/brands/<brand>/`;
[app/brands/README.md](./app/brands/README.md) says how to regenerate them.
