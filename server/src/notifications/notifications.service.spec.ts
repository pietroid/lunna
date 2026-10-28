import { CalendarEvent } from '../calendar/calendar.types';
import { Day, TimelineService } from '../events/timeline.service';
import { Task } from '../tasks/task.types';
import { DEFAULT_WORK_DAY, Interval } from '../time/work-hours';
import { NotificationItem } from './dto/notification-plan.dto';
import { EVENING_MESSAGES, MORNING_MESSAGES } from './notification-copy';
import { NotificationsService } from './notifications.service';

const SAO_PAULO = 'America/Sao_Paulo';
const USER = { id: 'test-user' };

/** 12:04 in São Paulo on 21/09/2026. */
const NOW = new Date('2026-09-21T15:04:00.000Z');

/** A task in the queue, and the hour the queue gives it. */
interface Queued {
  task: Task;
  slot: Interval;
}

/** A day that holds exactly [events] and [queue], kept in São Paulo. */
function serviceWith(
  events: CalendarEvent[],
  queue: Queued[] = [],
): NotificationsService {
  const day: Day = {
    now: NOW,
    zone: SAO_PAULO,
    workDay: DEFAULT_WORK_DAY,
    until: new Date(NOW.getTime() + 86_400_000),
    events,
    tasks: queue.map((it) => it.task),
    backlog: [],
    live: new Map(),
    placed: new Map(queue.map((it) => [it.task.id, it.slot])),
    routines: new Map(),
    artifacts: new Map(),
  };
  const timeline = {
    day: () => Promise.resolve(day),
    zone: () => SAO_PAULO,
  } as unknown as TimelineService;

  return new NotificationsService(timeline);
}

function block(overrides: Partial<CalendarEvent> = {}): CalendarEvent {
  return {
    id: 'evt-1',
    title: 'Revisão de código',
    // 14:00 to 15:00 in São Paulo.
    startTime: '2026-09-21T17:00:00.000Z',
    endTime: '2026-09-21T18:00:00.000Z',
    managed: true,
    fixed: true,
    notes: '',
    ...overrides,
  };
}

/** A task the queue puts at [start], 14:00 in São Paulo unless told. */
function queued(
  id: string,
  overrides: Partial<Task> = {},
  start = '2026-09-21T17:00:00.000Z',
): Queued {
  const from = new Date(start);
  const minutes = overrides.minutes ?? 30;

  return {
    task: {
      id,
      title: 'Escrever relatório',
      notes: '',
      minutes,
      position: 0,
      backlog: false,
      ...overrides,
    },
    slot: { start: from, end: new Date(from.getTime() + minutes * 60_000) },
  };
}

async function itemsFor(
  events: CalendarEvent[],
  horizonDays = 1,
  queue: Queued[] = [],
): Promise<NotificationItem[]> {
  return (await serviceWith(events, queue).plan(USER, horizonDays, NOW)).items;
}

function ofKind(items: NotificationItem[], kind: string): NotificationItem[] {
  return items.filter((item) => item.kind === kind);
}

function times(items: NotificationItem[]): string[] {
  return items.map((item) => item.fireAt);
}

describe('the next task', () => {
  it('is asked to be begun at its hour, and twice more ten minutes apart', async () => {
    const items = await itemsFor([], 1, [queued('t1')]);
    const asks = ofKind(items, 'askStart');

    expect(times(asks)).toEqual([
      '2026-09-21T14:00:00-03:00',
      '2026-09-21T14:10:00-03:00',
      '2026-09-21T14:20:00-03:00',
    ]);
    expect(asks[0]).toMatchObject({
      title: 'Escrever relatório',
      body: 'Está na hora. Começamos?',
      timeSensitive: true,
      eventId: 't1',
      card: 'task',
      edge: 'start',
    });
    expect(new Set(asks.map((item) => item.id)).size).toBe(3);
  });

  it('is the only task asked about', async () => {
    const items = await itemsFor([], 1, [
      queued('t1'),
      queued('t2', {}, '2026-09-21T17:35:00.000Z'),
    ]);

    expect(
      new Set(ofKind(items, 'askStart').map((item) => item.eventId)),
    ).toEqual(new Set(['t1']));
  });

  it('keeps its re-asks from the hour it came due while it waits', async () => {
    // Anchored at 12:00 and still waiting at 12:04: the queue puts it at
    // this minute, but it was asked at noon, so it is asked at 12:10 and
    // 12:20, not ten minutes after every sync.
    const items = await itemsFor([], 1, [
      queued(
        't1',
        { notBefore: '2026-09-21T15:00:00.000Z' },
        '2026-09-21T15:04:00.000Z',
      ),
    ]);

    expect(times(ofKind(items, 'askStart'))).toEqual([
      '2026-09-21T12:10:00-03:00',
      '2026-09-21T12:20:00-03:00',
    ]);
  });

  it('gets new ids when the queue moves it', async () => {
    const [before] = ofKind(await itemsFor([], 1, [queued('t1')]), 'askStart');
    const [after] = ofKind(
      await itemsFor([], 1, [queued('t1', {}, '2026-09-21T17:30:00.000Z')]),
      'askStart',
    );

    expect(after.id).not.toBe(before.id);
  });

  it('gets new ids when it is renamed', async () => {
    const [before] = ofKind(await itemsFor([], 1, [queued('t1')]), 'askStart');
    const [after] = ofKind(
      await itemsFor([], 1, [queued('t1', { title: 'Outra coisa' })]),
      'askStart',
    );

    expect(after.id).not.toBe(before.id);
  });
});

