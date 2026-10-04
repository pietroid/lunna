# Project Setup

## 1. Package and App Name

Already configured for Focus:

- Dart package: `focus`
- Android/iOS bundle ID: `com.pietroid.focus` (production), `com.pietroid.focus.dev` (dev)
- App display name: `Focus`

## 2. Icon and Splash Screen

- Replace the icon in `app/assets/launch_icon/icon.png` with your app icon.
- Run `dart run flutter_launcher_icons` to generate the app icons for Android and iOS.
- Run `dart run flutter_native_splash:create` to generate the splash screen for Android and iOS.

## 3. Firebase

This project is pre-wired for **production** and **dev** Firebase flavors.
Local development uses the dev project (`focus-local-dev`) with a localhost backend.
The production Firebase project is `focus-production`.

### 3.1. Firebase Project

- Production project: `focus-production` (already created).
- Local development uses the dev project (`focus-local-dev`) with a localhost backend.

### 3.2. Firestore Database

- Create a [Cloud Firestore database](https://firebase.google.com/docs/firestore/quickstart#create) in **Native mode** for `focus-production`.
- Firestore is accessed from the **backend only**. The Flutter app talks to the NestJS API, which reads and writes Firestore documents.
- Start in **test mode** for initial setup, then lock down with [Security Rules](https://firebase.google.com/docs/firestore/security/get-started).

### 3.3. Firebase Auth

- Enable [Firebase Auth](https://firebase.google.com/docs/auth) and turn on the **Google** sign-in provider in `focus-production`.

### 3.4. Google Sign-In Setup

The app uses the [`google_sign_in`](https://pub.dev/packages/google_sign_in) plugin.

#### Web Client ID

1. In the [Google Cloud Credentials page](https://console.cloud.google.com/apis/credentials), open the `focus-production` project.
2. Find the **Web client** OAuth 2.0 Client ID and copy its Client ID.
3. Paste it into `app/env/production.json` as `GOOGLE_SIGN_IN_CLIENT_ID`.
4. Copy `app/env/dev.example.json` to `app/env/dev.json` and paste the dev Web client ID into `GOOGLE_SIGN_IN_CLIENT_ID`.
5. Add authorized origins:
   - `http://localhost:7357` for local development.
   - Your production domain once the Pi has a hostname.
6. Enable the [People API](https://console.cloud.google.com/apis/library/people.googleapis.com) in `focus-production` and `focus-local-dev`. `google_sign_in` uses it to fetch the user's profile.

#### Android / iOS

Run the FlutterFire helper (see 3.6) after creating the apps in Firebase. The helper uses the bundle/package IDs:

- Production: `com.pietroid.focus`
- Dev: `com.pietroid.focus.dev`

### 3.5. SHA-1 for Android

- Follow https://developers.google.com/android/guides/client-auth to extract the SHA-1 fingerprint for your debug and release keystores.
- Add the SHA-1 fingerprints to the Android app in `focus-production`.

### 3.6. Install CLI Tools

- Install the [Firebase CLI](https://firebase.google.com/docs/cli#setup_update_cli)
- Activate the FlutterFire CLI:

  ```bash
  dart pub global activate flutterfire_cli
  ```

- Login to Firebase:

  ```bash
  firebase login
  ```

### 3.7. Generate Firebase Config Files

Make sure `app/env/production.json` and `app/env/dev.json` have the correct `PROJECT_ID` values, then run the helper script from the `app` directory:

```bash
cd app
./update_firebase_config.sh
```

This regenerates:

- `lib/firebase_options_production.dart`
- `lib/firebase_options_dev.dart` (used by the dev build)
- `android/app/src/production/google-services.json`
- `android/app/src/dev/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `ios/Runner/GoogleService-Info-Dev.plist`

> `lib/firebase_options_production.dart` and `lib/firebase_options_dev.dart` are tracked in the repository. The remaining generated files are gitignored and must be regenerated before the app can talk to Firebase.

### 3.8. iOS URL Schemes

After running `./update_firebase_config.sh`, verify that the `CFBundleURLSchemes` entries in `ios/Runner/Info.plist` match the `REVERSED_CLIENT_ID` values in:

- `ios/Runner/GoogleService-Info.plist`
- `ios/Runner/GoogleService-Info-Dev.plist`

Update them if they change. Remove any stale development URL scheme if present.

## 4. Backend API

The Flutter app communicates with the NestJS backend via the `api_client` package.

### 4.1. API Base URL

The backend URL is read from the environment files:

- `app/env/dev.json` — dev backend URL (`http://localhost:3001`), uses dev Firebase
- `app/env/production.json` — production backend URL on the Pi

Update `API_BASE_URL` in `app/env/production.json` once the Pi hostname is known, e.g.:

```json
{
  "API_BASE_URL": "http://your-pi-hostname:3000"
}
```

Use the VS Code launch targets to run the app with the correct environment file:

- **App - Dev** uses `env/dev.json` (dev Firebase + localhost backend)
- **App - Production** uses `env/production.json`

### 4.2. Backend Service Accounts

The backend uses the Firebase Admin SDK to verify tokens and write to Firestore.
On Cloud Run this uses workload identity; on the Pi we use a **service account JSON key**.

> **Security:** the JSON key is a secret. It must never be committed to the repo. The deploy scripts expect it to live outside the project directory.

#### Create the production service account

```bash
cd app
./create-backend-account.sh --env-file env/production.json
```

This creates `focus-backend@focus-production.iam.gserviceaccount.com` with the required Firebase Admin and Firestore roles.

#### Download the JSON key

Run the command printed by the script, or:

```bash
gcloud iam service-accounts keys create ~/keys/focus-backend-prod.json \
  --project=focus-production \
  --iam-account=focus-backend@focus-production.iam.gserviceaccount.com
```

Save the key **outside the repo** (e.g. `~/keys/focus-backend-prod.json`).

Repeat for the dev project (`focus-local-dev`) and save the key as `~/.config/focus/focus-backend-dev.json`.

#### Running locally

Local development uses the `focus-local-dev` Firebase project. Create `server/.env.local` (gitignored) with the dev service account key:

```bash
cp server/.env.example server/.env.local
# Edit GOOGLE_APPLICATION_CREDENTIALS to point to ~/.config/focus/focus-backend-dev.json.
```

Then:

```bash
cd server
npm install
npm run start:local
```

The backend will pick the service account via Application Default Credentials.

### 4.3. Run the backend locally

```bash
cd server
npm install
npm run start:local
```

The backend runs on `http://localhost:3000` and points at the `focus-local-dev` Firebase project.

## 5. Deploy to Raspberry Pi

The backend runs on the Pi as a Docker container managed by Docker Compose.

### 5.1. Pi Prerequisites

- Raspberry Pi with Docker and Docker Compose installed.
- SSH access from your development machine.
- The service account key placed on the Pi at:

  ```
  /opt/focus/secrets/focus-backend-prod.json
  ```

  Create the directory and copy the key securely:

  ```bash
  ssh pi@your-pi-hostname "sudo mkdir -p /opt/focus/secrets"
  scp ~/keys/focus-backend-prod.json pi@your-pi-hostname:/tmp/
  ssh pi@your-pi-hostname "sudo mv /tmp/focus-backend-prod.json /opt/focus/secrets/ && sudo chmod 600 /opt/focus/secrets/focus-backend-prod.json"
  ```

### 5.2. Deploy

Run this directly on the Raspberry Pi from the `server` directory:

```bash
cd server
npm run deploy:prod
```

This pulls the latest code, builds the Docker image natively on the Pi, and starts the container on port `3000`.

### 5.3. Update the app

After deploying, update `app/env/production.json` with the Pi URL:

```json
{
  "API_BASE_URL": "http://your-pi-hostname:3000"
}
```

If you add a domain + HTTPS later, change it to `https://your-domain`.

### 5.4. HTTPS / Let's Encrypt

The current setup uses HTTP on port 3000. When you are ready:

1. Point a domain at the Pi.
2. Add a reverse proxy (Caddy is easiest on a Pi) that terminates TLS.
3. Update `API_BASE_URL` to `https://your-domain`.
4. Add the production domain to the Google Sign-In authorized origins.

## 6. Notes

- `app/env/dev.json`, `app/env/production.json` and `app/env/*.local.json` are gitignored because they contain real backend URLs and Google client IDs.
- Use `app/env/dev.example.json` and `app/env/production.example.json` as templates.
- All server/agent `.env.*.local` files and service-account JSON keys are gitignored.
