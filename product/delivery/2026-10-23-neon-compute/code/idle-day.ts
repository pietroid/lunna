/**
 * What the built server sends to Postgres while nobody uses it.
 *
 * Boots the server's own feature modules (everything in AppModule but auth
 * and analytics, which need Better Auth and PostHog; a stub stands in for
 * Better Auth) over an in-process
 * Postgres (PGlite), with every timer faked, then:
 *
 *   1. counts the timers the modules left scheduled after init,
 *   2. lets 24 hours pass and counts the statements sent meanwhile,
 *   3. pauses a task at 09:20 and reads the day an hour later, the way the
 *      app's first refresh after a quiet hour would (CatchUpInterceptor's
 *      catchUp, then the day), and prints the paused task's card.
 *
 *   cd server && NODE_PATH=$PWD/node_modules npx ts-node --transpile-only -P tsconfig.json ../product/delivery/2026-10-23-neon-compute/code/idle-day.ts
 */
import * as path from 'path';
import FakeTimers from '@sinonjs/fake-timers';
import { Global, Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { PGlite } from '@electric-sql/pglite';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import { AUTH } from '../../../../server/src/auth/auth.tokens';
import { DB } from '../../../../server/src/db/db';
import { schema, user } from '../../../../server/src/db/schema';
import { AgentModule } from '../../../../server/src/agent/agent.module';
import { ArtifactsModule } from '../../../../server/src/artifacts/artifacts.module';
import { CalendarModule } from '../../../../server/src/calendar/calendar.module';
import { EventsModule } from '../../../../server/src/events/events.module';
import { EventLayoutService } from '../../../../server/src/events/event-layout.service';
import { TimelineService } from '../../../../server/src/events/timeline.service';
import { LinksModule } from '../../../../server/src/links/links.module';
import { NotificationsModule } from '../../../../server/src/notifications/notifications.module';
import { RoutinesModule } from '../../../../server/src/routines/routines.module';
import { UsersModule } from '../../../../server/src/users/users.module';
import { TaskStore } from '../../../../server/src/tasks/task.store';
import { Trace } from '../../../../server/src/common/trace';

const SERVER = path.join(__dirname, '..', '..', '..', '..', 'server');
const ZONE = 'America/Sao_Paulo';
const WHO = { id: 'u1', timeZone: ZONE, workDay: { start: 420, end: 1320 } };
/** 09:00 in São Paulo, a Tuesday. */
const START = Date.parse('2026-03-10T12:00:00Z');
const MIN = 60_000;

async function main(): Promise<void> {
  const client = new PGlite();
  let statements = 0;
  const db = drizzle(client, {
    schema,
    logger: { logQuery: () => void statements++ },
  });
  await migrate(db, { migrationsFolder: path.join(SERVER, 'drizzle') });
  await db.insert(user).values({ id: WHO.id, name: 'P', email: 'p@x.dev' });

  @Global()
  // SessionGuard is built for every controller; no request reaches it here.
  @Module({
    providers: [
      { provide: DB, useValue: db },
      { provide: AUTH, useValue: {} },
    ],
    exports: [DB, AUTH],
  })
  class TestDb {}

  const clock = FakeTimers.install({ now: START, shouldClearNativeTimers: true });
  const moduleRef = await Test.createTestingModule({
    imports: [
      ConfigModule.forRoot({ isGlobal: true, ignoreEnvFile: true }),
      TestDb,
      AgentModule,
      CalendarModule,
      EventsModule,
      LinksModule,
      NotificationsModule,
      ArtifactsModule,
      RoutinesModule,
      UsersModule,
    ],
  }).compile();
  const app = moduleRef.createNestApplication({ logger: false });
  await app.init();

  const timersAfterInit = clock.countTimers();
  statements = 0;
  await clock.tickAsync(24 * 60 * MIN);
  const idleDay = statements;

  // A day with a task begun at 09:00 (now, after the idle day) and paused
  // twenty minutes in; then an hour with nobody reading.
  const layout = moduleRef.get(EventLayoutService);
  const timeline = moduleRef.get(TimelineService);
  const tasks = moduleRef.get(TaskStore);
  const trace = () => Trace.start(WHO.id);
  const created = await tasks.insert(WHO, {
    title: 'Email',
    minutes: 45,
    position: 0,
    backlog: false,
  });
  await layout.startTask(WHO, created.id, trace(), new Date(clock.now));
  await clock.tickAsync(20 * MIN);
  await layout.pauseTask(WHO, created.id, trace(), new Date(clock.now));

  statements = 0;
  await clock.tickAsync(60 * MIN);
  const quietHour = statements;

  statements = 0;
  const now = new Date(clock.now);
  await layout.catchUp(WHO, trace(), now);
  const view = timeline.view(await timeline.day(WHO, 1, now));
  const firstRead = statements;
  const email = view.tasks.find((it) => it.id === created.id);
  const hhmm = (iso: string) =>
    new Date(iso).toLocaleTimeString('pt-BR', {
      timeZone: ZONE,
      hour: '2-digit',
      minute: '2-digit',
    });

  console.log(
    JSON.stringify(
      {
        timersAfterInit,
        statementsInAnIdleDay: idleDay,
        statementsInAPausedQuietHour: quietHour,
        statementsInTheFirstReadAfter: firstRead,
        readAt: hhmm(now.toISOString()),
        pausedTask:
          email === undefined
            ? 'gone from the list (taken for done)'
            : {
                paused: email.pausedAt !== undefined,
                start: hhmm(email.startTime),
                end: hhmm(email.endTime),
              },
      },
      null,
      2,
    ),
  );

  await app.close();
  clock.uninstall();
  await client.close();
}

void main();
