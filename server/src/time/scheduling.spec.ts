import { marksOf } from './day-kinds';
import { QueuedBlock, relayout } from './scheduling';
import { Interval } from './work-hours';
import { formatDayIn, formatTimeIn, instantOf } from './zone';

/** A zone that is not the machine's, so the suite reads the same anywhere. */
const ZONE = 'America/Sao_Paulo';

function at(hour: number, minute = 0, day = 21): Date {
  return instantOf(
    { year: 2026, month: 9, day, hour, minute, second: 0 },
    ZONE,
  );
}

function task(id: string, minutes: number): QueuedBlock {
  return { id, minutes };
}

function meeting(from: Date, minutes: number): Interval {
  return { start: from, end: new Date(from.getTime() + minutes * 60_000) };
}

function reads(placed: Map<string, Interval>, id: string): string {
  const slot = placed.get(id);
  if (slot === undefined) return 'unplaced';

  return `${formatTimeIn(slot.start, ZONE)}-${formatTimeIn(slot.end, ZONE)}`;
}

describe('laying the queue out', () => {
  it('keeps an anchored block at its hour and flows the queue around it', () => {
    const queue = [
      task('a', 30),
      { ...task('b', 30), anchor: at(13) },
      task('c', 30),
    ];

    const placed = relayout(queue, [], at(9), ZONE);

    expect(reads(placed, 'a')).toBe('09:00-09:30');
    expect(reads(placed, 'b')).toBe('13:00-13:30');
    // Its place in the queue means nothing: the next one fills the morning.
    expect(reads(placed, 'c')).toBe('09:35-10:05');
  });

  it('hops a queued block over an anchored one it does not fit before', () => {
    const queue = [
      task('a', 90),
      { ...task('lunch', 60), anchor: at(12) },
      task('b', 60),
    ];

    const placed = relayout(queue, [], at(11), ZONE);

    expect(reads(placed, 'lunch')).toBe('12:00-13:00');
    expect(reads(placed, 'a')).toBe('13:05-14:35');
    expect(reads(placed, 'b')).toBe('14:40-15:40');
  });

  it('pushes an anchored block that something already there runs into', () => {
    const queue = [{ ...task('lunch', 60), anchor: at(12) }];

    const placed = relayout(queue, [meeting(at(11, 30), 60)], at(9), ZONE);

    expect(reads(placed, 'lunch')).toBe('12:35-13:35');
  });

  it('pushes an anchored block along with the one before it', () => {
    const queue = [
      { ...task('second', 30), anchor: at(12, 15) },
      { ...task('first', 60), anchor: at(11, 30) },
    ];

    const placed = relayout(queue, [meeting(at(11), 60)], at(9), ZONE);

    expect(reads(placed, 'first')).toBe('12:05-13:05');
    expect(reads(placed, 'second')).toBe('13:10-13:40');
  });

  it('waits at now with an anchored block whose hour has passed', () => {
    const queue = [task('a', 30), { ...task('lunch', 60), anchor: at(12) }];

    const placed = relayout(queue, [], at(12, 20), ZONE);

    expect(reads(placed, 'lunch')).toBe('12:20-13:20');
    expect(reads(placed, 'a')).toBe('13:25-13:55');
  });

  it('packs the queue from now, with a gap between blocks', () => {
    const placed = relayout([task('a', 30), task('b', 45)], [], at(9), ZONE);

    expect(reads(placed, 'a')).toBe('09:00-09:30');
    expect(reads(placed, 'b')).toBe('09:35-10:20');
  });

  it('fills the gap before a fixed block when the work fits in it', () => {
    const placed = relayout(
      [task('a', 45)],
      [meeting(at(11), 60)],
      at(9),
      ZONE,
    );

    expect(reads(placed, 'a')).toBe('09:00-09:45');
  });

  it('steps over a fixed block the work does not fit before', () => {
    const placed = relayout(
      [task('a', 60)],
      [meeting(at(9, 30), 60)],
      at(9),
      ZONE,
    );

    expect(reads(placed, 'a')).toBe('10:35-11:35');
  });

  it('keeps the queue order', () => {
    const queue = [task('third', 30), task('first', 30), task('second', 30)];

    const placed = relayout(queue, [], at(8), ZONE);

    expect(reads(placed, 'third')).toBe('08:00-08:30');
    expect(reads(placed, 'first')).toBe('08:35-09:05');
    expect(reads(placed, 'second')).toBe('09:10-09:40');
  });

  it('runs on into the following days when the queue is longer than one', () => {
    // Fifteen hours of work starting at nine at night: an hour's worth fits
    // before ten, then the rest fills the next working day and spills over.
    const queue = Array.from({ length: 20 }, (_, n) => task(`t${n}`, 55));

    const placed = relayout(queue, [], at(21), ZONE);

    expect(reads(placed, 't0')).toBe('21:00-21:55');
    expect(formatDayIn(placed.get('t1')!.start, ZONE)).toBe('22-09-2026');
    expect(reads(placed, 't1')).toBe('07:00-07:55');
    expect(formatDayIn(placed.get('t19')!.start, ZONE)).toBe('23-09-2026');
  });
});

