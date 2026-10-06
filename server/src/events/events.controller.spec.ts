import {
  CanActivate,
  ExecutionContext,
  INestApplication,
} from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { SessionGuard } from '../auth/session.guard';
import { CalendarService } from '../calendar/calendar.service';
import { CalendarStore, MemoryCalendarStore } from '../calendar/calendar.store';
import { MemoryTaskStore, TaskStore } from '../tasks/task.store';
import { Timeline, TimelineCard } from './entities/event.entity';
import { EventLayoutService } from './event-layout.service';
import { EventsController } from './events.controller';
import { PauseTickerService } from './pause-ticker.service';
import { TasksController } from './tasks.controller';
import { TimelineController } from './timeline.controller';
import { TimelineService } from './timeline.service';
import { StartNowGuard } from './timing';

/** Signs everyone in as the same person, in the zone this file runs in. */
class StubSessionGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    context.switchToHttp().getRequest<{ user: unknown }>().user = {
      id: 'test-user',
      email: 'test@example.com',
      name: 'Test',
      timeZone: ZONE,
    };
    return true;
  }
}

/**
 * The zone and the instant this whole file runs at.
 *
 * Every test here writes its dates as local ones and lets the routes decide
 * where they land, so both halves of that have to stand still. On the real
 * clock they did not: run the suite at twenty to ten at night and a
 * forty-five minute block no longer fits before the working day closes at
 * 22:00, so it is booked for tomorrow morning and the tests that expect to
 * see it in "agora" fail for a reason that has nothing to do with the code
 * they are covering.
 *
 * Ten in the morning, with the rest of the day ahead of it. The zone is
 * pinned for the whole run by `jest.global-setup.js` (a test file cannot set
 * `TZ` itself), so `systemZone`, the local `Date` methods the tests do their
 * arithmetic with and the hours the routes come back with are all the same
 * zone on every machine.
 */
const ZONE = 'America/Sao_Paulo';
const NOW = new Date('2026-03-10T13:00:00Z');

/**
 * Only `Date` is frozen.
 *
 * The timers stay real, because supertest is talking over a real socket to a
 * real server and a faked `setTimeout` would hang the first request.
 */
beforeAll(() => {
  jest.useFakeTimers({
    now: NOW,
    doNotFake: [
      'cancelAnimationFrame',
      'cancelIdleCallback',
      'clearImmediate',
      'clearInterval',
      'clearTimeout',
      'hrtime',
      'nextTick',
      'performance',
      'queueMicrotask',
      'requestAnimationFrame',
      'requestIdleCallback',
      'setImmediate',
      'setInterval',
      'setTimeout',
    ],
  });
});

afterAll(() => {
  jest.useRealTimers();
});

afterEach(() => {
  jest.setSystemTime(NOW);
});

/** Moves the frozen clock forward by [minutes]. */
function later(minutes: number): void {
  jest.setSystemTime(new Date(Date.now() + minutes * 60_000));
}

/** The answer a guard's button sends, for [decision]. */
function answerOf(
  guard: StartNowGuard | undefined,
  decision: 'solve_current' | 'postpone_current',
): Record<string, unknown> {
  if (guard === undefined) throw new Error('No guard to answer');

  return { taskId: guard.taskId, index: guard.index, decision };
}

function body(response: { body: unknown }): Timeline {
  return response.body as Timeline;
}

/** What the calendar draws, from any answer. */
function cards(response: { body: unknown }): TimelineCard[] {
  return body(response).cards;
}

/** The list of tasks, from any answer. */
function tasks(response: { body: unknown }): TimelineCard[] {
  return body(response).tasks;
}

function titles(list: TimelineCard[]): string[] {
  return list.map((it) => it.title);
}

/** "14:30", so a test can say what it expects in the words the app uses. */
function hhmm(iso: string): string {
  const at = new Date(iso);
  return `${String(at.getHours()).padStart(2, '0')}:${String(at.getMinutes()).padStart(2, '0')}`;
}

/** How many minutes apart two cards are, end to start. */
function gapBetween(first: TimelineCard, second: TimelineCard): number {
  return Math.round(
    (Date.parse(second.startTime) - Date.parse(first.endTime)) / 60_000,
  );
}

/** [hours] from now, on the hour. */
function inHours(hours: number): Date {
  const at = new Date();
  at.setHours(at.getHours() + hours, 0, 0, 0);
  return at;
}

