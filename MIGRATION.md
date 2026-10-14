# Migration: one backend, two apps

Up to now this repo built one app, Lunna, dark, at `lunna.pietroteruya.dev`,
and the Pi also ran the old Focus (its own nginx on port 80). From now on
the repo builds both:

| | Focus | Lunna |
|---|---|---|
| Look | today's: dark, lime | the new guide's: light, red, the crescent |
| Host | `focus.pietroteruya.dev` | `lunna.pietroteruya.dev` |
| Bundle / package | `com.pietroid.focus` | `com.pietroid.lunna` (unchanged) |
| Web container | `focus-web`, port 8081 | `lunna-web`, port 8080 |

Both talk to the one `lunna-backend` and the one Neon database, so the same
Google account is the same user, with the same day, in either app. That is
also what leaves room for spaces shared between people later. Each app is
still its own product to Google: its own Google Cloud project, so Google's
sign-in screen names the app you are signing into. The old Focus is retired
and its data is not carried over.

Do the steps in order. Nothing goes live until step 6, and the old Focus
keeps serving `focus.pietroteruya.dev` until step 7.

---

## 1. Google Cloud: a Focus project

The existing **production** project (web client `1053837510772-…`) becomes
Lunna's and stays as it is; check its **OAuth consent screen** says
"Lunna".

Create a new project for Focus:

1. **console.cloud.google.com → New project**: "Focus".
2. **APIs & Services → OAuth consent screen**: app name "Focus", your
   support email, logo if you have one, user type External. While it is in
   *Testing*, add your Google account(s) as test users (or publish it).
3. **Credentials → Create credentials → OAuth client ID → Web application**:
   - Authorized JavaScript origins: `https://focus.pietroteruya.dev`
   - Authorized redirect URIs:
     `https://focus.pietroteruya.dev/api/auth/callback/google-focus`
     (note `google-focus`: Focus signs in through its own provider)
   - Copy the **client ID** and the **client secret**.

## 2. Google Cloud: phone clients for Focus

In the **Focus** project, **Credentials → Create credentials → OAuth
client ID**:

1. **iOS**, bundle ID `com.pietroid.focus`. Copy its client ID.
2. **Android**, package `com.pietroid.focus`, with the SHA-1 of the upload
   keystore (`keytool -list -v -keystore <keystore>`). The same keystore
   can sign both apps.
3. For the dev flavors on a phone, add iOS and Android clients for
   `com.pietroid.focus.dev` to the **dev** project (`861100732758-`), which
   serves both brands locally.

Then put them where the app reads them:

- `app/env/focus.production.json`: `GOOGLE_WEB_CLIENT_ID` (Focus's web
  client from step 1) and `GOOGLE_IOS_CLIENT_ID`. `GOOGLE_WEB_PROVIDER` is
  already `google-focus`. Likewise `focus.dev.json`, with the dev project's
  iOS client.
- `app/ios/Flutter/GoogleSignIn.xcconfig`: replace
  `YOUR_FOCUS_PRODUCTION_IOS_CLIENT` (and `YOUR_FOCUS_DEV_IOS_CLIENT`) with
  the reversed ID, i.e. what comes after `com.googleusercontent.apps.` in
  the client's "iOS URL scheme". Commit this file.

## 3. Apple and Google Play: register Focus

The app records are new, since the bundle ID is.

1. **developer.apple.com → Identifiers**: register `com.pietroid.focus`
   (and `com.pietroid.focus.dev`), with the same capabilities as
   `com.pietroid.lunna`.
2. **App Store Connect → Apps → +**: a new app "Focus", bundle ID
   `com.pietroid.focus`, primary language Portuguese (Brazil).
3. **Play Console → Create app**: "Focus", package `com.pietroid.focus`.

Lunna's records stay as they are. Its icon, splash and look change with the
next build it ships.

## 4. The Pi: free port 80 and stop nothing yet

SSH to the Pi and look at what the old Focus runs:

```bash
docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Image}}'
```

Leave it running for now. Note its compose directory (`docker inspect
<container> --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}'`),
since step 7 stops it from there.

## 5. The Pi: the new environment

Edit `/opt/lunna/.env`:

