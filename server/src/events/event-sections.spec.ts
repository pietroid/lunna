import { instantOf } from '../time/zone';
import { intervalOf, sectionOf } from './event-sections';

/**
 * The zone the day is read in.
 *
 * Not the machine's: "hoje" is the user's day in their calendar's zone, and
 * the point of these tests is that the answer does not depend on where the
 * server happens to be running.
 */
const ZONE = 'America/Sao_Paulo';

function at(day: number, hour: number, minute = 0): Date {
  return instantOf(
    { year: 2026, month: 9, day, hour, minute, second: 0 },
    ZONE,
  );
}

/** The same day everything else in this file happens on. */
function on21(hour: number, minute = 0): Date {
  return at(21, hour, minute);
}

function span(start: Date, end: Date) {
  return { start, end };
}

describe('the section the clock puts a card in', () => {
  it('puts something already running in agora', () => {
    expect(sectionOf(at(21, 10, 30), span(at(21, 10), at(21, 11)), ZONE)).toBe(
      'agora',
    );
  });

  it('draws nothing whose hour has run out', () => {
    expect(
      sectionOf(at(21, 16), span(at(21, 9), at(21, 10)), ZONE),
    ).toBeUndefined();
  });

  it('lets go of a block the moment its last minute is up', () => {
    const block = span(on21(11, 20), on21(11, 25));

    expect(sectionOf(on21(11, 24), block, ZONE)).toBe('agora');
    expect(sectionOf(on21(11, 25), block, ZONE)).toBeUndefined();
    expect(sectionOf(on21(11, 26), block, ZONE)).toBeUndefined();
  });

  it('puts the rest of today in hoje', () => {
    expect(sectionOf(at(21, 10), span(at(21, 15), at(21, 16)), ZONE)).toBe(
      'hoje',
    );
  });

  it('puts the next day in amanha', () => {
    expect(sectionOf(at(21, 10), span(at(22, 9), at(22, 10)), ZONE)).toBe(
      'amanha',
    );
  });

  it('draws nothing further out than tomorrow', () => {
    expect(
      sectionOf(at(21, 10), span(at(23, 9), at(23, 10)), ZONE),
    ).toBeUndefined();
  });

  it('keeps an evening block on the day the calendar says', () => {
    // Half past seven in the evening in São Paulo is half past ten UTC. Read
    // against the server's clock this landed in "amanhã"; read against the
    // calendar's, it is the rest of today.
    expect(sectionOf(at(21, 18), span(at(21, 19, 30), at(21, 20)), ZONE)).toBe(
      'hoje',
    );
  });

  it('has no interval without an event', () => {
    expect(intervalOf(undefined)).toBeUndefined();
  });

  it('has no interval when the ends do not parse', () => {
    expect(
      intervalOf({ startTime: 'never', endTime: 'never' }),
    ).toBeUndefined();
  });
});
