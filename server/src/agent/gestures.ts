import { ConfigService } from '@nestjs/config';
import {
  ArtifactStore,
  MemoryArtifactStore,
} from '../artifacts/artifact.store';
import {
  Artifact,
  CatalogCategory,
  CatalogType,
  Goal,
  StoredRow,
} from '../artifacts/artifact.types';
import { ArtifactsService } from '../artifacts/artifacts.service';
import { CalendarService } from '../calendar/calendar.service';
import { MemoryCalendarStore } from '../calendar/calendar.store';
import { CalendarRoutine, CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { EventLayoutService } from '../events/event-layout.service';
import { Day, TimelineService } from '../events/timeline.service';
import { MemoryTaskStore, TaskStore } from '../tasks/task.store';
import { RoutinesService } from '../routines/routines.service';
import { Task } from '../tasks/task.types';
import { DEFAULT_WORK_DAY } from '../time/work-hours';
import { addDaysIn } from '../time/zone';
import type { UsersService } from '../users/users.service';
import { actionOf } from './actions';
import { HORIZON_DAYS } from './board';
import { MemoryRhythmStore } from '../rhythm/rhythm.store';
import { RhythmService } from '../rhythm/rhythm.service';
import { Gesture, Row, Undo } from './plan';

/**
 * What a gesture is made with: the person's own day, or a sandbox copy of
 * it. The same code runs on both, so a plan that held in the dry run is the
 * plan Aplicar makes.
 */
export interface Hands {
  timeline: TimelineService;
  layout: EventLayoutService;
  calendar: CalendarService;
  tasks: TaskStore;
  artifacts: ArtifactStore;
  /** Entregas' own service: the deliveries, the catalogue, the goals. */
  deliveries: ArtifactsService;
  /** Rotina's own service. */
  routines: RoutinesService;
  /** Where the working day is kept: the menu's own service. */
  users: WorkDays;
  /** Ciclo and Folgas' own service. */
  rhythm: RhythmService;
}

/** What sets a person's working day: `UsersService`, or nothing in a sandbox. */
export type WorkDays = Pick<UsersService, 'setWorkDay'>;

/** A working day kept nowhere: the sandbox's, and the tests'. */
export const NO_WORK_DAYS: WorkDays = {
  setWorkDay: () => Promise.resolve(),
};

/** Everything a turn read, which a sandbox is seeded with. */
export interface Seed {
  day: Day;
  artifacts: Artifact[];
  /** Every task of a delivery, done ones included. */
  artifactTasks: Task[];
  categories: CatalogCategory[];
  types: CatalogType[];
  goals: Goal[];
  /** Every routine. */
  routines: CalendarRoutine[];
}

/** The ids the plan's own new things were given, by the name it gave them. */
export type Made = Map<string, string>;

/**
 * A throwaway copy of the rows a turn read: the same layout and the same
 * Entregas, over memory stores seeded with them. Nothing made here reaches
 * the database or the calendar's cache.
 *
 * Routines are left out unless [routines] (a plan that writes or changes
 * one): their days within reach are already rows, and the copy never reads
 * further than the real day did. With them, a day of a routine is seeded
 * under its occurrence, so a read does not write it twice.
 */
export function sandbox(
  user: CalendarUser,
  seed: Seed,
  routines = false,
): Hands {
  const { day } = seed;
  const events = new MemoryCalendarStore();
  for (const event of day.events) {
    events.seed(
      user,
      event,
      routines && event.routineId !== undefined
        ? `${event.routineId}@${event.startTime}`
        : undefined,
    );
  }
  if (routines) {
    for (const routine of seed.routines) events.seedRoutine(user, routine);
  }
  const tasks = new MemoryTaskStore();
  for (const task of [...day.tasks, ...day.backlog, ...seed.artifactTasks]) {
    tasks.seed(user, task);
  }
  const artifacts = new MemoryArtifactStore();
  const rows: StoredRow[] = [
    ...seed.categories.map((row) => ({ kind: 'category' as const, row })),
    ...seed.types.map((row) => ({ kind: 'type' as const, row })),
    ...seed.artifacts.map((row) => ({ kind: 'artifact' as const, row })),
    ...seed.goals.map((row) => ({ kind: 'goal' as const, row })),
  ];
  for (const row of rows) void artifacts.revive(user, row);

  const calendar = new CalendarService(
    events,
    new ConfigService({ LUNNA_TIMEZONE: day.zone }),
  );
  // The day's kinds as the real day read them: a copy with none where the
  // real one had none, so the dry run lays the queue out the same way.
  const rhythm = new MemoryRhythmStore();
  if (day.rhythm !== undefined) rhythm.seed(user, day.rhythm);
  const timeline = new TimelineService(
    calendar,
    tasks,
    undefined,
    day.rhythm === undefined ? undefined : rhythm,
  );
  return handsOver(
    calendar,
    tasks,
    artifacts,
    timeline,
    undefined,
    NO_WORK_DAYS,
    new RhythmService(rhythm),
  );
}

/** The services a gesture is made with, over these stores. */
export function handsOver(
  calendar: CalendarService,
  tasks: TaskStore,
  artifacts: ArtifactStore,
  timeline = new TimelineService(calendar, tasks),
  layout = new EventLayoutService(timeline, calendar, tasks, artifacts),
  users: WorkDays = NO_WORK_DAYS,
  rhythm = new RhythmService(new MemoryRhythmStore()),
): Hands {
  return {
    timeline,
    layout,
    calendar,
    tasks,
    artifacts,
    deliveries: new ArtifactsService(artifacts, tasks, timeline, layout),
    routines: new RoutinesService(calendar),
    users,
    rhythm,
  };
}

/**
 * Makes [gesture] with [hands], through the action that declares it.
 * Answers the id of what it made or changed; a new thing named with `as` is
 * written into [made], for the changes after it.
 */
export function make(
  hands: Hands,
  user: CalendarUser,
  gesture: Gesture,
  made: Made,
  trace: Trace,
  now: Date,
): Promise<string> {
  const action = actionOf(gesture.do);
  if (action?.make === undefined) {
    throw new Error(`Nothing makes "${gesture.do}"`);
  }
  return action.make(hands, user, gesture, made, trace, now);
}

/**
 * Every row a plan can touch, as it is: the tasks still to do and every
 * task of a delivery, the events in reach, the deliveries, the catalogue
 * and the goals. Read before and after a plan, it is what undoing it puts
 * back.
 */
export interface Snapshot {
  rows: Map<string, Row>;
}

export async function snapshot(
  hands: Hands,
  user: CalendarUser,
  now: Date,
): Promise<Snapshot> {
  const zone = hands.timeline.zone(user);
  const [
    pending,
    ofArtifacts,
    events,
    artifacts,
    categories,
    types,
    goals,
    routines,
  ] = await Promise.all([
    hands.tasks.pending(user),
    hands.tasks.ofArtifacts(user),
    hands.calendar.between(
      user,
      addDaysIn(now, -1, zone),
      addDaysIn(now, HORIZON_DAYS + 1, zone),
    ),
    hands.artifacts.list(user),
    hands.artifacts.categories(user),
    hands.artifacts.types(user),
    hands.artifacts.goals(user),
    hands.calendar.routines(user),
  ]);

  const rows = new Map<string, Row>();
  const keep = (it: Row) => rows.set(`${it.kind}:${it.row.id}`, it);
  for (const row of [...pending, ...ofArtifacts]) keep({ kind: 'task', row });
  for (const row of events) keep({ kind: 'event', row });
  for (const row of artifacts) keep({ kind: 'artifact', row });
  for (const row of categories) keep({ kind: 'category', row });
  for (const row of types) keep({ kind: 'type', row });
  for (const row of goals) keep({ kind: 'goal', row });
  for (const row of routines) keep({ kind: 'routine', row });
  const workDay = user.workDay ?? DEFAULT_WORK_DAY;
  keep({ kind: 'workDay', row: { id: user.id, ...workDay } });
  const rhythm = await hands.rhythm.read(user);
  keep({ kind: 'rhythm', row: { id: user.id, ...rhythm } });

  return { rows };
}

/**
 * How to go from [after] back to [before]: each row that changed or went
 * written back as it was, each row that came taken out. A day of a routine
 * that came is left: reading further wrote it, not the plan, and the next
 * read would write it again. The days of a routine the plan wrote or
 * changed are left both ways: putting the routine back (or taking it out)
 * drops its days not begun, and the next read writes them as it was.
 */
export function undoOf(before: Snapshot, after: Snapshot): Undo[] {
  const changed = new Set<string>();
  for (const [key, it] of after.rows) {
    if (it.kind !== 'routine') continue;
    const was = before.rows.get(key);
    if (was === undefined || !same(was.row, it.row)) changed.add(it.row.id);
  }
  const ofChanged = (it: Row) =>
    it.kind === 'event' &&
    it.row.routineId !== undefined &&
    changed.has(it.row.routineId);

  const undo: Undo[] = [];
  for (const [key, it] of before.rows) {
    if (ofChanged(it)) continue;
    const now = after.rows.get(key);
    if (now === undefined || !same(now.row, it.row)) {
      undo.push({ op: 'put', it });
    }
  }
  for (const [key, it] of after.rows) {
    if (before.rows.has(key)) continue;
    if ('routineId' in it.row && it.row.routineId !== undefined) continue;
    undo.push({ op: 'drop', it });
  }

  return undo;
}

/**
 * Undoes [undo] with [hands]: what the plan made is taken out (the events
 * and tasks first, since they point at deliveries), what it changed or took
 * away written back (shelves before kinds before deliveries before tasks
 * before events, then routines, whose days not begun go with them, and the
 * working day), and the deliveries, kinds and shelves it made last.
 */
export async function takeBack(
  hands: Hands,
  user: CalendarUser,
  undo: Undo[],
  now = new Date(),
): Promise<void> {
  const of = (op: Undo['op'], kinds: Row['kind'][]) =>
    kinds.flatMap((kind) =>
      undo.filter((it) => it.op === op && it.it.kind === kind),
    );

  for (const step of of('drop', ['event', 'task', 'routine']))
    await drop(hands, user, step.it, now);
  for (const step of of('put', [
    'category',
    'type',
    'artifact',
    'goal',
    'task',
    'event',
    'routine',
    'workDay',
    'rhythm',
  ])) {
    await put(hands, user, step.it, now);
  }
  for (const step of of('drop', ['goal', 'artifact', 'type', 'category'])) {
    await drop(hands, user, step.it, now);
  }
}

/** Makes [it] be as it is: written back over the row, or revived. */
async function put(
  hands: Hands,
  user: CalendarUser,
  it: Row,
  now: Date,
): Promise<void> {
  switch (it.kind) {
    case 'routine': {
      const { title, startTime, endTime, days, checklist } = it.row;
      await hands.calendar.updateRoutine(
        user,
        it.row.id,
        { title, startTime, endTime, days, checklist, fixed: true },
        now,
      );
      return;
    }
    case 'rhythm': {
      const { cycle, rest, daysOff } = it.row;
      await hands.rhythm.restore(user, {
        rest,
        daysOff,
        ...(cycle === undefined ? {} : { cycle }),
      });
      return;
    }
    case 'workDay': {
      const day = { start: it.row.start, end: it.row.end };
      await hands.users.setWorkDay(user.id, day);
      user.workDay = day;
      return;
    }
    case 'task':
      if ((await hands.tasks.get(user, it.row.id)) !== undefined) {
        await hands.tasks.update(user, it.row);
      } else {
        await hands.tasks.revive(user, it.row);
      }
      return;
    case 'event':
      if ((await hands.calendar.find(user, it.row.id)) !== undefined) {
        await hands.calendar.save(user, it.row);
      } else {
        await hands.calendar.revive(user, it.row);
      }
      return;
    case 'artifact':
      if ((await hands.artifacts.get(user, it.row.id)) !== undefined) {
        await hands.artifacts.update(user, it.row);
      } else {
        await hands.artifacts.revive(user, it);
      }
      return;
    case 'goal':
      if ((await hands.artifacts.goals(user)).some((g) => g.id === it.row.id)) {
        const { target, deadline } = it.row;
        await hands.artifacts.updateGoal(user, it.row.id, { target, deadline });
      } else {
        await hands.artifacts.revive(user, it);
      }
      return;
    default:
      // Shelves and kinds are never edited, only made and removed.
      await hands.artifacts.revive(user, it);
  }
}

/** Takes out [it], which the plan made. */
async function drop(
  hands: Hands,
  user: CalendarUser,
  it: Row,
  now: Date,
): Promise<void> {
  switch (it.kind) {
    case 'routine':
      await hands.calendar.removeRoutine(user, it.row.id, now);
      return;
    case 'workDay':
    case 'rhythm':
      // Never made, only changed.
      return;
    case 'task':
      return hands.tasks.remove(user, it.row.id);
    case 'event':
      return hands.calendar.remove(user, it.row);
    case 'artifact':
      return hands.artifacts.remove(user, it.row.id);
    case 'goal':
      return hands.artifacts.removeGoal(user, it.row.id);
    case 'type':
      return hands.artifacts.removeType(user, it.row.id);
    case 'category':
      return hands.artifacts.removeCategory(user, it.row.id);
  }
}

/** Whether two rows say the same, whatever order their fields are in. */
function same(a: object, b: object): boolean {
  return stable(a) === stable(b);
}

function stable(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stable).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, it]) => it !== undefined)
      .sort(([a], [b]) => a.localeCompare(b));
    return `{${entries.map(([k, it]) => `${JSON.stringify(k)}:${stable(it)}`).join(',')}}`;
  }
  return JSON.stringify(value);
}
