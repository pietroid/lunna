# PostHog: users, errors and replays

2026-10-21 · delivery · **draft: plan, waiting for approval** · track: plan

## 1. The prompt

From [issue #21](https://github.com/pietroid/lunna/issues/21):

> **Implement Posthog based on Research**
>
> Based on past research made by the repository, implement Posthog

The research is the RFC
[product/research/2026-10-21-posthog](../../research/2026-10-21-posthog/README.md).
Its binding decision: **US cloud, no heatmaps, no consent prompt**. The two
it left open take their recommended option here: **one project** for both
brands, and **everything masked** in replays.

## 2. The plan

**Track: plan.** Nothing in the RFC's rollout draws a new screen; the only
visible touch is one line of copy on the landing page (below). This
delivery ships **all of the RFC's rollout phases 0–4**, except the web
source-map upload in CI (phase 4's last item), which needs a personal API
key and is left for later.

### Approach

1. **Phase 0, the measuring.** One PostHog project on the US cloud. Its
   project key (public by design) goes in a repo variable `POSTHOG_KEY` and
   in the app's `env/*.json`; `POSTHOG_HOST` is `https://us.i.posthog.com`.
   The server reads the same two from its env (`server/.env.example`,
   `deploy/docker-compose.yml`, `SETUP.md`).
2. **Server** (`server/src/analytics/`): `posthog-node`, one `Analytics`
   provider in an `AnalyticsModule` (disabled when `POSTHOG_KEY` is unset,
   so tests and `start:local` stay offline), `enableExceptionAutocapture`
   for what escapes every request (the minute tick), `shutdown()` on
   `onApplicationShutdown`. `LoggingInterceptor` (built with `new` in
   `main.ts:45`) takes it as a constructor argument: `captureException`
   with `{ method, url, status }` on a 5xx or a missing status, and one
   event per successful write from a route table (`POST /tasks` →
   `task_created`, `/tasks/:id/start` → `task_started`, `/tasks/:id/done`
   → `task_done`, `/agent/plans/:id/apply` → `plan_applied`, routines,
   artifacts…). Reads and 4xx (the server's own refusals) are not events.
   The `distinctId` is `req.user.id`; no email, no name, no body.
3. **App seam** (`app/packages/analytics`): `abstract class Analytics {
   identify, reset, screen, captureException }`, `PostHogAnalytics` over
   `posthog_flutter`, `NoAnalytics`. `main.dart` picks PostHog only when the
   `POSTHOG_KEY` define is set; tests, `preview.dart` and the demo get
   `NoAnalytics` and never touch the method channel. `AUTO_INIT` false in
   `Info.plist` and `AndroidManifest.xml`; `Posthog().setup(config)` from
   the define.
4. **App wiring:** `AppBloc._onUserChanged` identifies with Better Auth's
   user id and `{brand: AppBrand.id}`, `reset()` on sign-out.
   `PosthogObserver` in the `GoRouter`, a `name:` on each `GoRoute`, and
   `ShellPage` calls `screen()` when the tab changes (three tabs, one
   route). Errors: `captureFlutterErrors`, `capturePlatformDispatcherErrors`,
   `captureNativeExceptions`, plus the Dio `onError` in `api_client` (5xx
   only, not a dropped network) and `AppBlocObserver.onError`.
5. **Replay:** `sessionReplay: true`, `maskAllTexts` and `maskAllImages`
   left on, `PostHogWidget` above `MaterialApp.router`. On the web, "Canvas
   capture" turned on in the project settings (a click in PostHog, listed
   in `SETUP.md`).
6. **Web:** the posthog-js snippet in `app/web/index.html` with a
   `__POSTHOG_KEY__` placeholder that `tool/brand_web.sh` fills, `api_host:
   '/ingest'`, `ui_host: 'https://us.posthog.com'`, no heatmaps;
   `deploy/nginx.conf` proxies `/ingest/static/` to
   `us-assets.i.posthog.com` and `/ingest/` to `us.i.posthog.com`.
   `deploy.yml` writes `POSTHOG_KEY`/`POSTHOG_HOST` into `env/web.json`.
7. **The one visible touch:** under the sign-in button on the landing page
   (`app/lib/landing/view/landing_page.dart`), one muted line from
   `app_pt.arb`: *"Registramos o uso e os erros do app para melhorá-lo.
   Textos e imagens nunca saem do seu aparelho nas gravações."* (shot in
   Phase 4 through a small preview, both brands).

### References

- [PostHog Flutter SDK](https://posthog.com/docs/libraries/flutter): `setup`, `AUTO_INIT`, `PosthogObserver`, and that `setup()` does nothing on web without the JS snippet.
- [Flutter session replay](https://posthog.com/docs/session-replay/installation/flutter): `PostHogWidget`, `maskAllTexts`/`maskAllImages` default to true.
- [Node SDK](https://posthog.com/docs/libraries/node) and [NestJS error tracking](https://posthog.com/docs/error-tracking/installation/nestjs): `captureException`, `enableExceptionAutocapture`, `shutdown()`; why we reuse our interceptor rather than add `PostHogInterceptor`.
- [nginx proxy](https://posthog.com/docs/advanced/proxy/nginx): the two US locations for `/ingest`.

The version pinned will be the current `posthog_flutter` on pub.dev at
build time (the RFC read 5.56.1; canvas masking needs ≥ 5.34.0).

### Decisions

| # | Decision | Chosen | Why |
|---|----------|--------|-----|
| 1 | Region | US cloud | RFC decision, binding |
| 2 | Projects | one for both brands, `brand` as a property | the same person in both apps is one row, as in the database (RFC, recommended) |
| 3 | Masking | all text and images | titles and notes are the most private thing in the app; a picture can't be redacted later (RFC, recommended) |
| 4 | Heatmaps | off | RFC decision; Flutter paints one canvas |
| 5 | Consent prompt | none; one informative line on the landing page | RFC decision (sign-up is by invitation); the line is not a prompt |
| 6 | Where actions are counted | the server's `LoggingInterceptor` | backend events are not ad-blocked, one place for three platforms |
| 7 | Secrets | none new: the project key is public; `POSTHOG_KEY` is a repo **variable** | PostHog project keys are meant to ship in clients |
| 8 | Left out | web source maps in CI, LLM analytics for the agent | the first needs a personal API key secret; the second is its own topic |
| 9 | Without a key | everything off (`NoAnalytics`, `disabled: true`) | tests, CI, dev and preview stay offline |

### How it will be proved

- `npm test` in `server/`: a spec of `LoggingInterceptor` with a fake
  `Analytics`, asserting a 5xx calls `captureException` with the user id, a
  4xx does not, `POST /tasks/:id/done` emits `task_done`, a `GET` emits
  nothing; and the e2e timeline specs still pass with no key.
- `flutter test` of `packages/analytics` and the app under both brands:
  `AppBloc` identifies and resets through a fake `Analytics`; the Dio
  interceptor reports a 500 and not a connection error.
- `flutter build web` + `tool/brand_web.sh lunna`: the built
  `index.html` has the key and no `__POSTHOG_` placeholder left; `nginx -t`
  on `deploy/nginx.conf` (via the `nginx` image if Docker is here).
- `flutter build apk --flavor lunnaDev` (and iOS if signing allows) to
  prove `AUTO_INIT` and the plugin compile.
- **Not provable here:** events arriving in PostHog. That needs the project
  key on a real device; section 4 will say so and list what to look for
  (a `task_done` with the person's id, a masked replay).
- `.tool/check` once at the end.

## Decided unattended

- **Track: plan.** The only visible change is one line of copy; no layout
  to approve.
- Took the RFC's recommended options on its two open decisions: one
  project, everything masked.
- Kept the landing-page line the RFC left in scope; drop it here if it is
  not wanted. Its copy is mine.
- Left the web source-map upload out (needs a personal API key secret).

## Questions

- Has the US PostHog project been created, and can its project key go in
  a repo variable `POSTHOG_KEY` (and the server's `.env` on the Pi)?
  The build works without it, but nothing is sent until it is set.

## Build brief

Phase 3 starts here (same kind of session; a plan does not split).

- **Files to write:** `server/src/analytics/` (module + provider + route
  table + spec), `server/src/common/logging.interceptor.ts`,
  `server/src/main.ts`, `server/.env.example`, `deploy/docker-compose.yml`,
  `deploy/nginx.conf`, `app/packages/analytics/` (new package, shape of
  `timeline`), `app/lib/main.dart`, `app/lib/bootstrap.dart`,
  `app/lib/app/` (`AppBloc`, router names, `PostHogWidget`),
  `app/lib/shell/` (tab screens), `app/packages/api_client` (Dio
  `onError`), `app/ios/Runner/Info.plist`,
  `app/android/app/src/main/AndroidManifest.xml`, `app/web/index.html`,
  `app/tool/brand_web.sh`, the four `app/env/*.example.json`,
  `.github/workflows/deploy.yml`, `app_pt.arb` + gen, the landing page,
  `SETUP.md`.
- **Server:** analytics off without `POSTHOG_KEY`; never send bodies,
  titles or emails; only 5xx are exceptions; only successful writes are
  events.
- **App:** no plugin call outside `PostHogAnalytics`; tests use
  `NoAnalytics` or a fake.
- **Spec:** `product/spec/analytics.md` (events table, what is never sent)
  and a short pointer section in `AGENTS.md`, plus the two folders in its
  Layout block.
- **Open question:** the project key (above).
- **Cost:** measured by the queue and written in the PR.
