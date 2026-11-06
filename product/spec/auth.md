# Auth

Better Auth runs inside the Nest server, mounted at `/api/auth/*` in
`main.ts` ahead of Nest's body parser (it reads the raw request itself).
Everything else under `/api` is Nest, protected by `SessionGuard`, which asks
Better Auth for the session behind the request and puts an `AuthUser` on it.

Google is the only way in, by two roads:

- **Web:** the OAuth redirect. `POST /api/auth/sign-in/social` (provider
  `google`) answers with Google's URL, the
  browser leaves, comes back to `/`, and from then on sends the session
  cookie. The web app is served from the same origin as the API,
  so the cookie needs no CORS.
- **iOS/Android:** the native `google_sign_in` SDK produces an ID token
  (minted for the web client, via `serverClientId`), the app posts
  it to the same route as provider `google`, and the server verifies it against `GOOGLE_CLIENT_IDS` and
  answers with a session token. The app keeps it in the Keychain/Keystore
  (`TokenStore`) and sends it as `Authorization: Bearer` (Better Auth's
  `bearer` plugin).

`ALLOWED_EMAILS` gates sign-up: an address not on it never gets a user row.
The user table carries `timeZone`, which is the zone that person's day is
measured in.

Better Auth is ESM-only and the server compiles to CommonJS. That works
because Node ≥ 22.12 can `require()` ES modules; keep the images on Node 24.
Code under test must not import `better-auth` at runtime (Jest's CommonJS
sandbox cannot load it): `session.guard.ts` imports only its type.