/**
 * The day, end to end.
 *
 * The clock stands still at [NOW], so a run at midnight says what a run at
 * noon says. Even so, little here asserts an absolute hour: the arithmetic
 * that produces hours is covered by `scheduling.spec.ts`. What is checked
 * here is what the routes do to each other — the queue, the gaps, the
 * calendar, and the one question that is left.
 *
 * Both stores are in memory: the same contracts as Postgres, routine
 * expansion included, with nothing to connect to.
 */
describe('the day', () => {
  let app: INestApplication<App>;
  let store: MemoryCalendarStore;
  let taskStore: MemoryTaskStore;

  /** Whoever the stub guard signs in. */
  const owner = { id: 'test-user', timeZone: ZONE };

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ConfigModule.forRoot({ ignoreEnvFile: true })],
      controllers: [TimelineController, EventsController, TasksController],
      providers: [
        TimelineService,
        EventLayoutService,
        PauseTickerService,
        CalendarService,
        { provide: CalendarStore, useClass: MemoryCalendarStore },
        { provide: TaskStore, useClass: MemoryTaskStore },
      ],
    })
      .overrideGuard(SessionGuard)
      .useClass(StubSessionGuard)
      .compile();

    store = moduleRef.get(CalendarStore);
    taskStore = moduleRef.get(TaskStore);

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  function post(pathname: string, payload?: object) {
    return request(app.getHttpServer()).post(pathname).send(payload);
  }

  /** Writes a task down, the way the sheet does. */
  function add(title: string, minutes: number, extra: object = {}) {
    return post('/tasks', { title, minutes, ...extra });
  }

  /** Writes a fixed block down at [at], the way the sheet does. */
  function fix(title: string, minutes: number, at: Date) {
    return post('/events', {
      title,
      durationMinutes: minutes,
      startTime: at.toISOString(),
    });
  }

  /** Drags a task to [index] in the list of tasks. */
  function drag(taskId: string, index: number, extra: object = {}) {
    return post(`/tasks/${taskId}/move`, { index, ...extra });
  }

  /** Says the task called [title] was begun, the way the card's button does. */
  async function begin(title: string): Promise<void> {
    await post(`/tasks/${(await task(title)).id}/start`).expect(201);
  }

  /** Answers a guard with one of its buttons. */
  function answer(action: Record<string, unknown>) {
    return post('/tasks/timing', { action });
  }

  async function read(days?: number): Promise<Timeline> {
    const path = days === undefined ? '/timeline' : `/timeline?days=${days}`;
    return body(await request(app.getHttpServer()).get(path).expect(200));
  }

  /** The calendar card called [title], which is how these tests name them. */
  async function card(title: string): Promise<TimelineCard> {
    const found = (await read()).cards.find((it) => it.title === title);
    if (found === undefined) throw new Error(`No card "${title}"`);
    return found;
  }

  /** The task called [title], on the list. */
  async function task(title: string): Promise<TimelineCard> {
    const found = (await read()).tasks.find((it) => it.title === title);
    if (found === undefined) throw new Error(`No task "${title}"`);
    return found;
  }

  /**
   * Puts one event on the calendar that Lunna did not book.
   *
   * Straight into the store, the way an outside calendar would, so it has to
   * happen before the first read of the day: the cache does not watch the
   * store, because in production nothing writes to it behind its back.
   */
  function meeting(title: string, from: Date, minutes: number) {
    store.seed(owner, {
      id: `ev-${title}`,
      title,
      startTime: from.toISOString(),
      endTime: new Date(from.getTime() + minutes * 60_000).toISOString(),
      managed: false,
      fixed: true,
    });
  }

  describe('writing a task down', () => {
    it('gives it an hour without putting anything on the calendar', async () => {
      const response = await add('Revisar proposta', 30).expect(201);
      const [listed] = tasks(response);
      const [drawn] = cards(response);

      expect(listed).toMatchObject({
        kind: 'task',
        title: 'Revisar proposta',
        workMinutes: 30,
        fixed: false,
        started: false,
        notes: '',
      });
      // The list and the calendar are two drawings of one answer.
      expect(drawn).toEqual(listed);
      expect(drawn.section).toBe('agora');
      expect(drawn.awaitingStart).toBe(true);

      // Its hour is worked out, not written down.
      expect(store.all(owner)).toEqual([]);
    });

    it('queues the next one after the first, without moving it', async () => {
      const [first] = tasks(await add('Primeiro', 30).expect(201));
      const day = tasks(await add('Segundo', 45).expect(201));

      expect(titles(day)).toEqual(['Primeiro', 'Segundo']);
      expect(day[0].startTime).toBe(first.startTime);
      expect(gapBetween(day[0], day[1])).toBe(5);
    });

    it('refuses one with no length', async () => {
      await add('Revisar proposta', 0).expect(400);
    });

    it('refuses one with no name', async () => {
      await add('   ', 30).expect(400);
    });

    it('starts one written in empty room where the room starts, and keeps it there', async () => {
      const room = inHours(3);

      const [drawn] = tasks(
        await add('Ler', 30, { notBefore: room.toISOString() }).expect(201),
      );

      expect(Date.parse(drawn.startTime)).toBe(room.getTime());
      expect(drawn.notBefore).toBe(room.toISOString());
    });

    it('puts one written in empty room in the queue where the room is', async () => {
      await add('Primeiro', 30).expect(201);
      await add('Tarde', 30, { notBefore: inHours(4).toISOString() });
      await add('Fim da fila', 30).expect(201);

      const day = tasks(
        await add('Meio', 30, { notBefore: inHours(2).toISOString() }),
      );

      expect(titles(day)).toEqual(['Primeiro', 'Meio', 'Tarde', 'Fim da fila']);
    });

    it('ignores a floor the clock has already passed', async () => {
      const past = new Date(Date.now() - 3_600_000).toISOString();

      const [drawn] = tasks(
        await add('Ler', 30, { notBefore: past }).expect(201),
      );

      expect(drawn.notBefore).toBeUndefined();
    });
  });

  describe('writing a fixed block down', () => {
    it('keeps the hour it was given, on the calendar and off the list', async () => {
      await add('Primeiro', 60).expect(201);
      const at = inHours(3);

      const response = await fix('Reunião', 30, at).expect(201);

      const pinned = cards(response).find((it) => it.title === 'Reunião')!;
      expect(pinned).toMatchObject({ kind: 'event', fixed: true });
      expect(hhmm(pinned.startTime)).toBe(hhmm(at.toISOString()));
      expect(titles(tasks(response))).toEqual(['Primeiro']);
      expect(store.all(owner).map((it) => it.title)).toEqual(['Reunião']);
    });

    it('refuses one with no hour', async () => {
      await post('/events', { title: 'Reunião', durationMinutes: 30 }).expect(
        400,
      );
    });

    it('is something the tasks flow around', async () => {
      const at = new Date();
      at.setMinutes(at.getMinutes() + 10, 0, 0);
      await fix('Workshop', 120, at).expect(201);

      await add('Revisar proposta', 60).expect(201);

      expect(
        Date.parse((await card('Revisar proposta')).startTime),
      ).toBeGreaterThanOrEqual(at.getTime() + 120 * 60_000);
    });

    it('is never asked about when its hour comes', async () => {
      const at = new Date();
      at.setMinutes(at.getMinutes() + 30, 0, 0);
      await fix('Reunião', 30, at).expect(201);

      later(35);
      const [meeting] = (await read()).cards;
      expect(meeting.awaitingStart).toBe(false);
      expect(hhmm(meeting.startTime)).toBe(hhmm(at.toISOString()));
    });
  });

  describe('a meeting Lunna did not book', () => {
    it('is drawn, and is not Lunna’s to change', async () => {
      meeting('Daily', inHours(2), 30);
      await add('Revisar proposta', 30).expect(201);

      const daily = await card('Daily');
      expect(daily.managed).toBe(false);
      expect(daily.fixed).toBe(true);

      await post(`/events/${daily.id}/done`).expect(400);
    });

    it('is scheduled around', async () => {
      const at = new Date();
      at.setMinutes(at.getMinutes() + 10, 0, 0);
      meeting('Workshop', at, 120);

      await add('Revisar proposta', 60).expect(201);

      expect(
        Date.parse((await card('Revisar proposta')).startTime),
      ).toBeGreaterThanOrEqual(at.getTime() + 120 * 60_000);
    });
  });

  describe('reordering', () => {
    it('moves a task without asking anything when nothing is displaced', async () => {
      await add('Primeiro', 30).expect(201);
      await add('Segundo', 30).expect(201);
      await add('Terceiro', 30).expect(201);

      const response = await drag((await task('Terceiro')).id, 1).expect(201);

      expect(body(response).guard).toBeUndefined();
      expect(titles(tasks(response))).toEqual([
        'Primeiro',
        'Terceiro',
        'Segundo',
      ]);
      // The calendar follows the list.
      expect(titles(cards(response))).toEqual([
        'Primeiro',
        'Terceiro',
        'Segundo',
      ]);
    });

    it('never moves a fixed block', async () => {
      const at = inHours(3);
      await fix('Reunião', 30, at).expect(201);
      await add('Primeiro', 30).expect(201);
      await add('Segundo', 30).expect(201);

      await drag((await task('Segundo')).id, 0).expect(201);

      expect(hhmm((await card('Reunião')).startTime)).toBe(
        hhmm(at.toISOString()),
      );
    });

    it('lets a task moved to the front start without asking when nothing runs', async () => {
      await add('Primeiro', 30).expect(201);
      await add('Segundo', 30).expect(201);

      const response = await drag((await task('Segundo')).id, 0, {
        start: true,
      }).expect(201);

      expect(body(response).guard).toBeUndefined();
      expect(tasks(response)[0]).toMatchObject({
        title: 'Segundo',
        started: true,
      });
    });

    it('asks what to do with what is running before starting something else', async () => {
      await add('Em andamento', 60).expect(201);
      await add('Outra coisa', 30).expect(201);
      await begin('Em andamento');

      const response = await drag((await task('Outra coisa')).id, 0, {
        start: true,
      }).expect(201);

      const guard = body(response).guard;
      expect(guard?.kind).toBe('start_now');
      expect(guard?.current.title).toBe('Em andamento');
      expect(guard?.taskId).toBe((await task('Outra coisa')).id);
    });

    it('changes nothing while it is asking', async () => {
      await add('Em andamento', 60).expect(201);
      await add('Outra coisa', 30).expect(201);
      await begin('Em andamento');

      const before = await read();
      await drag((await task('Outra coisa')).id, 0, { start: true }).expect(
        201,
      );

      expect(await read()).toEqual(before);
    });

    it('finishes the running task and gives its hour away', async () => {
      await add('Em andamento', 60).expect(201);
      await add('Outra coisa', 30).expect(201);
      await begin('Em andamento');
      later(10);

      const guard = body(
        await drag((await task('Outra coisa')).id, 0, { start: true }),
      ).guard;
      const after = await answer(answerOf(guard, 'solve_current')).expect(201);

      expect(titles(tasks(after))).toEqual(['Outra coisa']);
      expect(tasks(after)[0].started).toBe(true);
      // The ten minutes it ran stay on the calendar, as what happened.
      const kept = store.all(owner).find((it) => it.title === 'Em andamento');
      expect(hhmm(kept!.endTime)).toBe('10:10');
    });

    it('pushes the running task down when told to keep it', async () => {
      await add('Em andamento', 60).expect(201);
      await add('Outra coisa', 30).expect(201);
      await begin('Em andamento');
      later(10);

      const guard = body(
        await drag((await task('Outra coisa')).id, 0, { start: true }),
      ).guard;
      const after = await answer(answerOf(guard, 'postpone_current')).expect(
        201,
      );

      const [now, next] = tasks(after);
      expect(titles(tasks(after))).toEqual(['Outra coisa', 'Em andamento']);
      expect(now.started).toBe(true);
      expect(next.started).toBe(false);
      expect(gapBetween(now, next)).toBe(5);
    });

    it('makes a task the next thing when dropped just under what is running', async () => {
      await add('Em andamento', 60).expect(201);
      await add('Depois', 30).expect(201);
      await add('Urgente', 30).expect(201);
      await begin('Em andamento');

      const response = await drag((await task('Urgente')).id, 1).expect(201);

      expect(body(response).guard).toBeUndefined();
      expect(titles(tasks(response))).toEqual([
        'Em andamento',
        'Urgente',
        'Depois',
      ]);
    });

    it('leaves the hour of what is already running alone', async () => {
      await add('Em andamento', 60).expect(201);
      await add('Depois disso', 30).expect(201);
      await add('E então', 30).expect(201);
      await begin('Em andamento');
      later(20);

      await drag((await task('E então')).id, 1).expect(201);

      const current = await task('Em andamento');
      expect(current.section).toBe('agora');
      expect(hhmm(current.startTime)).toBe('10:00');
      expect(
        Date.parse((await task('E então')).startTime),
      ).toBeGreaterThanOrEqual(Date.parse(current.endTime));
    });

    it('stops the running task when the user drags it down themselves', async () => {
      await add('Em andamento', 60).expect(201);
      await add('Outra', 30).expect(201);
      await begin('Em andamento');
      later(20);

      const response = await drag((await task('Em andamento')).id, 1).expect(
        201,
      );

      expect(titles(tasks(response))).toEqual(['Outra', 'Em andamento']);
      expect(tasks(response)[1].started).toBe(false);
      expect(store.all(owner)).toEqual([]);
    });

    it('refuses a move without a place to move to', async () => {
      const [listed] = tasks(await add('Revisar proposta', 30).expect(201));

      await post(`/tasks/${listed.id}/move`, {}).expect(400);
    });
  });

  describe('dropping into a gap', () => {
    it('starts the task where the gap starts, not earlier', async () => {
      const at = inHours(2);
      await fix('Reunião', 60, at).expect(201);
      await add('Primeiro', 30).expect(201);
      await add('Segundo', 30).expect(201);

      const afterMeeting = new Date(at.getTime() + 60 * 60_000);
      const response = await drag((await task('Segundo')).id, 1, {
        after: afterMeeting.toISOString(),
      }).expect(201);

      const moved = tasks(response).find((it) => it.title === 'Segundo')!;
      expect(Date.parse(moved.startTime)).toBe(afterMeeting.getTime());
      expect(moved.notBefore).toBeDefined();
    });

    it('cuts the task to the length it was given', async () => {
      await add('Primeiro', 30).expect(201);
      const [, second] = tasks(await add('Segundo', 60).expect(201));

      const response = await drag(second.id, 1, { minutes: 20 }).expect(201);

      expect(tasks(response)[1].workMinutes).toBe(20);
    });

    it('lifts the floor when dropped between two cards again', async () => {
      await add('Primeiro', 30).expect(201);
      const [, second] = tasks(await add('Segundo', 30).expect(201));
      const room = new Date(Date.now() + 3 * 3_600_000).toISOString();

      await drag(second.id, 1, { after: room }).expect(201);
      const day = tasks(await drag(second.id, 1).expect(201));

      expect(day[1].notBefore).toBeUndefined();
      expect(gapBetween(day[0], day[1])).toBe(5);
    });
  });

  describe('when a task reaches its hour', () => {
    it('waits for the user, sliding down the day a minute at a time', async () => {
      await add('Escrever', 30).expect(201);
      await add('Depois', 30).expect(201);

      later(7);
      const [waiting, next] = (await read()).tasks;

      expect(waiting.awaitingStart).toBe(true);
      expect(hhmm(waiting.startTime)).toBe('10:07');
      expect(waiting.durationMinutes).toBe(30);
      expect(gapBetween(waiting, next)).toBe(5);
    });

    it('keeps its hour once begun, on the calendar', async () => {
      const [first] = tasks(await add('Escrever', 30).expect(201));

      const [started] = tasks(await post(`/tasks/${first.id}/start`));
      expect(started).toMatchObject({ started: true, awaitingStart: false });
      expect(store.all(owner)[0]).toMatchObject({
        title: 'Escrever',
        taskId: first.id,
      });

      later(7);
      expect(hhmm((await task('Escrever')).startTime)).toBe('10:00');
    });

    it('is begun now when started from further down the day', async () => {
      await add('Primeiro', 30).expect(201);
      const [, second] = tasks(await add('Segundo', 30).expect(201));

      const [now, next] = tasks(await post(`/tasks/${second.id}/start`));

      expect(now).toMatchObject({ title: 'Segundo', started: true });
      expect(next.title).toBe('Primeiro');
    });

    it('waits fifteen minutes more when asked, leaving the gap free', async () => {
      const [first] = tasks(await add('Escrever', 30).expect(201));

      const [snoozed] = tasks(
        await post(`/tasks/${first.id}/snooze`, { minutes: 15 }).expect(201),
      );

      expect(hhmm(snoozed.startTime)).toBe('10:15');
      expect(snoozed.awaitingStart).toBe(false);

      later(3);
      expect(hhmm((await task('Escrever')).startTime)).toBe('10:15');
    });
  });

  describe('while a task is running', () => {
    it('spaces tasks exactly five minutes apart, off the grid', async () => {
      later(2);
      await add('Primeiro', 32).expect(201);
      await add('Segundo', 30).expect(201);

      const [first, second] = (await read()).tasks;
      expect(hhmm(first.startTime)).toBe('10:02');
      expect(hhmm(second.startTime)).toBe('10:39');
    });

    it('drags the rest of the day while paused, a minute per minute', async () => {
      const [running] = tasks(await add('Escrever', 30).expect(201));
      await begin('Escrever');
      await add('Depois', 30).expect(201);

      later(10);
      const [paused] = tasks(
        await post(`/tasks/${running.id}/pause`).expect(201),
      );
      expect(paused.pausedAt).toBeDefined();
      expect(paused.workMinutes).toBe(30);

      later(7);
      const [stretched, next] = (await read()).tasks;
      expect(hhmm(stretched.endTime)).toBe('10:37');
      expect(stretched.workMinutes).toBe(30);
      expect(gapBetween(stretched, next)).toBe(5);
    });

    it('owes exactly the same work after resuming', async () => {
      const [running] = tasks(await add('Escrever', 30).expect(201));
      await begin('Escrever');

      later(10);
      await post(`/tasks/${running.id}/pause`).expect(201);
      later(15);
      const [resumed] = tasks(
        await post(`/tasks/${running.id}/resume`).expect(201),
      );

      expect(resumed.pausedAt).toBeUndefined();
      expect(resumed.pausedSeconds).toBe(15 * 60);
      expect(hhmm(resumed.endTime)).toBe('10:45');
      expect(resumed.workMinutes).toBe(30);
    });

    it('refuses to pause what has not started', async () => {
      await add('Primeiro', 30).expect(201);
      const [, second] = tasks(await add('Segundo', 30).expect(201));

      await post(`/tasks/${second.id}/pause`).expect(400);
    });

    it('gives fifteen more minutes and pushes what follows', async () => {
      const [running] = tasks(await add('Escrever', 30).expect(201));
      await begin('Escrever');
      const [, before] = tasks(await add('Depois', 30).expect(201));

      const [extended, after] = tasks(
        await post(`/tasks/${running.id}/extend`, { minutes: 15 }).expect(201),
      );

      expect(extended.workMinutes).toBe(45);
      expect(Date.parse(after.startTime) - Date.parse(before.startTime)).toBe(
        15 * 60_000,
      );
    });

    it('takes fifteen minutes off and pulls what follows up', async () => {
      const [running] = tasks(await add('Escrever', 45).expect(201));
      await begin('Escrever');
      const [, before] = tasks(await add('Depois', 30).expect(201));

      const [shortened, after] = tasks(
        await post(`/tasks/${running.id}/extend`, { minutes: -15 }).expect(201),
      );

      expect(shortened.workMinutes).toBe(30);
      expect(Date.parse(before.startTime) - Date.parse(after.startTime)).toBe(
        15 * 60_000,
      );
    });

    it('refuses to shorten it into the past', async () => {
      const [running] = tasks(await add('Escrever', 30).expect(201));
      await begin('Escrever');

      later(20);
      await post(`/tasks/${running.id}/extend`, { minutes: -15 }).expect(400);
    });
  });

  describe('finishing', () => {
    it('ticks off a task that never began, leaving nothing behind', async () => {
      const [listed] = tasks(await add('Revisar proposta', 30).expect(201));

      const after = await post(`/tasks/${listed.id}/done`).expect(201);

      expect(tasks(after)).toEqual([]);
      expect(cards(after)).toEqual([]);
      expect(store.all(owner)).toEqual([]);
      expect((await taskStore.get(owner, listed.id))?.doneAt).toBeDefined();
    });

    it('closes the queue up over what was ticked off', async () => {
      await add('Primeiro', 60).expect(201);
      await add('Segundo', 30).expect(201);
      const before = tasks(await add('Terceiro', 30).expect(201));

      const after = tasks(
        await post(`/tasks/${before[0].id}/done`).expect(201),
      );

      expect(titles(after)).toEqual(['Segundo', 'Terceiro']);
      expect(Date.parse(after[0].startTime)).toBeLessThan(
        Date.parse(before[1].startTime),
      );
      expect(gapBetween(after[0], after[1])).toBe(5);
    });

    it('keeps a running task as the hour it took, and rests five minutes', async () => {
      const [running] = tasks(await add('Escrever', 30).expect(201));
      await begin('Escrever');
      await add('Depois', 30).expect(201);

      later(12);
      const after = tasks(await post(`/tasks/${running.id}/done`).expect(201));

      expect(titles(after)).toEqual(['Depois']);
      expect(hhmm(after[0].startTime)).toBe('10:17');

      const [kept] = store.all(owner);
      expect(kept.endTime).toBe(new Date(Date.now()).toISOString());
    });

    it('counts a running task as done once its hour runs out', async () => {
      const [running] = tasks(await add('Escrever', 30).expect(201));
      await begin('Escrever');

      later(31);
      const day = await read();

      expect(day.tasks).toEqual([]);
      expect((await taskStore.get(owner, running.id))?.doneAt).toBeDefined();
      // The hour happened, and stays on the calendar as what did.
      expect(store.all(owner).map((it) => it.title)).toEqual(['Escrever']);
    });

    it('deletes a task outright, and the hour it was taking', async () => {
      await add('Primeiro', 30).expect(201);
      await begin('Primeiro');
      const [first, second] = tasks(await add('Segundo', 30).expect(201));

      const after = tasks(
        await request(app.getHttpServer())
          .delete(`/tasks/${first.id}`)
          .expect(200),
      );

      expect(titles(after)).toEqual(['Segundo']);
      expect(after[0].startTime).not.toBe(second.startTime);
      expect(store.all(owner)).toEqual([]);
    });

    it('leaves a fixed block where it is when the queue closes up', async () => {
      const [first] = tasks(await add('Primeiro', 60).expect(201));
      const at = inHours(3);
      await fix('Reunião', 30, at).expect(201);
      await add('Segundo', 30).expect(201);

      await post(`/tasks/${first.id}/done`).expect(201);

      expect(hhmm((await card('Reunião')).startTime)).toBe(
        hhmm(at.toISOString()),
      );
    });

    it('cuts a running fixed block off at this minute', async () => {
      const at = new Date();
      at.setSeconds(0, 0);
      const [block] = cards(await fix('Reunião', 60, at).expect(201));

      later(20);
      await post(`/events/${block.id}/done`).expect(201);

      expect(hhmm(store.all(owner)[0].endTime)).toBe('10:20');
    });
  });

  describe('the detail screen', () => {
    it('keeps what is written on a task, and moves nothing', async () => {
      const [first] = tasks(await add('Primeiro', 30).expect(201));
      const before = tasks(await add('Segundo', 30).expect(201));

      const after = tasks(
        await request(app.getHttpServer())
          .patch(`/tasks/${first.id}`)
          .send({ notes: 'Começar pela seção 3.' })
          .expect(200),
      );

      expect(after[0].notes).toBe('Começar pela seção 3.');
      expect(after.map((it) => it.startTime)).toEqual(
        before.map((it) => it.startTime),
      );
    });

    it('renames and re-estimates a task', async () => {
      await add('Primeiro', 30).expect(201);
      const [, second] = tasks(await add('Segundo', 30).expect(201));

      const renamed = tasks(
        await request(app.getHttpServer())
          .patch(`/tasks/${second.id}`)
          .send({ title: 'Outro nome', workMinutes: 45 })
          .expect(200),
      );

      expect(renamed[1]).toMatchObject({
        title: 'Outro nome',
        workMinutes: 45,
      });
    });

    it('renames the hour of a running task with it', async () => {
      const [first] = tasks(await add('Primeiro', 30).expect(201));
      await begin('Primeiro');

      await request(app.getHttpServer())
        .patch(`/tasks/${first.id}`)
        .send({ title: 'Outro nome' })
        .expect(200);

      expect(store.all(owner)[0].title).toBe('Outro nome');
    });

    it('gives a fixed block a new hour', async () => {
      const [block] = cards(await fix('Reunião', 30, inHours(2)).expect(201));
      const at = inHours(5);

      const after = cards(
        await request(app.getHttpServer())
          .patch(`/events/${block.id}`)
          .send({ startTime: at.toISOString(), notes: 'Sala 2' })
          .expect(200),
      );

      expect(after[0]).toMatchObject({ fixed: true, notes: 'Sala 2' });
      expect(hhmm(after[0].startTime)).toBe(hhmm(at.toISOString()));
    });
  });

  describe('further ahead', () => {
    it('lays the whole queue out, however many days it takes', async () => {
      for (let n = 0; n < 20; n++) {
        await add(`Tarefa ${n}`, 55).expect(201);
      }

      const day = await read(1);

      expect(day.tasks).toHaveLength(20);
      const days = new Set(day.tasks.map((it) => it.day));
      expect(days.size).toBeGreaterThan(1);
      // The calendar draws only the days asked for.
      expect(new Set(day.cards.map((it) => it.day))).toEqual(
        new Set(['2026-03-10']),
      );
    });

    it('draws as many days as asked, routines and all', async () => {
      const lunch = inHours(2);
      await store.insertRoutine(owner, {
        title: 'Almoço',
        startTime: lunch.toISOString(),
        endTime: new Date(lunch.getTime() + 60 * 60_000).toISOString(),
        days: 'daily',
      });

      const day = await read(5);
      const lunches = day.cards.filter((it) => it.title === 'Almoço');

      expect(lunches.map((it) => it.day)).toEqual([
        '2026-03-10',
        '2026-03-11',
        '2026-03-12',
        '2026-03-13',
        '2026-03-14',
      ]);
      expect(lunches.every((it) => it.section === 'dia')).toBe(true);
    });

    it('flows tasks around routines on days nobody has looked at yet', async () => {
      // A routine every morning from seven to noon, and more work than the
      // rest of today holds.
      const morning = new Date(NOW);
      morning.setHours(7, 0, 0, 0);
      await store.insertRoutine(owner, {
        title: 'Manhã',
        startTime: morning.toISOString(),
        endTime: new Date(morning.getTime() + 5 * 3_600_000).toISOString(),
        days: 'daily',
      });
      for (let n = 0; n < 15; n++) {
        await add(`Tarefa ${n}`, 55).expect(201);
      }

      const day = await read(1);

      for (const listed of day.tasks) {
        const start = new Date(listed.startTime);
        expect(
          start.getHours() * 60 + start.getMinutes(),
        ).toBeGreaterThanOrEqual(12 * 60);
      }
    });
  });

  describe('routines', () => {
    it('moves one day of a routine and leaves the others where they were', async () => {
      const lunch = inHours(2);
      await store.insertRoutine(owner, {
        title: 'Almoço',
        startTime: lunch.toISOString(),
        endTime: new Date(lunch.getTime() + 60 * 60_000).toISOString(),
        days: 'daily',
      });

      const today = await card('Almoço');
      expect(today.routine).toBe('daily');
      expect(today.fixed).toBe(true);
      expect(hhmm(today.startTime)).toBe(hhmm(lunch.toISOString()));

      const moved = new Date(lunch.getTime() + 2 * 3_600_000);
      const day = cards(
        await request(app.getHttpServer())
          .patch(`/events/${today.id}?days=2`)
          .send({ startTime: moved.toISOString() })
          .expect(200),
      );

      const [first, second] = day.filter((it) => it.title === 'Almoço');
      expect(first.id).toBe(today.id);
      expect(first.routine).toBe('daily');
      expect(Date.parse(first.startTime)).toBe(moved.getTime());
      expect(first.durationMinutes).toBe(60);

      // Tomorrow is its own row, still at the routine's hour.
      expect(second.day).toBe('2026-03-11');
      expect(hhmm(second.startTime)).toBe(hhmm(lunch.toISOString()));
    });

    it('does not bring back a day of a routine that was taken off', async () => {
      const lunch = inHours(2);
      await store.insertRoutine(owner, {
        title: 'Almoço',
        startTime: lunch.toISOString(),
        endTime: new Date(lunch.getTime() + 60 * 60_000).toISOString(),
        days: 'daily',
      });

      const today = await card('Almoço');
      await request(app.getHttpServer())
        .delete(`/events/${today.id}`)
        .expect(200);

      // A fresh read expands the window again; the cancelled day stays gone.
      const fresh = await store.window(
        owner,
        new Date(Date.now() - 3_600_000),
        new Date(Date.now() + 36 * 3_600_000),
        ZONE,
      );
      expect(fresh.filter((it) => it.title === 'Almoço')).toHaveLength(1);
      expect(fresh.find((it) => it.id === today.id)).toBeUndefined();
    });
  });
});
