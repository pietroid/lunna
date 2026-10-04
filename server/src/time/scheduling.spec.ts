import { PlannedBlock, relayout } from './scheduling';
import { Interval } from './work-hours';
import { formatTimeIn, instantOf } from './zone';

/** A zone that is not the machine's, so the suite reads the same anywhere. */
const ZONE = 'America/Sao_Paulo';

function at(hour: number, minute = 0): Date {
  return instantOf(
    { year: 2026, month: 9, day: 21, hour, minute, second: 0 },
    ZONE,
  );
}

function block(
  id: string,
  from: Date,
  minutes: number,
  fixed = false,
): PlannedBlock {
  return {
    id,
    minutes,
    fixed,
    interval: { start: from, end: new Date(from.getTime() + minutes * 60_000) },
  };
}

function reads(placed: Map<string, Interval>, id: string): string {
  const slot = placed.get(id);
  if (slot === undefined) return 'unplaced';

  return `${formatTimeIn(slot.start, ZONE)}-${formatTimeIn(slot.end, ZONE)}`;
}

describe('laying the day out', () => {
  it('starts a block no earlier than the floor the user gave it', () => {
    const queue = [
      block('a', at(9), 30),
      { ...block('b', at(10), 30), notBefore: at(13) },
      block('c', at(11), 30),
    ];

    const placed = relayout(queue, [], at(9), ZONE);

    expect(reads(placed, 'a')).toBe('09:00-09:30');
    // The gap before it is left alone, and what follows it follows it.
    expect(reads(placed, 'b')).toBe('13:00-13:30');
    expect(reads(placed, 'c')).toBe('13:35-14:05');
  });

  it('packs the queue from now, with a gap between blocks', () => {
    const queue = [block('a', at(15), 30), block('b', at(16), 45)];

    const placed = relayout(queue, [], at(9), ZONE);

    expect(reads(placed, 'a')).toBe('09:00-09:30');
    expect(reads(placed, 'b')).toBe('09:35-10:20');
  });

  it('never moves a fixed block, and never assigns it an hour', () => {
    const anchor = block('meeting', at(10), 60, true);
    const queue = [block('a', at(9), 30), anchor];

    const placed = relayout(queue, [anchor.interval], at(9), ZONE);

    expect(placed.has('meeting')).toBe(false);
    expect(reads(placed, 'a')).toBe('09:00-09:30');
  });

  it('fills the gap before a fixed block when the work fits in it', () => {
    const anchor = block('meeting', at(11), 60, true);
    const queue = [anchor, block('a', at(14), 45)];

    const placed = relayout(queue, [anchor.interval], at(9), ZONE);

    // Queued after the meeting, but the meeting is an anchor rather than a
    // cursor, so the morning is still free and that is where it goes.
    expect(reads(placed, 'a')).toBe('09:00-09:45');
  });

  it('steps over a fixed block the work does not fit before', () => {
    const anchor = block('meeting', at(9, 30), 60, true);
    const queue = [block('a', at(14), 60), anchor];

    const placed = relayout(queue, [anchor.interval], at(9), ZONE);

    expect(reads(placed, 'a')).toBe('10:35-11:35');
  });

  it('keeps the queue order for everything flexible', () => {
    const queue = [
      block('third', at(9), 30),
      block('first', at(10), 30),
      block('second', at(11), 30),
    ];

    const placed = relayout(queue, [], at(8), ZONE);

    expect(reads(placed, 'third')).toBe('08:00-08:30');
    expect(reads(placed, 'first')).toBe('08:35-09:05');
    expect(reads(placed, 'second')).toBe('09:10-09:40');
  });
});
