/**
 * Does the queue need the minute tick to keep its hours right?
 *
 * Builds three copies of the same day over in-process Postgres (PGlite): one
 * person, four queued tasks, a flexible and a fixed routine; "Email" begun at
 * 09:00 and paused at 09:20, and left paused. Then lets the clock run to
 * 23:00 and, every 30 minutes, reads the day the app would get from each:
 *
 *   tick   today: catchUp every minute, and catchUp before the read
 *   read   the proposal: no tick, catchUp before the read
 *   fixed  the proposal with catchUp's one-line fix: a paused block is never
 *          "over" (its end is always now plus what it owes)
 *   bare   no tick and no catchUp: only TimelineService.day
 *
 * and compares every card's hour, by title. Also counts the rows each one
 * wrote, and when.
 *
 *   cd server && NODE_PATH=$PWD/node_modules npx tsx ../product/research/2026-10-23-neon-compute/code/tick-vs-read.ts
 *
 * Writes data/tick-vs-read.json next to this folder.
 */
import * as fs from 'fs';
import * as path from 'path';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import type { Database } from '../../../../server/src/db/db';
import { schema, user } from '../../../../server/src/db/schema';
import { PgCalendarStore } from '../../../../server/src/calendar/pg-calendar.store';
import { CalendarService } from '../../../../server/src/calendar/calendar.service';
import { PgTaskStore } from '../../../../server/src/tasks/pg-task.store';
import { PgArtifactStore } from '../../../../server/src/artifacts/pg-artifact.store';
import { TimelineService } from '../../../../server/src/events/timeline.service';
import { EventLayoutService } from '../../../../server/src/events/event-layout.service';
import { Trace } from '../../../../server/src/common/trace';
import type { CalendarEvent, CalendarUser } from '../../../../server/src/calendar/calendar.types';
import { isMissed } from '../../../../server/src/events/timeline.service';
import { DEFAULT_WORK_DAY } from '../../../../server/src/time/work-hours';

/**
 * catchUp as it is in event-layout.service.ts, with one change: the tasks
 * whose hour ran out are found after the paused ends were moved, so a paused
 * block nobody read for a while is not taken for finished.
 */
class FixedLayout extends EventLayoutService {
  override async catchUp(user: CalendarUser, trace: Trace, now = new Date()) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const self = this as any;
    const events: CalendarEvent[] = await self._calendar.events(user, undefined, now);
    for (const event of events) {
      if (!event.managed || event.pausedAt === undefined) continue;
      const end = new Date(now.getTime() + (event.remainingSeconds ?? 0) * 1000);
      if (end.getSeconds() !== 0 || end.getMilliseconds() !== 0) end.setSeconds(60, 0);
      if (end.getTime() === Date.parse(event.endTime)) continue;
      await self._revise(user, event, { endTime: end.toISOString() }, trace);
      event.endTime = end.toISOString(); // the fix
    }
    const over = events.filter(
      (e) => e.taskId !== undefined && Date.parse(e.endTime) <= now.getTime(),
    );
    const begun = new Set(
      events.flatMap((e) =>
        e.taskId !== undefined && Date.parse(e.endTime) > now.getTime() ? [e.taskId] : [],
      ),
    );
    const pending = new Map(
      ((await self._tasks.pending(user)) as { id: string }[]).map((t) => [t.id, t]),
    );
    for (const event of over) {
      const task = pending.get(event.taskId!);
      if (task === undefined) continue;
      await self._tasks.update(user, { ...task, doneAt: event.endTime });
      pending.delete(task.id);
    }
    const zone = self._timeline.zone(user);
    const workDay = user.workDay ?? DEFAULT_WORK_DAY;
    for (const task of pending.values()) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      if (begun.has(task.id) || !isMissed(task as any, now, zone, workDay)) continue;
      await self._tasks.update(user, { ...task, cancelled: true });
    }
  }
}

const SERVER = path.join(__dirname, '..', '..', '..', '..', 'server');
const OUT = path.join(__dirname, '..', 'data', 'tick-vs-read.json');
const ZONE = 'America/Sao_Paulo';
const WHO = { id: 'u1', timeZone: ZONE, workDay: { start: 420, end: 1320 } };

/** 09:00 in São Paulo, a Tuesday. */
const START = Date.parse('2026-03-10T12:00:00Z');
const MIN = 60_000;

let clock = START;
const closers: (() => Promise<void>)[] = [];

interface World {
  name: string;
  layout: EventLayoutService;
  timeline: TimelineService;
  writes: () => number;
}

