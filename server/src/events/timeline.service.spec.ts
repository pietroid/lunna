import { ConfigService } from '@nestjs/config';
import { CalendarService } from '../calendar/calendar.service';
import { MemoryCalendarStore } from '../calendar/calendar.store';
import { CalendarUser } from '../calendar/calendar.types';
import { MemoryTaskStore } from '../tasks/task.store';
import { formatTimeIn } from '../time/zone';
import { TimelineService } from './timeline.service';

/**
 * The day, laid out in the person's zone and never the server's.
 *
 * The rest of the suite runs in São Paulo for people in São Paulo, so a
 * slip that read the process's zone instead of the person's would pass
 * there. Here the person is in Tokyo and the process is not: every hour and
 * every day below is only right if it was worked out in Tokyo.
 */
const TOKYO = 'Asia/Tokyo';
const PERSON: CalendarUser = { id: 'u1', timeZone: TOKYO };

/** 13:00 UTC: ten in the morning in São Paulo, ten at night in Tokyo. */
const NOW = new Date('2026-03-10T13:00:00Z');

describe('the day in the person’s zone', () => {
  let tasks: MemoryTaskStore;
  let timeline: TimelineService;

  beforeEach(() => {
    tasks = new MemoryTaskStore();
    const config = { get: () => undefined } as unknown as ConfigService;
    timeline = new TimelineService(
      new CalendarService(new MemoryCalendarStore(), config),
      tasks,
    );
  });

  it('puts a task written at ten at night on the next morning', async () => {
    await tasks.insert(PERSON, { title: 'Ler', minutes: 30, position: 0 });

    const view = timeline.view(await timeline.day(PERSON, 2, NOW));
    const [task] = view.tasks;

    // In São Paulo it would be ten in the morning, and today.
    expect(formatTimeIn(new Date(task.startTime), TOKYO)).toBe('07:00');
    expect(task.day).toBe('2026-03-11');
    expect(task.awaitingStart).toBe(false);
  });

  it('ends today at the person’s midnight', async () => {
    await tasks.insert(PERSON, { title: 'Ler', minutes: 30, position: 0 });

    const today = timeline.view(await timeline.day(PERSON, 1, NOW));
    const twoDays = timeline.view(await timeline.day(PERSON, 2, NOW));

    // Tomorrow morning in Tokyo is still today in São Paulo, and is not
    // drawn when only today was asked for.
    expect(today.tasks).toHaveLength(1);
    expect(today.cards).toEqual([]);
    expect(twoDays.cards.map((it) => it.title)).toEqual(['Ler']);
  });
});
