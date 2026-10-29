/**
 * The person's actions, one event per write that succeeded, by route. Reads
 * are not events, and neither is a refusal (a 4xx): only what changed.
 *
 * Keyed by method and the route as Nest declares it, without the global
 * prefix, so an id in the path never reaches an event name.
 *
 * Each carries `via` (`notification`, `live_activity` or `app`), from the
 * `X-Lunna-Via` header, when the app said where the answer came from ([viaOf]).
 */
const EVENTS: Record<string, string> = {
  'POST /tasks': 'task_created',
  'POST /tasks/timing': 'task_guard_answered',
  'PATCH /tasks/:id': 'task_edited',
  'POST /tasks/:id/move': 'task_moved',
  'POST /tasks/:id/start': 'task_started',
  'POST /tasks/:id/snooze': 'task_snoozed',
  'POST /tasks/:id/done': 'task_done',
  'DELETE /tasks/:id': 'task_deleted',
  'POST /tasks/:id/pause': 'task_paused',
  'POST /tasks/:id/resume': 'task_resumed',
  'POST /tasks/:id/extend': 'task_extended',
  'POST /tasks/:id/shift': 'task_shifted',
  'POST /tasks/:id/swap': 'task_swapped',
  'POST /tasks/:id/resize': 'task_resized',

  'POST /events': 'event_created',
  'PATCH /events/:id': 'event_edited',
  'POST /events/:id/start': 'event_started',
  'POST /events/:id/delay': 'event_delayed',
  'POST /events/:id/done': 'event_done',
  'DELETE /events/:id': 'event_deleted',
  'POST /events/:id/pause': 'event_paused',
  'POST /events/:id/resume': 'event_resumed',
  'POST /events/:id/extend': 'event_extended',
  'POST /events/:id/resize': 'event_resized',

  'POST /routines': 'routine_created',
  'PATCH /routines/:id': 'routine_edited',
  'DELETE /routines/:id': 'routine_deleted',

  'POST /artifacts': 'artifact_created',
  'PATCH /artifacts/:id': 'artifact_edited',
  'DELETE /artifacts/:id': 'artifact_deleted',
  'POST /artifacts/:id/move': 'artifact_moved',
  'POST /artifacts/:id/tasks': 'artifact_task_created',
  'POST /catalog/types': 'catalog_type_created',
  'POST /goals': 'goal_created',
  'PATCH /goals/:id': 'goal_edited',
  'DELETE /goals/:id': 'goal_deleted',

  'POST /agent/turn': 'agent_turn',
  'POST /agent/plans/:id/apply': 'plan_applied',
  'POST /agent/plans/:id/undo': 'plan_undone',

  'PATCH /users/me': 'settings_changed',
};

/** The route a request matched, without the `/api` prefix (`/tasks/:id`). */
export function routeOf(path: string | undefined): string | undefined {
  if (!path) return undefined;
  return path.replace(/^\/api(?=\/|$)/, '') || '/';
}

/** The event a successful `method route` is, or undefined when it is none. */
export function eventFor(
  method: string,
  route: string | undefined,
): string | undefined {
  if (!route) return undefined;
  return EVENTS[`${method.toUpperCase()} ${route}`];
}

/** The header the app names where a write came from with. */
export const VIA_HEADER = 'x-lunna-via';

/** Where a write can say it came from. */
const VIAS = ['notification', 'live_activity', 'app'] as const;

/**
 * Where a write came from, as the app said in [VIA_HEADER]: a reminder's
 * button, a button on the Lock Screen's activity, or the app itself.
 * Anything else is not recorded.
 */
export function viaOf(
  raw: string | string[] | undefined,
): (typeof VIAS)[number] | undefined {
  const value = Array.isArray(raw) ? raw[0] : raw;
  return VIAS.find((via) => via === value);
}

/**
 * Captured once for each block `catchUp` closed with nobody answering:
 * what it was and how far past its end it ran. The baseline the reminders'
 * buttons are measured against.
 */
export const SILENT_CLOSE_EVENT = 'block_closed_silently';
