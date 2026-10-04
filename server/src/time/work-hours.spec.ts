import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  earliestStart,
  formatRange,
  nextFreeSlot,
  WORK_DAY_END_HOUR,
  WORK_DAY_START_HOUR,
  workWindowFor,
} from './work-hours';
import { instantOf, wallOf } from './zone';

/**
 * The zone the tests are written in.
 *
 * Deliberately not the machine's. Every date below is built as a wall-clock
 * reading in this zone and every assertion reads back in it, so the suite says
 * the same thing on a laptop in São Paulo and in a container running in UTC —
 * which is the bug these functions were changed for.
 */
const ZONE = 'America/Sao_Paulo';

/** A wall-clock moment in [ZONE], written the way the tests read best. */
function at(day: number, hour: number, minute = 0): Date {
  return instantOf(
    { year: 2026, month: 9, day, hour, minute, second: 0 },
    ZONE,
  );
}

describe('the working day', () => {
  it('runs from seven to ten', () => {
    const window = workWindowFor(at(21, 12), ZONE);

    expect(wallOf(window.start, ZONE).hour).toBe(WORK_DAY_START_HOUR);
    expect(wallOf(window.end, ZONE).hour).toBe(WORK_DAY_END_HOUR);
  });

  it('answers the same day before it has started', () => {
    expect(workWindowFor(at(21, 5), ZONE).start).toEqual(at(21, 7));
  });

  it('answers tomorrow once it is over', () => {
    expect(workWindowFor(at(21, 23), ZONE).start).toEqual(at(22, 7));
  });

  it('never starts anything before the day does', () => {
    expect(earliestStart(at(21, 3), ZONE)).toEqual(at(21, 7));
    expect(earliestStart(at(21, 9, 12), ZONE)).toEqual(at(21, 9, 12));
  });

  it("measures the day in the zone it is given, not the server's", () => {
    // Twenty to eight in the evening in São Paulo is twenty to eleven in
    // London and twenty to midnight UTC. The evening is still the evening: it
    // is inside the working day, and nothing about it belongs to tomorrow.
    const evening = at(21, 19, 40);

    expect(evening < workWindowFor(evening, ZONE).end).toBe(true);
    expect(earliestStart(evening, ZONE)).toEqual(evening);
    expect(nextFreeSlot(evening, 30, [], ZONE).start).toEqual(evening);
  });
});

describe('finding a slot', () => {
  it('starts at the minute asked for when nothing is booked', () => {
    expect(nextFreeSlot(at(21, 9, 12), 45, [], ZONE)).toEqual({
      start: at(21, 9, 12),
      end: at(21, 9, 57),
    });
  });

  it('steps over a booked block, keeping the gap', () => {
    const busy = [{ start: at(21, 9, 0), end: at(21, 10, 0) }];

    expect(nextFreeSlot(at(21, 9, 30), 30, busy, ZONE)).toEqual({
      start: addMinutes(at(21, 10, 0), BLOCK_GAP_MINUTES),
      end: addMinutes(at(21, 10, 35), 0),
    });
  });

  it('walks past a whole run of them', () => {
    const busy = [
      { start: at(21, 9, 0), end: at(21, 10, 0) },
      { start: at(21, 10, 0), end: at(21, 11, 0) },
    ];

    expect(nextFreeSlot(at(21, 8, 55), 30, busy, ZONE).start).toEqual(
      at(21, 11, 5),
    );
  });

  it('spills into the next day rather than past ten at night', () => {
    expect(nextFreeSlot(at(21, 21, 30), 60, [], ZONE).start).toEqual(
      at(22, 7, 0),
    );
  });
});

describe('writing time down', () => {
  it('writes a range the way a card does', () => {
    expect(formatRange({ start: at(21, 9, 5), end: at(21, 9, 50) }, ZONE)).toBe(
      '09:05-09:50',
    );
  });

  it('writes the hour the calendar keeps, not the one the server has', () => {
    const interval = { start: at(21, 19, 40), end: at(21, 20, 10) };

    expect(formatRange(interval, ZONE)).toBe('19:40-20:10');
    expect(formatRange(interval, 'UTC')).toBe('22:40-23:10');
  });
});
