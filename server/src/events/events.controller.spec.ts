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
import { EventCard } from './entities/event.entity';
import { EventLayoutService } from './event-layout.service';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';
import { PauseTickerService } from './pause-ticker.service';
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
 * 22:00, so it is booked for tomorrow morning and four tests that expect to
 * see it in "agora" fail for a reason that has nothing to do with the code
 * they are covering.
 *
 * Ten in the morning, with the rest of the day ahead of it. The zone is set
 * before anything reads a clock, so `systemZone`, the local `Date` methods
 * the tests do their arithmetic with and the hours the routes come back with
 * are all the same zone on every machine.
 */
const ZONE = 'America/Sao_Paulo';
const NOW = new Date('2026-03-10T13:00:00Z');

process.env.TZ = ZONE;

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

/** The answer a guard's button sends, for [decision]. */
function answerOf(
  guard: StartNowGuard | undefined,
  decision: 'solve_current' | 'postpone_current',
): Record<string, unknown> {
  if (guard === undefined) throw new Error('No guard to answer');

  return { eventId: guard.eventId, index: guard.index, decision };
}

interface Outcome {
  cards: EventCard[];
  guard?: StartNowGuard;
}

function outcome(response: { body: unknown }): Outcome {
  return response.body as Outcome;
}

function cards(response: { body: unknown }): EventCard[] {
  return response.body as EventCard[];
}

/** "14:30", so a test can say what it expects in the words the app uses. */
function hhmm(iso: string): string {
  const at = new Date(iso);
  return `${String(at.getHours()).padStart(2, '0')}:${String(at.getMinutes()).padStart(2, '0')}`;
}

/** How many minutes apart two cards are, end to start. */
function gapBetween(first: EventCard, second: EventCard): number {
  return Math.round(
    (Date.parse(second.startTime) - Date.parse(first.endTime)) / 60_000,
  );
}

/**
 * The day, end to end.
 *
 * The clock stands still at [NOW], so a run at midnight says what a run at
 * noon says. Even so, almost nothing here asserts an absolute hour: the
 * arithmetic that produces hours is covered by `scheduling.spec.ts`. What is
 * checked here is what the routes do to each other — the order, the gaps,
 * the calendar, and the one question that is left.
 *
 * The calendar is [MemoryCalendarStore]: the same contract as Postgres,
 * routine expansion included, with nothing to connect to.
 */
