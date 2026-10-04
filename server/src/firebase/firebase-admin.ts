import { getApps, initializeApp, applicationDefault } from 'firebase-admin/app';

export function initializeFirebaseAdmin() {
  if (getApps().length > 0) {
    return;
  }

  // Use Application Default Credentials (ADC). This keeps the backend from
  // depending on .env files and makes the active service account explicit:
  //
  //   Local development: point GOOGLE_APPLICATION_CREDENTIALS to a service
  //   account key file, e.g. the dev account for the dev Firebase project.
  //
  //   Raspberry Pi: mount the service account JSON key into the container
  //   and set GOOGLE_APPLICATION_CREDENTIALS to its path. See
  //   server/docker-compose.yml for the default mount location.
  //
  //   Optional: set FIREBASE_PROJECT_ID to force a specific Firebase project
  //   when ADC cannot infer one (e.g. some local gcloud credentials).
  const options = process.env.FIREBASE_PROJECT_ID
    ? {
        projectId: process.env.FIREBASE_PROJECT_ID,
        credential: applicationDefault(),
      }
    : { credential: applicationDefault() };

  initializeApp(options);
}
