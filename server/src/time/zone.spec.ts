import {
  addDaysIn,
  atHourIn,
  formatDayIn,
  formatTimeIn,
  instantOf,
  isoIn,
  sameDayIn,
  systemZone,
  wallOf,
} from './zone';

const SAO_PAULO = 'America/Sao_Paulo';
const NEW_YORK = 'America/New_York';

describe('reading a clock in a zone', () => {
  it('reads the same instant differently in two zones', () => {
    // 22:40 UTC.
    const instant = new Date('2026-09-21T22:40:00.000Z');

    expect(formatTimeIn(instant, SAO_PAULO)).toBe('19:40');
    expect(formatTimeIn(instant, 'UTC')).toBe('22:40');
  });

  it('puts an evening in São Paulo on the day the calendar says', () => {
    // The whole bug, in one assertion. Late evening there is the small hours
    // UTC, so anything asking the server's clock what day it is gets the
    // wrong one.
    const instant = new Date('2026-09-22T01:30:00.000Z');

    expect(formatDayIn(instant, SAO_PAULO)).toBe('21-09-2026');
    expect(formatDayIn(instant, 'UTC')).toBe('22-09-2026');
  });

  it('round-trips a wall reading through an instant', () => {
    const wall = {
      year: 2026,
      month: 9,
      day: 21,
      hour: 19,
      minute: 40,
      second: 0,
    };

    expect(wallOf(instantOf(wall, SAO_PAULO), SAO_PAULO)).toEqual(wall);
  });

  it('names an hour on the day the instant falls on', () => {
    const seven = atHourIn(new Date('2026-09-22T01:30:00.000Z'), 7, SAO_PAULO);

    // Still the 21st there, so seven o'clock is the 21st's seven o'clock.
    expect(formatDayIn(seven, SAO_PAULO)).toBe('21-09-2026');
    expect(formatTimeIn(seven, SAO_PAULO)).toBe('07:00');
  });
});

describe('the day either side of a clock change', () => {
  it('keeps the hour when a day is added across a spring change', () => {
    // New York moves to daylight saving in the small hours of 8 March 2026,
    // so that day is 23 hours long. Seven in the morning is still seven in
    // the morning the day after.
    const before = atHourIn(new Date('2026-03-07T12:00:00.000Z'), 7, NEW_YORK);
    const after = addDaysIn(before, 1, NEW_YORK);

    expect(formatTimeIn(after, NEW_YORK)).toBe('07:00');
    expect(formatDayIn(after, NEW_YORK)).toBe('08-03-2026');
    // 23 hours apart, which is the whole reason days are added as days.
    expect(after.getTime() - before.getTime()).toBe(23 * 3_600_000);
  });

  it('keeps the hour across an autumn change', () => {
    const before = atHourIn(new Date('2026-10-31T12:00:00.000Z'), 7, NEW_YORK);
    const after = addDaysIn(before, 1, NEW_YORK);

    expect(formatTimeIn(after, NEW_YORK)).toBe('07:00');
    expect(after.getTime() - before.getTime()).toBe(25 * 3_600_000);
  });

  it('rolls over the end of a month', () => {
    const last = atHourIn(new Date('2026-09-30T12:00:00.000Z'), 9, SAO_PAULO);

    expect(formatDayIn(addDaysIn(last, 1, SAO_PAULO), SAO_PAULO)).toBe(
      '01-10-2026',
    );
  });
});

describe('two instants on one day', () => {
  it('calls a morning and an evening the same day where it is one', () => {
    const morning = new Date('2026-09-21T13:00:00.000Z');
    const evening = new Date('2026-09-22T01:30:00.000Z');

    expect(sameDayIn(morning, evening, SAO_PAULO)).toBe(true);
    expect(sameDayIn(morning, evening, 'UTC')).toBe(false);
  });
});

describe('the fallback zone', () => {
  it('is a zone something can actually be formatted in', () => {
    expect(() => formatTimeIn(new Date(), systemZone())).not.toThrow();
  });
});

describe('an instant with its offset', () => {
  it('carries the offset the zone has at that instant', () => {
    const at = new Date('2026-09-21T17:00:00.000Z');

    expect(isoIn(at, SAO_PAULO)).toBe('2026-09-21T14:00:00-03:00');
    expect(isoIn(at, 'UTC')).toBe('2026-09-21T17:00:00+00:00');
  });

  it('follows a daylight-saving change', () => {
    expect(isoIn(new Date('2026-07-01T16:00:00.000Z'), NEW_YORK)).toBe(
      '2026-07-01T12:00:00-04:00',
    );
    expect(isoIn(new Date('2026-12-01T17:00:00.000Z'), NEW_YORK)).toBe(
      '2026-12-01T12:00:00-05:00',
    );
  });

  it('reads back as the same instant', () => {
    const at = new Date('2026-09-21T17:04:05.000Z');

    expect(new Date(isoIn(at, SAO_PAULO)).getTime()).toBe(at.getTime());
  });
});