async function world(name: string, fixed = false): Promise<World> {
  const client = new PGlite();
  let writes = 0;
  const db = drizzle(client, {
    schema,
    logger: {
      logQuery: (sql) => {
        if (/^\s*(insert|update|delete)/i.test(sql)) writes++;
      },
    },
  });
  await migrate(db, { migrationsFolder: path.join(SERVER, 'drizzle') });
  await db.insert(user).values({ id: WHO.id, name: 'P', email: 'p@x.dev' });

  const pg = db as unknown as Database;
  const config = { get: () => ZONE } as never;
  const calendarStore = new PgCalendarStore(pg);
  const calendar = new CalendarService(calendarStore, config);
  const tasks = new PgTaskStore(pg);
  const artifacts = new PgArtifactStore(pg);
  const timeline = new TimelineService(calendar, tasks, artifacts);
  const layout = new (fixed ? FixedLayout : EventLayoutService)(
    timeline,
    calendar,
    tasks,
    artifacts,
  );
  closers.push(() => client.close());

  for (const [i, title] of ['Email', 'Relatório', 'Ligar', 'Ler'].entries()) {
    await tasks.insert(WHO, { title, minutes: 45, position: i, backlog: false });
  }
  await calendarStore.insertRoutine(WHO, {
    title: 'Almoço',
    startTime: new Date(START + 3 * 3_600_000).toISOString(),
    endTime: new Date(START + 4 * 3_600_000).toISOString(),
    days: 'daily',
  });
  await calendarStore.insertRoutine(WHO, {
    title: 'Academia',
    startTime: new Date(START + 9 * 3_600_000).toISOString(),
    endTime: new Date(START + 10 * 3_600_000).toISOString(),
    days: 'weekdays',
    fixed: true,
  });

  return { name, layout, timeline, writes: () => writes };
}

/** Every card the app would draw, as "title start–end" in the person's zone. */
async function read(w: World, catchUp: boolean): Promise<string[]> {
  const now = new Date(clock);
  if (catchUp) await w.layout.catchUp(WHO, Trace.start(WHO.id), now);
  const view = w.timeline.view(await w.timeline.day(WHO, 2, now));
  const hhmm = (iso: string) =>
    new Date(iso).toLocaleTimeString('pt-BR', {
      timeZone: ZONE,
      hour: '2-digit',
      minute: '2-digit',
    });
  return view.cards.map(
    (card) => `${card.title} ${hhmm(card.startTime)}–${hhmm(card.endTime)}`,
  );
}

async function main(): Promise<void> {
  Date.now = () => clock;
  const worlds = {
    tick: await world('tick'),
    read: await world('read'),
    fixed: await world('fixed', true),
    bare: await world('bare'),
  };

  // Email begun at 09:00, paused at 09:20, never resumed.
  for (const w of Object.values(worlds)) {
    const day = await w.timeline.day(WHO, 1, new Date(clock));
    const email = day.tasks.find((t) => t.title === 'Email')!;
    await w.layout.startTask(WHO, email.id, Trace.start(WHO.id), new Date(clock));
  }
  clock += 20 * MIN;
  for (const w of Object.values(worlds)) {
    const day = await w.timeline.day(WHO, 1, new Date(clock));
    const email = day.tasks.find((t) => t.title === 'Email')!;
    await w.layout.pauseTask(WHO, email.id, Trace.start(WHO.id), new Date(clock));
  }
  const setup = Object.fromEntries(
    Object.values(worlds).map((w) => [w.name, w.writes()]),
  );

  const samples: {
    at: string;
    tickEqualsRead: boolean;
    tickEqualsFixed: boolean;
    bareEqualsTick: boolean;
    tick: string[];
    read?: string[];
    fixed?: string[];
    bare?: string[];
  }[] = [];
  const tickWrites: { at: string; rows: number }[] = [];

  // To 23:00, a minute at a time; read every 30 minutes.
  while (clock < START + 14 * 3_600_000) {
    clock += MIN;
    const before = worlds.tick.writes();
    await worlds.tick.layout.catchUp(WHO, Trace.start(WHO.id), new Date(clock));
    const wrote = worlds.tick.writes() - before;
    const at = new Date(clock).toLocaleTimeString('pt-BR', {
      timeZone: ZONE,
      hour: '2-digit',
      minute: '2-digit',
    });
    if (wrote > 0) tickWrites.push({ at, rows: wrote });

    if ((clock - START) % (30 * MIN) !== 0) continue;
    const tick = await read(worlds.tick, true);
    const viaRead = await read(worlds.read, true);
    const fixed = await read(worlds.fixed, true);
    const bare = await read(worlds.bare, false);
    const same = (a: string[], b: string[]) => a.join('|') === b.join('|');
    samples.push({
      at,
      tickEqualsRead: same(tick, viaRead),
      tickEqualsFixed: same(tick, fixed),
      bareEqualsTick: same(bare, tick),
      tick,
      ...(same(tick, viaRead) ? {} : { read: viaRead }),
      ...(same(tick, fixed) ? {} : { fixed }),
      ...(same(tick, bare) ? {} : { bare }),
    });
  }

  const ticked = tickWrites.reduce((sum, it) => sum + it.rows, 0);
  const result = {
    note: 'cards compared by title and hour; writes are insert/update/delete statements',
    reads: samples.length,
    tickEqualsRead: samples.filter((s) => s.tickEqualsRead).length,
    tickEqualsFixed: samples.filter((s) => s.tickEqualsFixed).length,
    bareEqualsTick: samples.filter((s) => s.bareEqualsTick).length,
    writesAfterSetup: {
      tick: worlds.tick.writes() - setup.tick,
      read: worlds.read.writes() - setup.read,
      fixed: worlds.fixed.writes() - setup.fixed,
      bare: worlds.bare.writes() - setup.bare,
    },
    tickMinutesThatWrote: tickWrites.length,
    tickRowsWritten: ticked,
    firstTickWrites: tickWrites.slice(0, 3),
    samples,
  };
  fs.writeFileSync(OUT, JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify({ ...result, samples: samples.slice(0, 3) }, null, 2));
  for (const close of closers) await close();
}

void main();
