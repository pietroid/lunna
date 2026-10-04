import { firstOccurrence, parseTime } from './routine-dates';
import { isoIn } from '../time/zone';

const ZONE = 'America/Sao_Paulo';

/** Saturday 26/09/2026, 15:00 in São Paulo. */
const SATURDAY = new Date('2026-09-26T18:00:00.000Z');

describe('a routine', () => {
  it('starts today when today is one of its days', () => {
    const first = firstOccurrence(
      SATURDAY,
      { hour: 12, minute: 30 },
      'daily',
      ZONE,
    );

    expect(isoIn(first, ZONE)).toBe('2026-09-26T12:30:00-03:00');
  });

  it('on weekdays starts on Monday when written down on a Saturday', () => {
    const first = firstOccurrence(
      SATURDAY,
      { hour: 7, minute: 0 },
      'weekdays',
      ZONE,
    );

    expect(isoIn(first, ZONE)).toBe('2026-09-28T07:00:00-03:00');
  });

  it('on the weekend starts today when today is Saturday', () => {
    const first = firstOccurrence(
      SATURDAY,
      { hour: 9, minute: 0 },
      'weekend',
      ZONE,
    );

    expect(isoIn(first, ZONE)).toBe('2026-09-26T09:00:00-03:00');
  });

  it('reads an hour written as HH:MM, and nothing else', () => {
    expect(parseTime('7:05')).toEqual({ hour: 7, minute: 5 });
    expect(parseTime('24:00')).toBeUndefined();
    expect(parseTime('meio-dia')).toBeUndefined();
  });
});
