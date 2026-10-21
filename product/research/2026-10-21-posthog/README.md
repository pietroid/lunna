# PostHog: users, errors, replays and heatmaps

2026-10-21 · RFC · draft (Phases 1–3; deep-research pass not run)

## In one minute

**One PostHog project, fed from the server for actions and errors and from
the app for screens and replays, with every picture masked by default.**

- **Do:** report errors at the two places every failure already passes
  through (`LoggingInterceptor` on the server, the Dio interceptor in
  `api_client`), not only through autocapture, which never sees the 26
  errors the app catches itself.
- **Do:** `identify` with the user id on sign-in, on both sides, so the
  server's events (`task_done`, `plan_applied`) and the app's screens and
  replays belong to the same person.
- **Do:** turn on session replay on iOS, Android and web (canvas capture),
  with `maskAllTexts` and `maskAllImages` left on.
- **Not needed:** self-hosting (the Pi can't hold it, and the free tier
  covers one person many times over), or a heatmap tool for the phones:
  none exists for Flutter, and replay's taps answer the same question.
- **You decide:** EU or US cloud (**EU** recommended), and whether heatmaps
  are worth turning on for the web build alone (**yes**, they cost nothing).

## Ideas to keep

1. **"An error you catch is an error nobody sees."**
   PostHog, [Flutter error tracking](https://posthog.com/docs/error-tracking/installation/flutter):
   autocapture hooks `FlutterError.onError` and `PlatformDispatcher.onError`,
   and anything else goes through `captureException` "in a `catch` block".
   *For us:* `TimelineBloc._failed` turns every failure into a state
   (`timeline_bloc.dart:126`), so a broken `/timeline` shows "erro" on the
   phone and nothing in PostHog. *New*
2. **"Count an action where it happens, not where it is drawn."**
   PostHog, [Product analytics best practices](https://posthog.com/docs/product-analytics/best-practices):
   "Backend analytics are more reliable than frontend analytics", since
   browsers block trackers. *For us:* every task, plan and routine change is
   a server route, so one interceptor counts them for all three platforms.
   *New*
3. **"A Flutter replay is a stack of pictures: mask before you record."**
   PostHog, [Mobile session replay](https://posthog.com/docs/session-replay/mobile):
   Flutter "always record[s] in screenshot mode", and on the web the app is
   one canvas captured as images ([canvas recording](https://posthog.com/docs/session-replay/canvas-recording)).
   A picture can't be redacted after it leaves the phone. *For us:* titles
   and notes are the most private thing in the app; they stay masked. *New*
4. **"A heatmap needs a page of elements; Flutter paints one canvas."**
   PostHog, [Heatmaps](https://posthog.com/docs/toolbar/heatmaps): the
   clickmap "requires autocapture" and counts "actual DOM elements".
   *For us:* on Flutter web only the coordinate heatmap can work, and the
   phones have no heatmap at all. *New*

## The change

| # | Change | Fixes | Size |
|---|--------|-------|------|
| 1 | `analytics` package: one `Analytics` interface, PostHog behind it | tests and dev stay offline | S |
| 2 | Server: `posthog-node`, errors and actions from `LoggingInterceptor` | errors, track users | S |
| 3 | App: setup, `identify`, screens, errors at the Dio boundary | track users, errors | M |
| 4 | Session replay, masked, on all three platforms | screen capture | S |
| 5 | Web: snippet in `index.html`, `/ingest` proxy, heatmaps | heatmap, ad blockers | S |

### 1. One `Analytics` seam

A new `app/packages/analytics` with `abstract class Analytics { identify,
reset, screen, captureException }`, a `PostHogAnalytics` and a
`NoAnalytics`. `main.dart` picks PostHog only when the `POSTHOG_KEY` define
is set; widget tests, `preview.dart` and the demo get `NoAnalytics` and
never touch the plugin's method channel. Add `POSTHOG_KEY` and
`POSTHOG_HOST` to the four `env/*.example.json` files and to the
`env/web.json` that `deploy.yml` writes (project keys are public by design;
a repo variable is enough).

### 2. Server

`npm i posthog-node`, one `PostHog` client provided by a small
`AnalyticsModule`, `enableExceptionAutocapture: true` for what escapes
everything (the minute tick that runs `catchUp`), and `shutdown()` in
`onApplicationShutdown` (`enableShutdownHooks` is already on, `main.ts:46`).

The catching reuses `LoggingInterceptor` (`common/logging.interceptor.ts`),
which already sees every request with its user id and status:

- in `catchError`, `posthog.captureException(error, userId, { method, url,
  status })` when the status is 5xx or missing. A 4xx is the server's own
  refusal in Portuguese (`refuseOutsideWorkDay`), not a bug.
- in `tap`, one event per successful write, named from the route by a small
  table: `POST /tasks` → `task_created`, `/tasks/:id/start` →
  `task_started`, `/tasks/:id/done` → `task_done`, `/agent/plans/:id/apply` →
  `plan_applied`, and so on (PostHog's `object_action` snake case). Reads
  are not events.

PostHog ships its own `PostHogInterceptor` for Nest
([docs](https://posthog.com/docs/error-tracking/installation/nestjs)); a
second interceptor beside ours would be two code paths for one job, and
ours already has the user id.

### 3. App

`Posthog().setup(config)` in `main.dart` with `AUTO_INIT` false in
`Info.plist` and `AndroidManifest.xml`, so both brands and envs set their
key from the define. Then:

- **Identify:** `AppBloc._onUserChanged` (`app_bloc.dart:37`) calls
  `identify(userId: user.id, userProperties: {brand: AppBrand.id})` and
  `reset()` on sign-out. The id is Better Auth's user id, the same string
  the server passes as `distinctId`, so one person is one person
  ([best practices](https://posthog.com/docs/product-analytics/best-practices)
  warns that different id formats make two). No email, no name.
- **Screens:** `PosthogObserver()` in the `GoRouter`'s `observers`
  (`app.dart:22`), with a `name:` on each `GoRoute` (they have none, and
  the observer names screens after routes). Tempo, Projetos and Menu are
  one route behind an `IndexedStack` (`shell_page.dart:106`), so
  `ShellPage` calls `screen()` itself when `_index` changes.
- **Errors:** `errorTrackingConfig` with `captureFlutterErrors`,
  `capturePlatformDispatcherErrors` and `captureNativeExceptions`, keeping
  `bootstrap.dart`'s `log` too. Then the boundary: the Dio `onError` in
  `api_client.dart:93` reports a 5xx, and `AppBlocObserver.onError` reports
  what a bloc threw. A dropped network on a phone is not an error.

### 4. Session replay

`sessionReplay: true`, `sessionReplayConfig.maskAllTexts` and
`maskAllImages` left at their default `true`, and the app wrapped in
`PostHogWidget` above `MaterialApp.router`. On the web, "Canvas capture" on
in the project settings: Flutter web is one CanvasKit canvas, and since SDK
5.34.0 the same masking is painted into it before frames leave the browser
([canvas recording](https://posthog.com/docs/session-replay/canvas-recording)).
What a replay shows is the layout, the drags and where each tap lands,
which is what a bug in the timeline's gestures needs.

### 5. Web: snippet, proxy, heatmaps

`posthog_flutter` on the web is a bridge to posthog-js, and "`setup()` does
nothing on web without" its snippet in `web/index.html`
([docs](https://posthog.com/docs/libraries/flutter)). The key goes in as a
`__POSTHOG_KEY__` placeholder that `tool/brand_web.sh` fills like the
others. `api_host` is `/ingest`, which `deploy/nginx.conf` proxies to
`eu.i.posthog.com` and `/ingest/static/` to `eu-assets.i.posthog.com`
([nginx proxy](https://posthog.com/docs/advanced/proxy/nginx)), so ad
blockers see the app's own origin. `enable_heatmaps: true` in the same
snippet.

## Decisions for you

1. **Region.** **EU cloud (recommended)**: same price, data outside the
   US; US cloud; self-host (PostHog's own hobby deploy wants a far bigger
   machine than the Pi, and you'd maintain ClickHouse).
2. **One project or one per brand.** **One (recommended)**, with `brand` as
   a person and event property: one person in both apps is one row, as in
   the database. Two projects would split that person in two.
3. **Masking.** **All text and images masked (recommended)**: replays show
   shapes, not titles. Unmasking chrome (tab labels, headings) widget by
   widget later is possible; unmasking notes is not advised.
4. **Heatmaps on the web.** **On (recommended)**: free, one line, but
   coordinate-only (see Deeper); off, and rely on replays' taps.
5. **Telling people.** **One line in the landing page (recommended)**:
   sign-up is gated by `ALLOWED_EMAILS`, so everyone is known; a consent
   banner is for when the app opens to strangers.

## Decided unattended

- Wrote Phases 1–3 only; the deep-research pass waits for the person.
- Picked server-side events over client autocapture for actions (idea 2);
  client autocapture of taps does not exist for Flutter widgets anyway.
- Left the agent's model calls out of scope (PostHog has LLM analytics;
  it is a separate topic and costs nothing to add later).

## Deeper

### How it works today

```
app  catch (error) → state.failure → "erro" on screen      (26 sites)
     FlutterError.onError → dart:developer log             (bootstrap.dart:24)
     Dio onError → log                                      (api_client.dart:93)
server  LoggingInterceptor → Nest Logger (stdout on the Pi) (logging.interceptor.ts)
```

No analytics, error reporting or replay anywhere: `grep -ri
"posthog\|sentry\|crashlytics\|analytics"` over `app/` and `server/src`
finds nothing. The only record of a failure is the Pi's container log and
the phone's debug console.

### Diagnosis

| # | Symptom (the ask) | Root cause | Where |
|---|-------------------|------------|-------|
| 1 | Can't track users | no analytics SDK; the user id exists only in `AppBloc` and `req.user` | `app_bloc.dart:37`, `logging.interceptor.ts:30` |
| 2 | Can't see errors | errors are logged, never reported; 26 catch sites turn them into states | `bootstrap.dart:24`, [`data/caught-errors.txt`](./data/caught-errors.txt) (`bash code/caught-errors.sh`) |
| 3 | Autocapture alone would miss them | `TimelineBloc._failed` and friends swallow what the global handler would see | `timeline_bloc.dart:68,99,206,231,282` |
| 4 | Screens would be unnamed | `GoRoute`s carry no `name:`; three tabs are one route | `app.dart:22`, `shell_page.dart:106` |
| 5 | Web events can be blocked | the web build would call `*.posthog.com` directly | `deploy/nginx.conf` |
| 6 | No heatmap for Flutter | PostHog heatmaps are a posthog-js feature over the DOM | [heatmaps docs](https://posthog.com/docs/toolbar/heatmaps) |

Tests: none of this is tested today, and the plugin's method channel would
throw in widget tests, hence `NoAnalytics` (change 1). The server's tests
build the app without `main.ts`, so the PostHog client must be optional
(`disabled: true` when `POSTHOG_KEY` is unset).

### The literature

1. **Flutter SDK** ([docs](https://posthog.com/docs/libraries/flutter),
   [changelog](https://pub.dev/packages/posthog_flutter/changelog), 5.56.1
   today): replay on iOS, Android and web; `PosthogObserver` for go_router;
   `captureException` routes through posthog-js on web (5.28.0).
   *For us:* one package for three platforms, but the web needs the JS
   snippet too.
2. **Error tracking limits** ([docs](https://posthog.com/docs/error-tracking/installation/flutter)):
   `PlatformDispatcher` and isolate capture are not supported on the web,
   no de-obfuscation of `--obfuscate` builds, minified frames on the web
   until source maps are uploaded. *For us:* we don't obfuscate; web stacks
   need `posthog-cli` source-map upload in `deploy.yml` (a later step).
3. **Screenshot replay** ([mobile](https://posthog.com/docs/session-replay/mobile),
   [Flutter install](https://posthog.com/docs/session-replay/installation/flutter)):
   text and images masked by default, one snapshot a second
   (`throttleDelay`), and "the recording still includes where each touch
   lands". *For us:* a tap on the time picker can still reveal an hour;
   acceptable, and `captureTouches = false` exists.
4. **Canvas recording** ([docs](https://posthog.com/docs/session-replay/canvas-recording)):
   4 frames a second at quality 0.4 by default, masked regions "painted
   black … before frames are encoded". *For us:* web replays are choppier
   than phone ones; drags will look jumpy.
5. **Heatmaps** ([docs](https://posthog.com/docs/toolbar/heatmaps)): the
   heatmap records clicks and mouse moves by position; the clickmap needs
   autocapture and DOM elements; the scrollmap needs page leaves.
   *For us:* only the position heatmap can mean anything on a canvas, and
   Tempo, Projetos and Menu share one URL, so their clicks pile onto one
   map. **Inferred, not verified**: worth checking in phase 0.
6. **Backend events** ([best practices](https://posthog.com/docs/product-analytics/best-practices),
   [Node](https://posthog.com/docs/libraries/node)): backend events need
   the same `distinct_id` the front end identifies with; `flushAt` 20,
   `flushInterval` 5 s by default. *For us:* the Pi's one process batches
   fine; flush on shutdown.
7. **Pricing**: 1M events, 5K recordings and 100K exceptions a month free
   ([pricing](https://posthog.com/pricing), figures from search results;
   the split of mobile recordings is unconfirmed). *For us:* a handful of
   people stays free.

### Rollout

| Phase | Ships | Fixes | Size |
|-------|-------|-------|------|
| 0 | EU project, keys in env; check a heatmap on the Flutter web build by hand | measuring | XS |
| 1 | Server: errors and action events (change 2) | 1, 2 | S |
| 2 | App: seam, identify, screens, errors (1, 3) | 1–4 | M |
| 3 | Replay, masked (4) | screen capture | S |
| 4 | Web snippet, proxy, heatmaps; source maps in CI (5) | 5, 6 | S |

Phase 1 alone already answers "what broke, for whom", from one file.

## References

- [PostHog Flutter SDK](https://posthog.com/docs/libraries/flutter): setup, `identify`, `PosthogObserver`, web snippet, masking.
- [Flutter error tracking](https://posthog.com/docs/error-tracking/installation/flutter): autocapture options and their web limits.
- [Flutter session replay](https://posthog.com/docs/session-replay/installation/flutter): `PostHogWidget`, masking defaults, touches.
- [Mobile session replay](https://posthog.com/docs/session-replay/mobile): Flutter records screenshots only.
- [Canvas recording](https://posthog.com/docs/session-replay/canvas-recording): 4 fps, masking inside the canvas.
- [Heatmaps](https://posthog.com/docs/toolbar/heatmaps): web only, clickmap needs DOM elements.
- [Node SDK](https://posthog.com/docs/libraries/node): client options, `shutdown`, Express handlers.
- [NestJS error tracking](https://posthog.com/docs/error-tracking/installation/nestjs): `PostHogInterceptor`, `minStatusToCapture`.
- [Product analytics best practices](https://posthog.com/docs/product-analytics/best-practices): backend is more reliable; one id format; event names.
- [nginx proxy](https://posthog.com/docs/advanced/proxy/nginx): the `/static/`, `/array/` and `/` locations.
- [Pricing](https://posthog.com/pricing): free tier (numbers via search, not read on the page).
- [posthog_flutter changelog](https://pub.dev/packages/posthog_flutter/changelog): canvas masking 5.34.0, `captureTouches` 5.41.0.
