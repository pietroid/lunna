/**
 * How many SQL statements the server sends while nobody is using it.
 *
 * Builds the real stores and services over an in-process Postgres (PGlite),
 * gives one person an ordinary day (four tasks, a flexible and a fixed
 * routine, one delivery), then lets the clock run for 24 hours of minute
 * ticks, as `PauseTickerService` does, counting every statement. Then counts
 * one `GET /api/timeline` (catch-up, day, view) without the session lookup.
 *
 *   cd server && npx tsx ../product/research/2026-10-23-neon-compute/code/count-queries.ts
 *
 * Writes data/queries.json next to this folder.
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
import { PauseTickerService } from '../../../../server/src/events/pause-ticker.service';
import { Trace } from '../../../../server/src/common/trace';

const SERVER = path.join(__dirname, '..', '..', '..', '..', 'server');
const OUT = path.join(__dirname, '..', 'data', 'queries.json');
const ZONE = 'America/Sao_Paulo';
const WHO = { id: 'u1', timeZone: ZONE, workDay: { start: 420, end: 1320 } };

/** 09:00 in São Paulo, a Tuesday. */
const START = Date.parse('2026-03-10T12:00:00Z');

async function main(): Promise<void> {
  // The services read Date.now() for the cache's age; drive it by hand.
  let clock = START;
  Date.now = () => clock;

  const client = new PGlite();
  let statements = 0;
  const db = drizzle(client, {
    schema,
    logger: { logQuery: () => void statements++ },
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
  const layout = new EventLayoutService(timeline, calendar, tasks, artifacts);
  const ticker = new PauseTickerService(layout);

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

  // One read of the day, as the app's minute refresh makes it.
  const read = async (now: Date): Promise<number> => {
    const before = statements;
    await layout.catchUp(WHO, Trace.start(WHO.id), now);
    timeline.view(await timeline.day(WHO, 7, now));
    return statements - before;
  };

  const firstRead = await read(new Date(clock));
  ticker.watch(WHO);

  // 24 hours of minute ticks with nobody looking.
  const perHour: number[] = [];
  const ticksWithQueries: number[] = [];
  const quiet: boolean[] = [];
  for (let hour = 0; hour < 24; hour++) {
    let inHour = 0;
    for (let minute = 0; minute < 60; minute++) {
      clock += 60_000;
      const before = statements;
      await ticker.tick(new Date(clock));
      const sent = statements - before;
      inHour += sent;
      if (sent > 0) ticksWithQueries.push(sent);
      quiet.push(sent === 0);
    }
    perHour.push(inHour);
  }

  clock += 60_000;
  const warmRead = await read(new Date(clock));
  clock += 60_000;
  const nextMinuteRead = await read(new Date(clock));
  clock += 5_000;
  const sameMinuteRead = await read(new Date(clock));

  const result = {
    note: 'statements sent to Postgres; session lookup (Better Auth) not included',
    ticker: {
      ticks: 24 * 60,
      ticksThatQueried: ticksWithQueries.length,
      statementsPerDay: perHour.reduce((a, b) => a + b, 0),
      perTickMin: Math.min(...ticksWithQueries),
      perTickMax: Math.max(...ticksWithQueries),
      longestQuietMinutes: longestRun(quiet),
      perHour,
    },
    timelineRead: {
      first: firstRead,
      afterIdleDay: warmRead,
      oneMinuteLater: nextMinuteRead,
      fiveSecondsLater: sameMinuteRead,
    },
  };
  fs.writeFileSync(OUT, JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result, null, 2));
  await client.close();
}

/** The longest stretch of consecutive minutes that sent nothing. */
function longestRun(quiet: boolean[]): number {
  let best = 0;
  let run = 0;
  for (const it of quiet) {
    run = it ? run + 1 : 0;
    best = Math.max(best, run);
  }
  return best;
}

void main();