describe('a fixed block', () => {
  it('says it started, three times, until the start is answered', async () => {
    const items = await itemsFor([block()]);
    const asks = ofKind(items, 'askStart');

    expect(times(asks)).toEqual([
      '2026-09-21T14:00:00-03:00',
      '2026-09-21T14:10:00-03:00',
      '2026-09-21T14:20:00-03:00',
    ]);
    expect(asks[0]).toMatchObject({
      title: 'Revisão de código começou',
      body: 'Até 15:00',
      timeSensitive: true,
      eventId: 'evt-1',
      card: 'event',
      edge: 'start',
    });

    const confirmed = block({ confirmedAt: '2026-09-21T15:01:00.000Z' });
    expect(ofKind(await itemsFor([confirmed]), 'askStart')).toHaveLength(0);
  });

  it('asks whether it ended, three times, until it is closed', async () => {
    const items = await itemsFor([block({ routine: 'daily' })]);
    const asks = ofKind(items, 'askEnd');

    expect(times(asks)).toEqual([
      '2026-09-21T15:00:00-03:00',
      '2026-09-21T15:10:00-03:00',
      '2026-09-21T15:20:00-03:00',
    ]);
    expect(asks[0]).toMatchObject({
      title: 'Revisão de código terminou?',
      card: 'event',
      edge: 'end',
    });

    const closed = block({ closedAt: '2026-09-21T15:01:00.000Z' });
    const left = await itemsFor([closed]);
    expect(left.filter((item) => item.eventId !== undefined)).toEqual([]);
  });

  it('in overtime is asked about from the end it was planned to have', async () => {
    // Planned to 12:00, nobody answered; its end is now dragged to 12:05.
    const late = block({
      startTime: '2026-09-21T14:00:00.000Z',
      endTime: '2026-09-21T15:05:00.000Z',
      overtimeFrom: '2026-09-21T15:00:00.000Z',
      confirmedAt: '2026-09-21T14:00:00.000Z',
    });

    expect(times(ofKind(await itemsFor([late]), 'askEnd'))).toEqual([
      '2026-09-21T12:10:00-03:00',
      '2026-09-21T12:20:00-03:00',
    ]);
  });

  it('gets a heads-up only when something runs right up to it', async () => {
    const lunch = block({ id: 'lunch', title: 'Almoço' });
    expect(ofKind(await itemsFor([lunch]), 'headsUp')).toHaveLength(0);

    // 13:00 to 13:55, then the break, then lunch at 14:00.
    const before = queued('t1', { minutes: 55 }, '2026-09-21T16:00:00.000Z');
    const [heads] = ofKind(await itemsFor([lunch], 1, [before]), 'headsUp');
    expect(heads).toMatchObject({
      fireAt: '2026-09-21T13:45:00-03:00',
      title: 'Almoço em 15 minutos',
      body: 'Das 14:00 às 15:00',
      eventId: 'lunch',
      card: 'event',
      edge: 'start',
    });
  });

  it('that Lunna did not book gets nothing', async () => {
    const meeting = block({ managed: false });
    const items = await itemsFor([meeting]);

    expect(items.filter((item) => item.eventId !== undefined)).toEqual([]);
  });

  it('never gets the old almost-finishing reminder', async () => {
    const kinds = new Set((await itemsFor([block()], 7)).map((it) => it.kind));
    expect([...kinds].sort()).toEqual(
      ['askEnd', 'askStart', 'evening', 'morning'].sort(),
    );
  });
});

