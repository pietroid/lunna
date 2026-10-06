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
  it('starts a block no earlier than the floor the user gave it', () => {
    const queue = [
      task('a', 30),
      { ...task('b', 30), notBefore: at(13) },
      task('c', 30),
    ];

    const placed = relayout(queue, [], at(9), ZONE);

    expect(reads(placed, 'a')).toBe('09:00-09:30');
    // The gap before it is left alone, and what follows it follows it.
    expect(reads(placed, 'b')).toBe('13:00-13:30');
    expect(reads(placed, 'c')).toBe('13:35-14:05');
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