```bash
# Both origins, the fallback first. Better Auth answers each request on its
# own host, so a sign-in on focus. comes back to focus.
BETTER_AUTH_URL=https://lunna.pietroteruya.dev,https://focus.pietroteruya.dev

# Every client whose ID tokens the server accepts, from both projects:
# Lunna's web client first (it stays the one with GOOGLE_CLIENT_SECRET),
# then Focus's web client, then each iOS client.
GOOGLE_CLIENT_IDS=<lunna web>,<focus web>,<lunna ios>,<focus ios>

# Focus's web client from step 1: the google-focus provider.
FOCUS_GOOGLE_CLIENT_ID=<focus web>
FOCUS_GOOGLE_CLIENT_SECRET=<focus web secret>

# The port focus-web listens on; 8081 unless something already has it.
FOCUS_HTTP_PORT=8081
```

Leave `DATABASE_URL`, `BETTER_AUTH_SECRET`, `GOOGLE_CLIENT_SECRET`,
`ALLOWED_EMAILS` and `LUNNA_HTTP_PORT` alone. `ALLOWED_EMAILS` now gates both
apps.

Check port 8081 is free: `ss -ltn | grep 8081` should print nothing.

## 6. Deploy

Merge to `main` (or run the **Deploy** workflow by hand). It now:

- tests the app under both brands;
- builds `lunna-backend`, `lunna-web` and `focus-web`;
- copies the new `docker-compose.yml` to the Pi and starts all three.

After it is green, on the Pi:

```bash
cd /opt/lunna && docker compose ps          # three containers, all up
curl -s localhost:8080 | grep '<title>'      # <title>Lunna</title>
curl -s localhost:8081 | grep '<title>'      # <title>Focus</title>
curl -s -o /dev/null -w '%{http_code}\n' localhost:8081/api/timeline   # 401: the backend answered
```

The first push creates the `focus-web` package on GHCR as **private**;
check it under your profile → Packages, as for the other two.

`https://lunna.pietroteruya.dev` now shows the new light Lunna. Sign in
there to check that auth still works with the list in `BETTER_AUTH_URL`.

## 7. Cloudflare: point `focus.` at the new container, retire the old Focus

In **Cloudflare Zero Trust → Networks → Tunnels → (the Pi's tunnel) →
Public Hostnames**:

1. Edit `focus.pietroteruya.dev`: service `http://localhost:8081` (it was
   the old Focus, probably `http://localhost:80`). If it does not exist
   yet, add it.
2. Leave `lunna.pietroteruya.dev → http://localhost:8080` as it is.

Open `https://focus.pietroteruya.dev` and sign in with Google. The
consent screen should say **Focus**, and the day should be the one Lunna
shows: the same Google account is the same user.

Then stop the old Focus, from the directory found in step 4:

```bash
cd <old focus dir> && docker compose down
docker image prune -f
```

Port 80 is free from now on. Remove the old Focus's files and its GHCR
packages when you are sure you do not need them.

## 8. Phones

```bash
cd app
cp env/focus.production.example.json env/focus.production.json   # if not there yet; fill it
flutter build ipa --flavor focusProduction --dart-define-from-file env/focus.production.json
flutter build appbundle --flavor focusProduction --dart-define-from-file env/focus.production.json
flutter build ipa --flavor lunnaProduction --dart-define-from-file env/lunna.production.json
flutter build appbundle --flavor lunnaProduction --dart-define-from-file env/lunna.production.json
```

Upload each to its own App Store Connect / Play Console record. Signing on
iOS is automatic with team `K3U55XXNRM`; Xcode creates the Focus profiles
the first time it sees the bundle ID.

The installed Lunna app updates in place (same bundle ID). The old Focus
app, if it is on a phone, is a different app; delete it.

## 9. Checklist

- [ ] Focus Google project with its consent screen and web client
      (redirect `…/api/auth/callback/google-focus`)
- [ ] Focus iOS client(s) created; IDs in `env/focus.*.json` and
      `GoogleSignIn.xcconfig`; Focus web client ID in
      `env/focus.production.json`
- [ ] Focus Android client(s) created with the keystore SHA-1
- [ ] `com.pietroid.focus` registered at Apple, app records on both stores
- [ ] `/opt/lunna/.env`: `BETTER_AUTH_URL` lists both, `GOOGLE_CLIENT_IDS`
      has Focus's web and iOS clients, `FOCUS_GOOGLE_CLIENT_ID`/`_SECRET`
      and `FOCUS_HTTP_PORT` set
- [ ] GitHub variable `GOOGLE_WEB_CLIENT_ID` deleted (no longer read)
- [ ] Deploy green; three containers up; `focus-web` package private
- [ ] Tunnel: `focus.` → 8081, `lunna.` → 8080; sign-in works on both
- [ ] Old Focus stopped and pruned
- [ ] Store builds uploaded for both brands
