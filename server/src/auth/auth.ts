import { betterAuth } from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { APIError } from 'better-auth/api';
import { bearer, genericOAuth } from 'better-auth/plugins';
import { Database } from '../db/db';
import { schema } from '../db/schema';
import { baseUrlOf } from './base-url';

/** Where Better Auth's routes live, behind the same `/api` as everything else. */
export const AUTH_BASE_PATH = '/api/auth';

/**
 * The provider Focus's web build signs in through: Google again, with
 * Focus's own client. Its callback is `/api/auth/callback/google-focus`.
 */
export const FOCUS_GOOGLE_PROVIDER = 'google-focus';

/** What the auth instance is built from. All of it comes from the env. */
export interface AuthSettings {
  /**
   * The public origins the apps are served from, e.g.
   * https://lunna.pietroteruya.dev and https://focus.pietroteruya.dev.
   *
   * One server answers for every brand, each from its own host, so each
   * signs in on its own origin: the Google redirect comes back to the host
   * it left from, and the cookie is set there. The first is the fallback for
   * a request whose host is none of these.
   */
  baseUrls: string[];
  secret: string;
  /**
   * Every Google OAuth client allowed to mint a token for these apps, from
   * any of their Google Cloud projects.
   *
   * The first is Lunna's web client, which does Lunna's redirect flow and
   * owns [googleClientSecret]. The others (Focus's web client, every iOS and
   * Android client) only ever hand the server an ID token, which is accepted
   * when its audience is any of these.
   */
  googleClientIds: string[];
  googleClientSecret: string;
  /**
   * Focus's own web client, in Focus's own Google Cloud project, so Google's
   * consent screen names Focus. Its redirect flow is the `google-focus`
   * provider. Unset, Focus's web build signs in through `google` like
   * Lunna's (as in local development, where one dev project serves both).
   */
  focusGoogle?: { clientId: string; clientSecret: string };
  /** Origins a browser may call from, beyond [baseUrls]. */
  trustedOrigins: string[];
  /** Who may sign up. Empty means anyone with a Google account. */
  allowedEmails: string[];
  /** The zone a new person's day starts in. */
  defaultTimeZone: string;
}

/**
 * Sign-in, sessions and the user table.
 *
 * Google is the only way in, for both apps, into one user table: the same
 * Google account is the same person in Focus and in Lunna. The web app goes through the redirect flow and
 * ends up with a session cookie on the same origin; the phones sign in with
 * the native Google SDK, send its ID token here, and keep the session token
 * the bearer plugin answers with.
 */
export function createAuth(db: Database, settings: AuthSettings) {
  const allowed = new Set(
    settings.allowedEmails.map((email) => email.trim().toLowerCase()),
  );

  return betterAuth({
    baseURL: baseUrlOf(settings.baseUrls),
    basePath: AUTH_BASE_PATH,
    secret: settings.secret,
    database: drizzleAdapter(db, { provider: 'pg', schema }),
    trustedOrigins: [...settings.baseUrls, ...settings.trustedOrigins],
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
        // When the working day runs, in minutes after midnight. Set from the
        // app's menu through `PATCH /api/users/me`, never at sign-up.
        dayStart: {
          type: 'number',
          required: false,
          input: false,
          defaultValue: 7 * 60,
        },
        dayEnd: {
          type: 'number',
          required: false,
          input: false,
          defaultValue: 22 * 60,
        },
      },
    },
    session: {
      // A phone stays signed in for months without asking again.
      expiresIn: 60 * 60 * 24 * 90,
      updateAge: 60 * 60 * 24,
    },
    account: {
      // One person, one user, whichever app or Google project they come in
      // through: a Google-verified email joins the account it already has.
      accountLinking: {
        enabled: true,
        trustedProviders: ['google', FOCUS_GOOGLE_PROVIDER],
      },
    },
    plugins: [
      bearer(),
      ...(settings.focusGoogle
        ? [
            genericOAuth({
              config: [
                {
                  providerId: FOCUS_GOOGLE_PROVIDER,
                  discoveryUrl:
                    'https://accounts.google.com/.well-known/openid-configuration',
                  clientId: settings.focusGoogle.clientId,
                  clientSecret: settings.focusGoogle.clientSecret,
                  scopes: ['openid', 'email', 'profile'],
                  prompt: 'select_account',
                  pkce: true,
                },
              ],
            }),
          ]
        : []),
    ],
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
                message: 'Esta conta não tem acesso.',
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

/**
 * An OAuth client from its two env values: both set, or neither. One without
 * the other is a typo in the env, so it stops the boot rather than quietly
 * falling back.
 */
export function optionalClient(
  clientId: string | undefined,
  clientSecret: string | undefined,
): { clientId: string; clientSecret: string } | undefined {
  if (!clientId && !clientSecret) return undefined;
  if (!clientId || !clientSecret) {
    throw new Error('Set both the client ID and its secret, or neither');
  }
  return { clientId, clientSecret };
}
