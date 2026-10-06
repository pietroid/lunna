import { CalendarEvent } from '../calendar/calendar.types';
import { Day, TimelineService } from '../events/timeline.service';
import { Task } from '../tasks/task.types';
import { Interval } from '../time/work-hours';
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
    until: new Date(NOW.getTime() + 86_400_000),
    events,
    tasks: queue.map((it) => it.task),
    live: new Map(),
    placed: new Map(queue.map((it) => [it.task.id, it.slot])),
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

describe('the next task', () => {
  it('asks to be begun at the hour the queue gives it', async () => {
    const items = await itemsFor([], 1, [queued('t1')]);
    const [asking] = ofKind(items, 'confirmStart');

    expect(asking).toMatchObject({
      fireAt: '2026-09-21T14:00:00-03:00',
      title: 'Escrever relatório',
      body: 'Está na hora. Começamos?',
      timeSensitive: true,
      eventId: 't1',
    });
  });

  it('is the only task asked about', async () => {
    const items = await itemsFor([], 1, [
      queued('t1'),
      queued('t2', {}, '2026-09-21T17:35:00.000Z'),
    ]);

    expect(ofKind(items, 'confirmStart').map((item) => item.eventId)).toEqual([
      't1',
    ]);
  });

  it('is not asked about once its hour has come', async () => {
    const items = await itemsFor([], 1, [
      queued('t1', {}, '2026-09-21T15:04:00.000Z'),
    ]);

    expect(ofKind(items, 'confirmStart')).toHaveLength(0);
  });

  it('gets a new id when the queue moves it', async () => {
    const [before] = ofKind(
      await itemsFor([], 1, [queued('t1')]),
      'confirmStart',
    );
    const [after] = ofKind(
      await itemsFor([], 1, [queued('t1', {}, '2026-09-21T17:30:00.000Z')]),
      'confirmStart',
    );

    expect(after.id).not.toBe(before.id);
  });

  it('gets a new id when it is renamed', async () => {
    const [before] = ofKind(
      await itemsFor([], 1, [queued('t1')]),
      'confirmStart',
    );
    const [after] = ofKind(
      await itemsFor([], 1, [queued('t1', { title: 'Outra coisa' })]),
      'confirmStart',
    );

    expect(after.id).not.toBe(before.id);
  });
});

describe('a block', () => {
  it('that is fixed is announced at its start, with its end', async () => {
    const items = await itemsFor([block()]);
    const [starting] = ofKind(items, 'starting');

    expect(ofKind(items, 'confirmStart')).toHaveLength(0);
    expect(starting).toMatchObject({
      kind: 'starting',
      fireAt: '2026-09-21T14:00:00-03:00',
      title: 'Revisão de código',
      body: 'Começa agora, até 15:00',
      timeSensitive: true,
      eventId: 'evt-1',
    });
  });

  it('that a routine repeats is announced, not asked about', async () => {
    const items = await itemsFor([block({ routine: 'daily' })]);

    expect(ofKind(items, 'confirmStart')).toHaveLength(0);
    expect(ofKind(items, 'starting')).toHaveLength(1);
  });

  it('is announced ten minutes before its end', async () => {
    const [almost] = ofKind(await itemsFor([block()]), 'almostFinishing');

    expect(almost).toMatchObject({
      fireAt: '2026-09-21T14:50:00-03:00',
      body: 'Finaliza em 10 minutos',
      timeSensitive: false,
    });
  });

  it('under twenty minutes gets no reminder before its end', async () => {
    const short = block({ endTime: '2026-09-21T17:19:00.000Z' });
    const items = await itemsFor([short]);

    expect(ofKind(items, 'starting')).toHaveLength(1);
    expect(ofKind(items, 'almostFinishing')).toHaveLength(0);
  });

  it('of exactly twenty minutes still gets one', async () => {
    const edge = block({ endTime: '2026-09-21T17:20:00.000Z' });

    expect(ofKind(await itemsFor([edge]), 'almostFinishing')).toHaveLength(1);
  });

  it('that Lunna did not book gets nothing', async () => {
    const meeting = block({ managed: false });
    const items = await itemsFor([meeting]);

    expect(ofKind(items, 'starting')).toHaveLength(0);
    expect(ofKind(items, 'almostFinishing')).toHaveLength(0);
  });

  it('that is a begun task opens the task when tapped', async () => {
    // 11:30 to 13:00: begun, not finished.
    const running = block({
      fixed: false,
      started: true,
      taskId: 't1',
      startTime: '2026-09-21T14:30:00.000Z',
      endTime: '2026-09-21T16:00:00.000Z',
    });
    const items = await itemsFor([running]);

    expect(ofKind(items, 'starting')).toHaveLength(0);
    expect(ofKind(items, 'almostFinishing')[0]).toMatchObject({
      fireAt: '2026-09-21T12:50:00-03:00',
      eventId: 't1',
    });
  });

  it('that is paused gets no reminder before an end that keeps moving', async () => {
    const paused = block({
      startTime: '2026-09-21T14:30:00.000Z',
      endTime: '2026-09-21T16:00:00.000Z',
      pausedAt: '2026-09-21T15:00:00.000Z',
      remainingSeconds: 1800,
    });

    expect(ofKind(await itemsFor([paused]), 'almostFinishing')).toHaveLength(0);
  });
});

describe('reminder ids', () => {
  it('are the same for the same block at the same hour', async () => {
    const first = await itemsFor([block()]);
    const second = await itemsFor([block()]);

    expect(first.map((item) => item.id)).toEqual(second.map((item) => item.id));
  });

  it('change when the block moves', async () => {
    const [before] = ofKind(await itemsFor([block()]), 'starting');
    const [after] = ofKind(
      await itemsFor([
        block({
          startTime: '2026-09-21T17:30:00.000Z',
          endTime: '2026-09-21T18:30:00.000Z',
        }),
      ]),
      'starting',
    );

    expect(after.id).not.toBe(before.id);
  });

  it('change when the block is renamed', async () => {
    const [before] = ofKind(await itemsFor([block()]), 'starting');
    const [after] = ofKind(
      await itemsFor([block({ title: 'Outra coisa' })]),
      'starting',
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
