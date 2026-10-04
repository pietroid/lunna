import { CalendarReaderService } from '../calendar/calendar-reader.service';
import { CalendarEvent } from '../calendar/calendar.types';
import { NotificationItem } from './dto/notification-plan.dto';
import { EVENING_MESSAGES, MORNING_MESSAGES } from './notification-copy';
import { NotificationsService } from './notifications.service';

const SAO_PAULO = 'America/Sao_Paulo';
const USER = { id: 'test-user' };

/** 12:04 in São Paulo on 21/09/2026. */
const NOW = new Date('2026-09-21T15:04:00.000Z');

/** A calendar that holds exactly [events], kept in São Paulo. */
function serviceWith(events: CalendarEvent[]): NotificationsService {
  const reader = {
    events: () => Promise.resolve(events),
    zone: () => Promise.resolve(SAO_PAULO),
  } as unknown as CalendarReaderService;

  return new NotificationsService(reader);
}

function block(overrides: Partial<CalendarEvent> = {}): CalendarEvent {
  return {
    id: 'evt-1',
    title: 'Revisão de código',
    // 14:00 to 15:00 in São Paulo.
    startTime: '2026-09-21T17:00:00.000Z',
    endTime: '2026-09-21T18:00:00.000Z',
    managed: true,
    fixed: false,
    ...overrides,
  };
}

async function itemsFor(
  events: CalendarEvent[],
  horizonDays = 1,
): Promise<NotificationItem[]> {
  return (await serviceWith(events).plan(USER, horizonDays, NOW)).items;
}

function ofKind(items: NotificationItem[], kind: string): NotificationItem[] {
  return items.filter((item) => item.kind === kind);
}

describe('a block', () => {
  it('that is flexible asks to be begun at its start', async () => {
    const items = await itemsFor([block()]);
    const [asking] = ofKind(items, 'confirmStart');

    expect(ofKind(items, 'starting')).toHaveLength(0);
    expect(asking).toMatchObject({
      fireAt: '2026-09-21T14:00:00-03:00',
      title: 'Revisão de código',
      body: 'Está na hora. Começamos?',
      timeSensitive: true,
      eventId: 'evt-1',
    });
  });

  it('that a routine repeats is announced, not asked about', async () => {
    const items = await itemsFor([block({ fixed: true, routine: 'daily' })]);

    expect(ofKind(items, 'confirmStart')).toHaveLength(0);
    expect(ofKind(items, 'starting')).toHaveLength(1);
  });

  it('that was already begun is not asked about again', async () => {
    const items = await itemsFor([block({ started: true })]);

    expect(ofKind(items, 'confirmStart')).toHaveLength(0);
  });

  it('that is fixed is announced at its start, with its end', async () => {
    const [starting] = ofKind(
      await itemsFor([block({ fixed: true })]),
      'starting',
    );

    expect(starting).toMatchObject({
      kind: 'starting',
      fireAt: '2026-09-21T14:00:00-03:00',
      title: 'Revisão de código',
      body: 'Começa agora, até 15:00',
      timeSensitive: true,
    });
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

    expect(ofKind(items, 'confirmStart')).toHaveLength(1);
    expect(ofKind(items, 'almostFinishing')).toHaveLength(0);
  });

  it('of exactly twenty minutes still gets one', async () => {
    const edge = block({ endTime: '2026-09-21T17:20:00.000Z' });

    expect(ofKind(await itemsFor([edge]), 'almostFinishing')).toHaveLength(1);
  });

  it('carries its conversation, so a tap can open it', async () => {
    const items = await itemsFor([block({ threadSlug: 'revisao-de-codigo' })]);

    expect(ofKind(items, 'confirmStart')[0].threadSlug).toBe(
      'revisao-de-codigo',
    );
  });

  it('that Focus did not book gets nothing', async () => {
    const meeting = block({ managed: false });
    const items = await itemsFor([meeting]);

    expect(ofKind(items, 'starting')).toHaveLength(0);
    expect(ofKind(items, 'confirmStart')).toHaveLength(0);
    expect(ofKind(items, 'almostFinishing')).toHaveLength(0);
  });

  it('already running keeps only what is still ahead', async () => {
    // 11:30 to 13:00: started, not finished.
    const running = block({
      startTime: '2026-09-21T14:30:00.000Z',
      endTime: '2026-09-21T16:00:00.000Z',
    });
    const items = await itemsFor([running]);

    expect(ofKind(items, 'confirmStart')).toHaveLength(0);
    expect(ofKind(items, 'almostFinishing')[0].fireAt).toBe(
      '2026-09-21T12:50:00-03:00',
    );
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
    const [before] = ofKind(await itemsFor([block()]), 'confirmStart');
    const [after] = ofKind(
      await itemsFor([
        block({
          startTime: '2026-09-21T17:30:00.000Z',
          endTime: '2026-09-21T18:30:00.000Z',
        }),
      ]),
      'confirmStart',
    );

    expect(after.id).not.toBe(before.id);
  });

  it('change when the block is renamed', async () => {
    const [before] = ofKind(await itemsFor([block()]), 'confirmStart');
    const [after] = ofKind(
      await itemsFor([block({ title: 'Outra coisa' })]),
      'confirmStart',
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
      expect(item.threadSlug).toBeUndefined();
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
