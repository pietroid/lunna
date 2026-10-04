# Setup

## 1. Neon

Create a Neon project (region **AWS São Paulo, `sa-east-1`**, next to the Pi)
with two branches:

- `main` for production;
- `dev` for local work.

Copy each branch's connection string (it ends in `?sslmode=require`). The
schema is created by the server itself: migrations in `server/drizzle/` run on
every boot.

## 2. Google OAuth

In a Google Cloud project, under **APIs & Services → Credentials**, create:

1. **Web client** (OAuth client ID, type *Web application*).
   - Authorized JavaScript origins: `https://<lunna-host>`,
     `http://localhost:5173`, `http://localhost:3000`
   - Authorized redirect URIs: `https://<lunna-host>/api/auth/callback/google`,
     `http://localhost:3000/api/auth/callback/google`
   - Keep its **client secret**; only the server gets it.
2. **iOS client**, bundle ID `com.pietroid.lunna` (and another for
   `com.pietroid.lunna.dev` if you want the dev flavor on a phone).
3. **Android client**, package `com.pietroid.lunna` with your keystore's
   SHA-1 (`.dev` likewise).

Then:

- `server/.env*`: `GOOGLE_CLIENT_IDS` is the web client first, then the
  iOS client(s), comma separated. `GOOGLE_CLIENT_SECRET` is the web client's.
- `app/env/*.json`: `GOOGLE_WEB_CLIENT_ID` and `GOOGLE_IOS_CLIENT_ID`.
- `app/ios/Flutter/GoogleSignIn.xcconfig`: the iOS client ID reversed
  (`com.googleusercontent.apps.<id>`), which is the URL scheme Google
  returns to.

## 3. Local development

```bash
# Server
cd server
cp .env.example .env.local      # fill DATABASE_URL (Neon dev), secrets, Google
npm install
npm run start:local             # http://localhost:3000/api

# App (another terminal)
cd app
cp env/dev.example.json env/dev.json
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define-from-file env/dev.json
flutter run --flavor dev --dart-define-from-file env/dev.json   # phone/simulator
```

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

- `lunna-backend`: the API on the internal network;
- `lunna-web`: nginx serving the Flutter web build and proxying `/api`.

It holds only two files, in `/opt/lunna`:

```bash
sudo mkdir -p /opt/lunna && sudo chown "$USER" /opt/lunna
# /opt/lunna/.env: the production server env (see server/.env.example):
#   DATABASE_URL=<Neon main>
#   BETTER_AUTH_URL=https://<lunna-host>
#   BETTER_AUTH_SECRET=<openssl rand -base64 32>
#   GOOGLE_CLIENT_IDS=<web>,<ios>
#   GOOGLE_CLIENT_SECRET=<web secret>
#   ALLOWED_EMAILS=you@gmail.com
#   LUNNA_TIMEZONE=America/Sao_Paulo
#   LUNNA_HTTP_PORT=8080
chmod 600 /opt/lunna/.env
```

`docker-compose.yml` is copied over by every deploy. The deploying user must
be able to run `docker` without `sudo` (`sudo usermod -aG docker $USER`).

`LUNNA_HTTP_PORT` (default `8080`) is the port `lunna-web` listens on.
Pick one nothing else on the Pi uses (Focus's nginx already holds 80).

### Cloudflare Tunnel

The same `cloudflared` tunnel that already exposes SSH for deploys gets a
public hostname for the app:

- `<lunna-host>` → `http://localhost:8080`

## 5. GitHub

`.github/workflows/deploy.yml` runs on every push to `main`: tests, builds
`lunna-backend` (ARM64 under QEMU on a standard x64 runner, which is free for
private repos) and `lunna-web` (Flutter on x64, then an ARM64 nginx image
with no emulation), pushes both to `ghcr.io/<owner>/`, then SSHes to the Pi
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
| `GOOGLE_WEB_CLIENT_ID` | `123-abc.apps.googleusercontent.com` |

### Deploying by hand

```bash
# Images, from the repo root (needs buildx and a GHCR login with write:packages)
docker buildx build --platform linux/arm64 -t ghcr.io/<owner>/lunna-backend:latest --push server
(cd app && flutter build web --release --dart-define-from-file env/production.json)
docker buildx build --platform linux/arm64 -f deploy/web.Dockerfile -t ghcr.io/<owner>/lunna-web:latest --push .

# On the Pi
cd /opt/lunna && docker compose pull && docker compose up -d
```

## Mobile builds

```bash
cd app
flutter build ipa --flavor production --dart-define-from-file env/production.json
flutter build appbundle --flavor production --dart-define-from-file env/production.json
```

`env/production.json` points `API_BASE_URL` at `https://<lunna-host>/api`.
