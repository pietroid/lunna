import { betterAuth } from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { APIError } from 'better-auth/api';
import { bearer } from 'better-auth/plugins';
import { Database } from '../db/db';
import { schema } from '../db/schema';

/** Where Better Auth's routes live, behind the same `/api` as everything else. */
export const AUTH_BASE_PATH = '/api/auth';

/** What the auth instance is built from. All of it comes from the env. */
export interface AuthSettings {
  /** The public origin the app is served from, e.g. https://lunna.example. */
  baseUrl: string;
  secret: string;
  /**
   * Every Google OAuth client allowed to mint a token for this app.
   *
   * The first is the web client, which also does the redirect flow and owns
   * [googleClientSecret]. The others (iOS, Android) only ever hand the server
   * an ID token, which is accepted when its audience is any of these.
   */
  googleClientIds: string[];
  googleClientSecret: string;
  /** Origins a browser may call from, beyond [baseUrl]. */
  trustedOrigins: string[];
  /** Who may sign up. Empty means anyone with a Google account. */
  allowedEmails: string[];
  /** The zone a new person's day starts in. */
  defaultTimeZone: string;
}

/**
 * Sign-in, sessions and the user table.
 *
 * Google is the only way in. The web app goes through the redirect flow and
 * ends up with a session cookie on the same origin; the phones sign in with
 * the native Google SDK, send its ID token here, and keep the session token
 * the bearer plugin answers with.
 */
export function createAuth(db: Database, settings: AuthSettings) {
  const allowed = new Set(
    settings.allowedEmails.map((email) => email.trim().toLowerCase()),
  );

  return betterAuth({
    baseURL: settings.baseUrl,
    basePath: AUTH_BASE_PATH,
    secret: settings.secret,
    database: drizzleAdapter(db, { provider: 'pg', schema }),
    trustedOrigins: [settings.baseUrl, ...settings.trustedOrigins],
    socialProviders: {
      google: {
        clientId: settings.googleClientIds,
        clientSecret: settings.googleClientSecret,
        prompt: 'select_account',
      },
    },
    user: {
      additionalFields: {
        timeZone: {
          type: 'string',
          required: false,
          input: false,
          defaultValue: settings.defaultTimeZone,
        },
      },
    },
    session: {
      // A phone stays signed in for months without asking again.
      expiresIn: 60 * 60 * 24 * 90,
      updateAge: 60 * 60 * 24,
    },
    plugins: [bearer()],
    databaseHooks: {
      user: {
        create: {
          // A personal app: an address that is not on the list never gets a
          // row, so it never gets a session either.
          before: (candidate) => {
            if (
              allowed.size > 0 &&
              !allowed.has(candidate.email.trim().toLowerCase())
            ) {
              throw new APIError('FORBIDDEN', {
                message: 'Esta conta não tem acesso ao Lunna.',
              });
            }

            return Promise.resolve({ data: candidate });
          },
        },
      },
    },
  });
}

export type Auth = ReturnType<typeof createAuth>;

/** Comma-separated env values, blanks dropped. */
export function listOf(value: string | undefined): string[] {
  return (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter((item) => item !== '');
}