describe('a begun task', () => {
  it('is asked whether it ended, and opens the task when tapped', async () => {
    // 11:30 to 13:00: begun, not finished.
    const running = block({
      fixed: false,
      started: true,
      confirmedAt: '2026-09-21T14:30:00.000Z',
      taskId: 't1',
      startTime: '2026-09-21T14:30:00.000Z',
      endTime: '2026-09-21T16:00:00.000Z',
    });
    const items = await itemsFor([running]);

    expect(ofKind(items, 'askStart')).toHaveLength(0);
    expect(ofKind(items, 'askEnd')[0]).toMatchObject({
      fireAt: '2026-09-21T13:00:00-03:00',
      eventId: 't1',
      card: 'task',
      edge: 'end',
    });
  });

  it('that is paused is not asked about an end that keeps moving', async () => {
    const paused = block({
      taskId: 't1',
      startTime: '2026-09-21T14:30:00.000Z',
      endTime: '2026-09-21T16:00:00.000Z',
      pausedAt: '2026-09-21T15:00:00.000Z',
      remainingSeconds: 1800,
    });

    expect(ofKind(await itemsFor([paused]), 'askEnd')).toHaveLength(0);
  });
});

describe('the re-asks', () => {
  it('are queued for the next 24 hours only; the first ask always is', async () => {
    const tomorrow = block({
      startTime: '2026-09-22T15:00:00.000Z',
      endTime: '2026-09-22T16:00:00.000Z',
    });
    const asks = ofKind(await itemsFor([tomorrow], 2), 'askStart');

    // 12:00 tomorrow is inside the day; 12:10 and 12:20 are past 12:04.
    expect(times(asks)).toEqual(['2026-09-22T12:00:00-03:00']);
  });
});

describe('reminder ids', () => {
  it('are the same for the same block at the same hour', async () => {
    const first = await itemsFor([block()]);
    const second = await itemsFor([block()]);

    expect(first.map((item) => item.id)).toEqual(second.map((item) => item.id));
  });

  it('change when the block moves', async () => {
    const [before] = ofKind(await itemsFor([block()]), 'askStart');
    const [after] = ofKind(
      await itemsFor([
        block({
          startTime: '2026-09-21T17:30:00.000Z',
          endTime: '2026-09-21T18:30:00.000Z',
        }),
      ]),
      'askStart',
    );

    expect(after.id).not.toBe(before.id);
  });

  it('change when the block is renamed', async () => {
    const [before] = ofKind(await itemsFor([block()]), 'askStart');
    const [after] = ofKind(
      await itemsFor([block({ title: 'Outra coisa' })]),
      'askStart',
    );

    expect(after.id).not.toBe(before.id);
  });
});

describe('the daily reminders', () => {
  it('fire at seven and at nine every day ahead', async () => {
    const items = await itemsFor([], 2);

    expect(ofKind(items, 'morning').map((item) => item.fireAt)).toEqual([
      '2026-09-22T07:00:00-03:00',
      '2026-09-23T07:00:00-03:00',
    ]);
    expect(ofKind(items, 'evening').map((item) => item.fireAt)).toEqual([
      '2026-09-21T21:00:00-03:00',
      '2026-09-22T21:00:00-03:00',
    ]);
  });

  it('say one of the written messages', async () => {
    const items = await itemsFor([], 3);

    for (const item of ofKind(items, 'morning')) {
      expect(item.title).toBe('Bom dia');
      expect(MORNING_MESSAGES).toContain(item.body);
    }
    for (const item of ofKind(items, 'evening')) {
      expect(item.title).toBe('Boa noite');
      expect(EVENING_MESSAGES).toContain(item.body);
    }
  });

  it('are not time-sensitive and open nothing in particular', async () => {
    for (const item of await itemsFor([], 2)) {
      expect(item.timeSensitive).toBe(false);
      expect(item.eventId).toBeUndefined();
    }
  });
});

describe('the plan', () => {
  it('is soonest first and holds nothing already past', async () => {
    const past = block({
      id: 'evt-past',
      startTime: '2026-09-21T12:00:00.000Z',
      endTime: '2026-09-21T13:00:00.000Z',
    });
    const items = await itemsFor([block(), past], 7);
    const times = items.map((item) => Date.parse(item.fireAt));

    expect(times).toEqual([...times].sort((a, b) => a - b));
    expect(times.every((at) => at > NOW.getTime())).toBe(true);
    expect(items.some((item) => item.id.includes('evt-past'))).toBe(false);
  });

  it('stops at the horizon', async () => {
    const items = await itemsFor([], 1);
    const until = Date.parse('2026-09-22T12:04:00-03:00');

    expect(items.every((item) => Date.parse(item.fireAt) <= until)).toBe(true);
  });

  it('names the zone it was written in', async () => {
    const plan = await serviceWith([]).plan(USER, 1, NOW);

    expect(plan.timeZone).toBe(SAO_PAULO);
    expect(plan.generatedAt).toBe(NOW.toISOString());
  });
});
