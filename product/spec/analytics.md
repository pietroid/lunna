# Analytics (PostHog)

Who uses the app, what they do with it, what broke, and replays of the
sessions, for both brands, in **one PostHog project on the US cloud**. The
research and its decisions are in
[product/research/2026-10-21-posthog](../research/2026-10-21-posthog/README.md);
the delivery in [product/delivery/2026-10-21-posthog](../delivery/2026-10-21-posthog/README.md).

## The rule

**Nothing a person wrote leaves for PostHog.** No title, no note, no body,
no query, no name, no email. The server sends route names and statuses; the
app sends the account id, the brand, screen names and errors; replays mask
every text, every image and everything custom-painted. **Off without a
key**: no `POSTHOG_KEY`, nothing is sent (dev, tests, CI, previews).

## Who

The account is the person: `distinctId` is Better Auth's user id, on the
server (`req.user.id`) and in the app (`AppBloc` identifies on sign-in,
with `{brand}`, and resets on sign-out). The same Google account in Focus
and in Lunna is one person, as it is one row in the database. Before
sign-in nothing makes a person profile (`identified_only`).

## The person's actions: on the server

`LoggingInterceptor` (`server/src/common/logging.interceptor.ts`) counts
each write that **succeeded** as one event, named by the route Nest
matched (`server/src/analytics/events.ts`), with `{ route, status, source:
'server' }`. Reads are not events, and neither is a refusal (a 4xx).

| Route | Event |
|-------|-------|
| `POST /tasks` | `task_created` |
| `POST /tasks/timing` | `task_guard_answered` |
| `PATCH /tasks/:id` | `task_edited` (notes autosave too) |
| `POST /tasks/:id/move` | `task_moved` |
| `POST /tasks/:id/start` · `snooze` · `done` | `task_started` · `task_snoozed` · `task_done` |
| `DELETE /tasks/:id` | `task_deleted` |
| `POST /tasks/:id/pause` · `resume` · `extend` | `task_paused` · `task_resumed` · `task_extended` |
| `POST /tasks/:id/shift` · `swap` · `resize` | `task_shifted` · `task_swapped` · `task_resized` |
| `POST /events`, `PATCH`/`DELETE /events/:id` | `event_created`, `event_edited`, `event_deleted` |
| `POST /events/:id/done` · `pause` · `resume` · `extend` · `resize` | `event_done` · `event_paused` · … |
| `POST /routines`, `PATCH`/`DELETE /routines/:id` | `routine_created`, `routine_edited`, `routine_deleted` |
| `POST /artifacts`, `PATCH`/`DELETE /artifacts/:id`, `POST /artifacts/:id/move` | `artifact_created`, `artifact_edited`, `artifact_deleted`, `artifact_moved` |
| `POST /artifacts/:id/tasks` | `artifact_task_created` |
| `POST /catalog/types`, `POST /goals`, `DELETE /goals/:id` | `catalog_type_created`, `goal_created`, `goal_deleted` |
| `POST /agent/turn` | `agent_turn` |
| `POST /agent/plans/:id/apply` · `undo` | `plan_applied` · `plan_undone` |
| `PATCH /users/me` | `settings_changed` |

A new write route gets its row in `events.ts`, or it is not counted.

## Errors

- **Server:** the interceptor reports every failure that is not a refusal
  (a 5xx, or an error with no status) with `captureException` and
  `{ method, route, status }`; `enableExceptionAutocapture` catches what
  escapes every request (the minute tick). `AnalyticsModule` flushes on
  shutdown.
- **App:** Flutter's errors, the platform dispatcher's and the native ones
  (PostHog's own handlers, after `bootstrap`'s log), every error a bloc
  throws (`AppBlocObserver.onError`), and every 5xx the API answers
  (`ApiClient.onServerError`, with method, path and status). A dropped
  network is not an error.

## Screens and replays

- Every `GoRoute` has a `name` (`Inicio`, `Evento`, `Rotina`, `Feitas`,
  `Entrada`), reported by `PosthogObserver`. The three tabs are one route,
  so `ShellPage` reports `Tempo`, `Entregas` and `Menu` itself.
- Session replay on iOS, Android and web, under `PostHogWidget`, with
  `maskAllTexts`, `maskAllImages` and `maskCustomPaint`. On the web the app
  is one canvas: canvas capture is on in the project and posthog_flutter
  paints the masks into each frame; the snippet records no frame until it
  has mounted (`maskRegionsFn: () => null`).
- No heatmaps, no autocapture, no surveys.

## Where

| Piece | Where |
|-------|-------|
| Server | `server/src/analytics/` (`Analytics`, `PostHogAnalytics`, `NoAnalytics`, the event table, `AnalyticsModule`), the interceptor |
| App | `app/packages/analytics` (`Analytics`, `PostHogAnalytics`, `NoAnalytics`, `AnalyticsScope`): **no other package calls the plugin** |
| Wiring | `app/lib/main.dart` (picks PostHog when `POSTHOG_KEY` is set), `bootstrap.dart`, `AppBloc`, `App`, `ShellPage` |
| Web | the snippet in `app/web/index.html` (key filled by `tool/brand_web.sh`), `/ingest` proxied by `deploy/nginx.conf` |
| Native | `AUTO_INIT` false in `Info.plist` and `AndroidManifest.xml`: Dart sets it up |
| Settings | `POSTHOG_KEY`, `POSTHOG_HOST` (server env, app defines, repo variable): see SETUP.md §6 |

Tests use `NoAnalytics` or a fake, never the plugin; `AnalyticsScope.of`
answers `NoAnalytics` where there is no scope.