/** An hour of a day of October 2026: Friday the 30th has the weekend after it. */
function oct(day: number, hour: number): Date {
  return instantOf(
    { year: 2026, month: 10, day, hour, minute: 0, second: 0 },
    ZONE,
  );
}

describe('laying the queue out over the kinds of day', () => {
  // Friday 30 October 2026, 09:00; the weekend after it is off.
  const from = oct(30, 9);
  const kinds = (light: boolean, budget = 180) =>
    marksOf({
      rest: { saturday: 'off', sunday: 'off', lightMinutes: budget },
      daysOff: [],
      ...(light
        ? {
            cycle: {
              lastStart: '2026-10-30',
              length: 28,
              periodLength: 1,
              periodKind: 'light' as const,
            },
          }
        : {}),
    });
  const dayOf = (placed: Map<string, Interval>, id: string) =>
    formatDayIn(placed.get(id)!.start, ZONE);

  it('puts nothing on a day off: what does not fit Friday goes to Monday', () => {
    const queue = [task('a', 600), task('b', 300)];
    const placed = relayout(queue, [], from, ZONE, undefined, kinds(false));
    expect(dayOf(placed, 'a')).toBe('30-10-2026');
    expect(dayOf(placed, 'b')).toBe('02-11-2026');
    expect(reads(placed, 'b')).toBe('07:00-12:00');
  });

  it('keeps a delivery’s task off a light day, and lets a loose one stay', () => {
    const queue = [
      { ...task('client', 60), artifact: true },
      task('loose', 60),
    ];
    const placed = relayout(queue, [], from, ZONE, undefined, kinds(true));
    expect(dayOf(placed, 'client')).toBe('02-11-2026');
    expect(reads(placed, 'loose')).toBe('09:00-10:00');
  });

  it('stops a light day at its budget', () => {
    const queue = [task('a', 120), task('b', 60), task('c', 30)];
    const placed = relayout(queue, [], from, ZONE, undefined, kinds(true, 180));
    expect(reads(placed, 'a')).toBe('09:00-11:00');
    expect(reads(placed, 'b')).toBe('11:05-12:05');
    // Three hours are taken: the next goes to the next working day.
    expect(dayOf(placed, 'c')).toBe('02-11-2026');
  });

  it('leaves an anchored task at its hour on a day off', () => {
    const saturday = oct(31, 10);
    const placed = relayout(
      [{ ...task('a', 60), anchor: saturday }],
      [],
      from,
      ZONE,
      undefined,
      kinds(false),
    );
    expect(placed.get('a')!.start).toEqual(saturday);
  });
});