describe('the day', () => {
  let app: INestApplication<App>;
  let store: MemoryCalendarStore;
  let calendar: CalendarService;

  /** Whoever the stub guard signs in. */
  const owner = { id: 'test-user', timeZone: ZONE };

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ConfigModule.forRoot({ ignoreEnvFile: true })],
      controllers: [EventsController],
      providers: [
        EventsService,
        EventLayoutService,
        PauseTickerService,
        CalendarService,
        { provide: CalendarStore, useClass: MemoryCalendarStore },
      ],
    })
      .overrideGuard(SessionGuard)
      .useClass(StubSessionGuard)
      .compile();

    store = moduleRef.get(CalendarStore);
    calendar = moduleRef.get(CalendarService);

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  /** Writes something down on the timeline, the way the sheet does. */
  function add(
    title: string,
    durationMinutes: number,
    extra: Record<string, unknown> = {},
  ) {
    return request(app.getHttpServer())
      .post('/events')
      .send({ title, durationMinutes, ...extra });
  }

  /** Drags a card to [index] in the day's one list. */
  function drag(eventId: string, index: number) {
    return request(app.getHttpServer())
      .post(`/events/${eventId}/move`)
      .send({ index });
  }

  /** Says the block called [title] was begun, the way the card's button does. */
  async function begin(title: string): Promise<void> {
    await request(app.getHttpServer())
      .post(`/events/${(await card(title)).id}/start`)
      .expect(201);
  }

  /** Answers a guard with one of its buttons. */
  function answer(action: Record<string, unknown>) {
    return request(app.getHttpServer()).post('/events/timing').send({ action });
  }

  async function timeline(): Promise<EventCard[]> {
    return cards(await request(app.getHttpServer()).get('/events').expect(200));
  }

  /** The card called [title], which is how these tests name them. */
  async function card(title: string): Promise<EventCard> {
    const found = (await timeline()).find((it) => it.title === title);
    if (found === undefined) throw new Error(`No card "${title}"`);
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

  it('gives everything an hour the moment it is written down', async () => {
    const [drawn] = cards(await add('Revisar proposta', 30).expect(201));

    expect(drawn.title).toBe('Revisar proposta');
    expect(drawn.durationMinutes).toBe(30);
    expect(drawn.fixed).toBe(false);
    expect(drawn.managed).toBe(true);
    expect(drawn.section).toBe('agora');

    // A block exists because the calendar holds an event for it. There is
    // nowhere else for it to be.
    expect(store.all(owner)).toHaveLength(1);
    expect(store.all({ id: 'someone-else' })).toEqual([]);
  });

  it('starts with no notes', async () => {
    const [drawn] = cards(await add('Revisar proposta', 30).expect(201));

    expect(drawn.notes).toBe('');
  });

  it('puts the next thing after the first, without moving it', async () => {
    const [first] = cards(await add('Primeiro', 30).expect(201));
    const day = cards(await add('Segundo', 45).expect(201));

    expect(day.map((it) => it.title)).toEqual(['Primeiro', 'Segundo']);
    expect(day[0].startTime).toBe(first.startTime);
    expect(gapBetween(day[0], day[1])).toBeGreaterThanOrEqual(5);
  });

  it('keeps the hour a fixed block was given', async () => {
    await add('Primeiro', 60).expect(201);

    const at = new Date();
    at.setHours(at.getHours() + 3, 0, 0, 0);

    await add('Reunião', 30, {
      fixed: true,
      startTime: at.toISOString(),
    }).expect(201);

    const pinned = await card('Reunião');
    expect(pinned.fixed).toBe(true);
    expect(hhmm(pinned.startTime)).toBe(hhmm(at.toISOString()));
  });

  it('never moves a fixed block when the day is rearranged', async () => {
    const at = new Date();
    at.setHours(at.getHours() + 3, 0, 0, 0);

    await add('Reunião', 30, {
      fixed: true,
      startTime: at.toISOString(),
    }).expect(201);
    await add('Primeiro', 30).expect(201);
    await add('Segundo', 30).expect(201);

    await drag((await card('Segundo')).id, 1).expect(201);

    expect(hhmm((await card('Reunião')).startTime)).toBe(
      hhmm(at.toISOString()),
    );
  });

  it('asks what to do with what is running before starting something else', async () => {
    await add('Em andamento', 60).expect(201);
    await add('Outra coisa', 30).expect(201);
    await begin('Em andamento');

    const response = await drag((await card('Outra coisa')).id, 0).expect(201);

    const guard = outcome(response).guard;
    expect(guard?.kind).toBe('start_now');
    expect(guard?.current.title).toBe('Em andamento');
    expect(guard?.eventId).toBe((await card('Outra coisa')).id);
  });

  it('changes nothing while it is asking', async () => {
    await add('Em andamento', 60).expect(201);
    await add('Outra coisa', 30).expect(201);
    await begin('Em andamento');

    const before = await timeline();
    await drag((await card('Outra coisa')).id, 0).expect(201);

    expect(await timeline()).toEqual(before);
  });

  it('finishes the running block and gives its hour back', async () => {
    await add('Em andamento', 60).expect(201);
    await add('Outra coisa', 30).expect(201);
    await begin('Em andamento');

    const guard = outcome(await drag((await card('Outra coisa')).id, 0)).guard;
    await answer(answerOf(guard, 'solve_current')).expect(201);

    expect((await timeline()).map((it) => it.title)).toEqual(['Outra coisa']);
    expect(store.all(owner).map((it) => it.title)).toEqual(['Outra coisa']);
  });

  it('pushes the running block down when told to keep it', async () => {
    await add('Em andamento', 60).expect(201);
    await add('Outra coisa', 30).expect(201);
    await begin('Em andamento');

    const guard = outcome(await drag((await card('Outra coisa')).id, 0)).guard;
    await answer(answerOf(guard, 'postpone_current')).expect(201);

    const day = await timeline();
    expect(day.map((it) => it.title)).toEqual(['Outra coisa', 'Em andamento']);
    expect(gapBetween(day[0], day[1])).toBeGreaterThanOrEqual(5);
  });

  it('rearranges without asking anything when nothing is displaced', async () => {
    await add('Primeiro', 30).expect(201);
    await add('Segundo', 30).expect(201);
    await add('Terceiro', 30).expect(201);

    const response = await drag((await card('Terceiro')).id, 1).expect(201);

    expect(outcome(response).guard).toBeUndefined();
    expect(outcome(response).cards.map((it) => it.title)).toEqual([
      'Primeiro',
      'Terceiro',
      'Segundo',
    ]);
  });

  it('draws a meeting it did not book, and will not move it', async () => {
    const at = new Date();
    at.setHours(at.getHours() + 2, 0, 0, 0);
    meeting('Daily', at, 30);
    await add('Revisar proposta', 30).expect(201);

    const daily = await card('Daily');
    expect(daily.managed).toBe(false);
    expect(daily.fixed).toBe(true);

    await drag(daily.id, 0).expect(400);
  });

  it('schedules around a meeting it did not book', async () => {
    const at = new Date();
    at.setMinutes(at.getMinutes() + 10, 0, 0);
    meeting('Workshop', at, 120);
    const end = new Date(at.getTime() + 120 * 60_000);

    await add('Revisar proposta', 60).expect(201);

    expect(
      Date.parse((await card('Revisar proposta')).startTime),
    ).toBeGreaterThanOrEqual(end.getTime());
  });

  it('takes a finished block off the calendar', async () => {
    const [drawn] = cards(await add('Revisar proposta', 30).expect(201));

    await request(app.getHttpServer())
      .post(`/events/${drawn.id}/done`)
      .expect(201);

    expect(await timeline()).toEqual([]);
    expect(store.all(owner)).toEqual([]);
  });

  it('closes the day up over something that was finished', async () => {
    await add('Primeiro', 60).expect(201);
    await add('Segundo', 30).expect(201);
    const before = cards(await add('Terceiro', 30).expect(201));

    expect(before.map((it) => it.title)).toEqual([
      'Primeiro',
      'Segundo',
      'Terceiro',
    ]);

    await request(app.getHttpServer())
      .post(`/events/${before[0].id}/done`)
      .expect(201);

    const after = await timeline();

    // The hour the finished thing had is the hour the rest of the day moves
    // into: "Segundo" takes the top of the queue, and "Terceiro" follows it
    // up rather than sitting where it was.
    expect(after.map((it) => it.title)).toEqual(['Segundo', 'Terceiro']);
    expect(Date.parse(after[0].startTime)).toBeLessThan(
      Date.parse(before[1].startTime),
    );
    expect(Date.parse(after[1].startTime)).toBeLessThan(
      Date.parse(before[2].startTime),
    );
    expect(gapBetween(after[0], after[1])).toBeGreaterThanOrEqual(5);
  });

  it('leaves a fixed block where it is when the day closes up', async () => {
    const [first] = cards(await add('Primeiro', 60).expect(201));

    const at = new Date();
    at.setHours(at.getHours() + 3, 0, 0, 0);
    await add('Reunião', 30, {
      fixed: true,
      startTime: at.toISOString(),
    }).expect(201);
    await add('Segundo', 30).expect(201);

    await request(app.getHttpServer())
      .post(`/events/${first.id}/done`)
      .expect(201);

    expect(hhmm((await card('Reunião')).startTime)).toBe(
      hhmm(at.toISOString()),
    );
  });

  /**
   * Backdates a block so it is genuinely mid-hour.
   *
   * A block added through the sheet starts at this minute, so it is running
   * but has nothing behind it: only a card whose start is real minutes ago
   * can show whether a rearrangement leaves that start alone.
   */
  async function backdate(
    title: string,
    startedMinutesAgo: number,
    minutes = 60,
  ): Promise<Date> {
    const event = await card(title);
    const start = new Date(Date.now() - startedMinutesAgo * 60_000);
    start.setSeconds(0, 0);

    await calendar.save(owner, {
      id: event.id,
      title: event.title,
      startTime: start.toISOString(),
      endTime: new Date(start.getTime() + minutes * 60_000).toISOString(),
      managed: true,
      fixed: false,
      notes: event.notes,
      // Mid-hour means the user began it; a block nobody began slides.
      started: true,
    });

    return start;
  }

  it('leaves the hour of what is already running alone', async () => {
    await add('Em andamento', 60).expect(201);
    await add('Depois disso', 30).expect(201);
    await add('E então', 30).expect(201);

    // Running since twenty minutes ago, and flexible, so nothing but the new
    // rule keeps the layout off it.
    const started = await backdate('Em andamento', 20);

    await drag((await card('E então')).id, 1).expect(201);

    const current = await card('Em andamento');
    expect(current.section).toBe('agora');
    expect(current.startTime).toBe(started.toISOString());
  });

  it('packs the rest of the day after what is running, not over it', async () => {
    await add('Em andamento', 60).expect(201);
    await add('Depois disso', 30).expect(201);
    const started = await backdate('Em andamento', 20);
    const runningEnd = new Date(started.getTime() + 60 * 60_000);

    await drag((await card('Depois disso')).id, 1).expect(201);

    expect(
      Date.parse((await card('Depois disso')).startTime),
    ).toBeGreaterThanOrEqual(runningEnd.getTime());
  });

  it('still moves the running card when the user drags it themselves', async () => {
    await add('Em andamento', 60).expect(201);
    await add('Outra', 30).expect(201);
    const started = await backdate('Em andamento', 20);

    await drag((await card('Em andamento')).id, 1).expect(201);

    const day = await timeline();
    expect(day.map((it) => it.title)).toEqual(['Outra', 'Em andamento']);
    expect(day[1].startTime).not.toBe(started.toISOString());
  });

  it('stops drawing a block once its hour has run out', async () => {
    await add('Acabou', 30).expect(201);
    // Started an hour ago and only lasted half of it, so it is over.
    await backdate('Acabou', 60, 30);

    expect(await timeline()).toEqual([]);
  });

  it('leaves a finished block on the calendar, because it happened', async () => {
    await add('Acabou', 30).expect(201);
    await backdate('Acabou', 60, 30);

    await timeline();

    // Nothing sweeps the past. The hour happened, and deleting the event
    // would be rewriting the day rather than letting it end.
    expect(store.all(owner).map((it) => it.title)).toEqual(['Acabou']);
  });

  it('refuses a move without a place to move to', async () => {
    const [drawn] = cards(await add('Revisar proposta', 30).expect(201));

    await request(app.getHttpServer())
      .post(`/events/${drawn.id}/move`)
      .send({})
      .expect(400);
  });

  it('refuses something written down with no length', async () => {
    await add('Revisar proposta', 0).expect(400);
  });

  it('refuses something written down with no name', async () => {
    await add('   ', 30).expect(400);
  });

  describe('notes', () => {
    it('keeps what is written on a block', async () => {
      const [drawn] = cards(await add('Revisar proposta', 30).expect(201));

      const after = cards(
        await request(app.getHttpServer())
          .patch(`/events/${drawn.id}`)
          .send({ notes: 'Começar pela seção 3.' })
          .expect(200),
      );

      expect(after[0].notes).toBe('Começar pela seção 3.');
      expect(store.all(owner)[0].notes).toBe('Começar pela seção 3.');
    });

    it('does not move anything when only the notes change', async () => {
      const [first] = cards(await add('Primeiro', 30).expect(201));
      const before = cards(await add('Segundo', 30).expect(201));

      const after = cards(
        await request(app.getHttpServer())
          .patch(`/events/${first.id}`)
          .send({ notes: 'x' })
          .expect(200),
      );

      expect(after.map((it) => it.startTime)).toEqual(
        before.map((it) => it.startTime),
      );
    });

    it('reads one block back by id', async () => {
      const [drawn] = cards(await add('Revisar proposta', 30).expect(201));

      const response = await request(app.getHttpServer())
        .get(`/events/${drawn.id}`)
        .expect(200);

      expect((response.body as EventCard).title).toBe('Revisar proposta');
    });

    it('404s a block that is not on the day', async () => {
      await request(app.getHttpServer()).get('/events/nope').expect(404);
    });
  });

  describe('while something is running', () => {
    /** Moves the frozen clock forward by [minutes]. */
    function later(minutes: number): void {
      jest.setSystemTime(new Date(Date.now() + minutes * 60_000));
    }

    afterEach(() => {
      jest.setSystemTime(NOW);
    });

    function post(pathname: string, body?: object) {
      return request(app.getHttpServer()).post(pathname).send(body);
    }

    it('spaces blocks exactly five minutes apart, off the grid', async () => {
      later(2);
      await add('Primeiro', 32).expect(201);
      await add('Segundo', 30).expect(201);

      const [first, second] = await timeline();
      expect(hhmm(first.startTime)).toBe('10:02');
      expect(hhmm(second.startTime)).toBe('10:39');
    });

    it('drags the rest of the day while paused, a minute per minute', async () => {
      const [running] = cards(await add('Escrever', 30).expect(201));
      await begin('Escrever');
      await add('Depois', 30).expect(201);

      later(10);
      const paused = cards(
        await post(`/events/${running.id}/pause`).expect(201),
      );
      expect(paused[0].pausedAt).toBeDefined();
      expect(paused[0].workMinutes).toBe(30);

      later(7);
      const [stretched, next] = await timeline();
      expect(hhmm(stretched.endTime)).toBe('10:37');
      expect(stretched.workMinutes).toBe(30);
      expect(gapBetween(stretched, next)).toBe(5);
    });

    it('owes exactly the same work after resuming', async () => {
      const [running] = cards(await add('Escrever', 30).expect(201));
      await begin('Escrever');

      later(10);
      await post(`/events/${running.id}/pause`).expect(201);
      later(15);
      const [resumed] = cards(
        await post(`/events/${running.id}/resume`).expect(201),
      );

      expect(resumed.pausedAt).toBeUndefined();
      expect(resumed.pausedSeconds).toBe(15 * 60);
      expect(hhmm(resumed.endTime)).toBe('10:45');
      expect(resumed.workMinutes).toBe(30);
    });

    it('refuses to pause what has not started', async () => {
      await add('Primeiro', 30).expect(201);
      const [, second] = cards(await add('Segundo', 30).expect(201));

      await post(`/events/${second.id}/pause`).expect(400);
    });

    it('gives fifteen more minutes and pushes what follows', async () => {
      const [running] = cards(await add('Escrever', 30).expect(201));
      await begin('Escrever');
      const [, before] = cards(await add('Depois', 30).expect(201));

      const [extended, after] = cards(
        await post(`/events/${running.id}/extend`, { minutes: 15 }).expect(201),
      );

      expect(extended.workMinutes).toBe(45);
      expect(Date.parse(after.startTime) - Date.parse(before.startTime)).toBe(
        15 * 60_000,
      );
    });

    it('takes fifteen minutes off and pulls what follows up', async () => {
      const [running] = cards(await add('Escrever', 45).expect(201));
      await begin('Escrever');
      const [, before] = cards(await add('Depois', 30).expect(201));

      const [shortened, after] = cards(
        await post(`/events/${running.id}/extend`, { minutes: -15 }).expect(
          201,
        ),
      );

      expect(shortened.workMinutes).toBe(30);
      expect(Date.parse(before.startTime) - Date.parse(after.startTime)).toBe(
        15 * 60_000,
      );
    });

    it('refuses to shorten a block into the past', async () => {
      const [running] = cards(await add('Escrever', 30).expect(201));
      await begin('Escrever');

      later(20);
      await post(`/events/${running.id}/extend`, { minutes: -15 }).expect(400);
    });

    it('keeps a finished block as the hour it took, and rests five minutes', async () => {
      const [running] = cards(await add('Escrever', 30).expect(201));
      await begin('Escrever');
      await add('Depois', 30).expect(201);

      later(12);
      const after = cards(await post(`/events/${running.id}/done`).expect(201));

      expect(after.map((it) => it.title)).toEqual(['Depois']);
      expect(hhmm(after[0].startTime)).toBe('10:17');

      const kept = store.all(owner).find((it) => it.id === running.id);
      expect(kept?.endTime).toBe(new Date(Date.now()).toISOString());
    });

    it('deletes a block outright and closes the day up', async () => {
      await add('Primeiro', 30).expect(201);
      const [, second] = cards(await add('Segundo', 30).expect(201));
      await add('Terceiro', 30).expect(201);

      const after = cards(
        await request(app.getHttpServer())
          .delete(`/events/${second.id}`)
          .expect(200),
      );

      expect(after.map((it) => it.title)).toEqual(['Primeiro', 'Terceiro']);
      expect(gapBetween(after[0], after[1])).toBe(5);
      expect(store.all(owner).map((it) => it.id)).not.toContain(second.id);
    });

    it('renames, re-estimates and pins from the detail screen', async () => {
      await add('Primeiro', 30).expect(201);
      const [, second] = cards(await add('Segundo', 30).expect(201));

      const renamed = cards(
        await request(app.getHttpServer())
          .patch(`/events/${second.id}`)
          .send({ title: 'Outro nome', workMinutes: 45 })
          .expect(200),
      );
      expect(renamed[1]).toMatchObject({
        title: 'Outro nome',
        workMinutes: 45,
      });

      const at = new Date();
      at.setHours(at.getHours() + 3, 0, 0, 0);
      const pinned = cards(
        await request(app.getHttpServer())
          .patch(`/events/${second.id}`)
          .send({ startTime: at.toISOString() })
          .expect(200),
      );
      const moved = pinned.find((it) => it.id === second.id);
      expect(moved).toMatchObject({ fixed: true, workMinutes: 45 });
      expect(hhmm(moved!.startTime)).toBe(hhmm(at.toISOString()));
    });
  });

  describe('when a flexible block reaches its hour', () => {
    function later(minutes: number): void {
      jest.setSystemTime(new Date(Date.now() + minutes * 60_000));
    }

    afterEach(() => {
      jest.setSystemTime(NOW);
    });

    function post(pathname: string, body?: object) {
      return request(app.getHttpServer()).post(pathname).send(body);
    }

    it('waits for the user, sliding down the day a minute at a time', async () => {
      await add('Escrever', 30).expect(201);
      await add('Depois', 30).expect(201);

      later(7);
      const [waiting, next] = await timeline();

      expect(waiting.awaitingStart).toBe(true);
      expect(hhmm(waiting.startTime)).toBe('10:07');
      expect(waiting.durationMinutes).toBe(30);
      expect(gapBetween(waiting, next)).toBe(5);
    });

    it('keeps its hour once begun', async () => {
      const [first] = cards(await add('Escrever', 30).expect(201));

      const started = outcome(
        await post(`/events/${first.id}/start`).expect(201),
      );
      expect(started.cards[0].awaitingStart).toBe(false);

      later(7);
      const [running] = await timeline();
      expect(hhmm(running.startTime)).toBe('10:00');
    });

    it('waits fifteen minutes more when asked, leaving the gap free', async () => {
      const [first] = cards(await add('Escrever', 30).expect(201));

      const day = cards(
        await post(`/events/${first.id}/snooze`, { minutes: 15 }).expect(201),
      );

      expect(hhmm(day[0].startTime)).toBe('10:15');
      expect(day[0].awaitingStart).toBe(false);

      // Nothing else pulls it back while it waits.
      later(3);
      expect(hhmm((await timeline())[0].startTime)).toBe('10:15');
    });

    it('is never asked about when it is fixed', async () => {
      const at = new Date();
      at.setMinutes(at.getMinutes() + 30, 0, 0);
      await add('Reunião', 30, { fixed: true, startTime: at.toISOString() });

      later(35);
      const [meeting] = await timeline();
      expect(meeting.awaitingStart).toBe(false);
      expect(hhmm(meeting.startTime)).toBe(hhmm(at.toISOString()));
    });
  });

  describe('writing down from a tap on empty room', () => {
    it('starts a flexible block where the room starts, and keeps it there', async () => {
      const room = new Date();
      room.setHours(room.getHours() + 3, 0, 0, 0);

      const [drawn] = cards(
        await add('Ler', 30, { notBefore: room.toISOString() }).expect(201),
      );

      expect(drawn.fixed).toBe(false);
      expect(Date.parse(drawn.startTime)).toBe(room.getTime());
      expect(drawn.notBefore).toBe(room.toISOString());
    });

    it('ignores a floor the clock has already passed', async () => {
      const past = new Date(Date.now() - 3_600_000).toISOString();

      const [drawn] = cards(
        await add('Ler', 30, { notBefore: past }).expect(201),
      );

      expect(drawn.notBefore).toBeUndefined();
    });
  });

  describe('dropping into a gap', () => {
    it('starts the block where the gap starts, not earlier', async () => {
      const at = new Date();
      at.setHours(at.getHours() + 2, 0, 0, 0);
      await add('Reunião', 60, { fixed: true, startTime: at.toISOString() });
      await add('Primeiro', 30).expect(201);
      await add('Segundo', 30).expect(201);

      const afterMeeting = new Date(at.getTime() + 60 * 60_000);
      const day = outcome(
        await request(app.getHttpServer())
          .post(`/events/${(await card('Segundo')).id}/move`)
          .send({ index: 2, after: afterMeeting.toISOString() })
          .expect(201),
      ).cards;

      const moved = day.find((it) => it.title === 'Segundo')!;
      expect(Date.parse(moved.startTime)).toBeGreaterThanOrEqual(
        afterMeeting.getTime(),
      );
      expect(moved.notBefore).toBeDefined();
    });

    it('cuts the block to the length it was given', async () => {
      await add('Primeiro', 30).expect(201);
      const [, second] = cards(await add('Segundo', 60).expect(201));

      const day = outcome(
        await request(app.getHttpServer())
          .post(`/events/${second.id}/move`)
          .send({ index: 1, minutes: 20 })
          .expect(201),
      ).cards;

      expect(day[1].durationMinutes).toBe(20);
    });

    it('lifts the floor when dropped between two cards again', async () => {
      await add('Primeiro', 30).expect(201);
      const [, second] = cards(await add('Segundo', 30).expect(201));
      const later = new Date(Date.now() + 3 * 3_600_000).toISOString();

      await request(app.getHttpServer())
        .post(`/events/${second.id}/move`)
        .send({ index: 1, after: later })
        .expect(201);
      const day = outcome(await drag(second.id, 1).expect(201)).cards;

      expect(day[1].notBefore).toBeUndefined();
      expect(gapBetween(day[0], day[1])).toBe(5);
    });
  });

  it('moves one day of a routine and leaves the others where they were', async () => {
    const lunch = new Date();
    lunch.setHours(lunch.getHours() + 2, 0, 0, 0);
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

    const later = new Date(lunch.getTime() + 2 * 3_600_000);
    const day = outcome(
      await request(app.getHttpServer())
        .post(`/events/${today.id}/move`)
        .send({ index: 0, after: later.toISOString() })
        .expect(201),
    ).cards;

    const moved = day.find((it) => it.id === today.id)!;
    expect(moved.routine).toBe('daily');
    expect(moved.fixed).toBe(true);
    expect(Date.parse(moved.startTime)).toBe(later.getTime());
    expect(moved.durationMinutes).toBe(60);

    // Tomorrow is its own row, still at the routine's hour.
    const tomorrow = day.filter((it) => it.title === 'Almoço')[1];
    expect(tomorrow.section).toBe('amanha');
    expect(hhmm(tomorrow.startTime)).toBe(hhmm(lunch.toISOString()));
  });

  it('does not bring back a day of a routine that was taken off', async () => {
    const lunch = new Date();
    lunch.setHours(lunch.getHours() + 2, 0, 0, 0);
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
