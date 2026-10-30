import {
  capacityShare,
  Cycle,
  cycleDayOf,
  DEFAULT_RHYTHM,
  DEFAULT_REST,
  marksFor,
  marksOf,
  markOf,
  nextPeriodOf,
  NO_MARKS,
  Rhythm,
} from './day-kinds';
import { DEFAULT_WORK_DAY } from './work-hours';
import { instantOf } from './zone';

// Friday 30 October 2026; 31 Oct and 1 Nov are the weekend.
const CYCLE: Cycle = {
  lastStart: '2026-10-28',
  length: 28,
  periodLength: 5,
  periodKind: 'light',
};

const withCycle = (
  cycle: Partial<Cycle> = {},
  rest = DEFAULT_REST,
): Rhythm => ({
  rest,
  daysOff: [],
  cycle: { ...CYCLE, ...cycle },
});

describe('the kind of a day', () => {
  it('rests on the weekend unless the person changed it', () => {
    expect(markOf(DEFAULT_RHYTHM, '2026-10-30').kind).toBe('work');
    expect(markOf(DEFAULT_RHYTHM, '2026-10-31')).toEqual({
      day: '2026-10-31',
      kind: 'off',
      reason: 'weekend',
    });
    expect(markOf(DEFAULT_RHYTHM, '2026-11-01').kind).toBe('off');
    const working = {
      ...DEFAULT_RHYTHM,
      rest: { ...DEFAULT_REST, saturday: 'work' as const },
    };
    expect(markOf(working, '2026-10-31').kind).toBe('work');
  });

  it('makes the period light, with the budget, by default', () => {
    expect(markOf(withCycle(), '2026-10-29')).toEqual({
      day: '2026-10-29',
      kind: 'light',
      reason: 'period',
      budgetMinutes: 180,
      cycle: { day: 2, length: 28, phase: 'menstrual' },
    });
    expect(markOf(withCycle({ periodKind: 'work' }), '2026-10-29').kind).toBe(
      'work',
    );
  });

  it('lets a date written down win, and the period still apply over a weekend put back', () => {
    const rhythm: Rhythm = {
      ...withCycle(),
      daysOff: [
        { id: 'a', day: '2026-10-31', title: '', kind: 'work' },
        { id: 'b', day: '2026-11-05', title: 'Feriado', kind: 'off' },
        { id: 'c', day: '2026-11-07', title: '', kind: 'work' },
      ],
    };
    // A Saturday back to work, in the period: light, not a full day.
    expect(markOf(rhythm, '2026-10-31')).toMatchObject({
      kind: 'light',
      reason: 'period',
    });
    expect(markOf(rhythm, '2026-11-05')).toMatchObject({
      kind: 'off',
      reason: 'day_off',
    });
    expect(markOf(rhythm, '2026-11-07').kind).toBe('work');
    // The Sunday of the first weekend was not put back.
    expect(markOf(rhythm, '2026-11-01')).toMatchObject({
      kind: 'off',
      reason: 'weekend',
    });
  });

  it('works the four phases out of a 28-day cycle', () => {
    const phase = (day: string) => cycleDayOf(CYCLE, day)?.phase;
    expect(cycleDayOf(CYCLE, '2026-10-27')).toBeUndefined();
    expect(phase('2026-11-01')).toBe('menstrual'); // day 5
    expect(phase('2026-11-02')).toBe('follicular'); // day 6
    expect(phase('2026-11-08')).toBe('follicular'); // day 12
    expect(phase('2026-11-09')).toBe('ovulatory'); // day 13
    expect(phase('2026-11-11')).toBe('ovulatory'); // day 15
    expect(phase('2026-11-12')).toBe('luteal'); // day 16
    expect(cycleDayOf(CYCLE, '2026-11-25')).toEqual({
      day: 1,
      length: 28,
      phase: 'menstrual',
    });
  });

  it('moves ovulation with a 35-day cycle', () => {
    const long = { ...CYCLE, length: 35 };
    // Ovulation is fourteen days before the next period: day 21.
    expect(cycleDayOf(long, '2026-11-17')).toMatchObject({
      day: 21,
      phase: 'ovulatory',
    });
    expect(cycleDayOf(long, '2026-11-14')?.phase).toBe('follicular');
    expect(nextPeriodOf(long, '2026-10-30')).toBe('2026-12-02');
  });

  it('counts the cycles from the person’s correction', () => {
    const corrected = { ...CYCLE, nextStart: '2026-11-23' };
    expect(nextPeriodOf(CYCLE, '2026-10-30')).toBe('2026-11-25');
    expect(nextPeriodOf(corrected, '2026-10-30')).toBe('2026-11-23');
    // The cycle before it is 26 days long, and ovulation moves with it.
    expect(cycleDayOf(corrected, '2026-11-09')).toMatchObject({
      day: 13,
      length: 26,
      phase: 'ovulatory',
    });
    expect(cycleDayOf(corrected, '2026-11-23')).toMatchObject({
      day: 1,
      phase: 'menstrual',
    });
    expect(cycleDayOf(corrected, '2026-12-21')?.day).toBe(1);
  });

  it('sends a mark for every day that is not a plain working day, or has a cycle', () => {
    expect(
      marksFor(marksOf(DEFAULT_RHYTHM), '2026-10-30', 4).map((it) => it.day),
    ).toEqual(['2026-10-31', '2026-11-01']);
    expect(marksFor(marksOf(withCycle()), '2026-10-30', 4)).toHaveLength(4);
    expect(marksFor(NO_MARKS, '2026-10-30', 4)).toEqual([]);
  });
});

describe.each(['America/Sao_Paulo', 'Asia/Tokyo', 'UTC'])(
  'the share of working time gone, in %s',
  (zone) => {
    const at = (day: number, hour: number) =>
      instantOf(
        { year: 2026, month: 10, day, hour, minute: 0, second: 0 },
        zone,
      );

    it('counts nothing on a weekend off', () => {
      const marks = marksOf(DEFAULT_RHYTHM);
      // Begun Friday 07:00, due the end of Monday: two working days.
      const from = at(30, 7);
      const to = instantOf(
        { year: 2026, month: 11, day: 3, hour: 0, minute: 0, second: 0 },
        zone,
      );
      const share = (now: Date) =>
        capacityShare(
          from,
          to,
          now,
          marks,
          zone,
          DEFAULT_WORK_DAY,
          '2026-10-30',
          '2026-11-02',
        );
      // Friday over: half. The weekend passes and it is still half.
      expect(share(at(30, 23))).toBeCloseTo(0.5);
      expect(share(at(31, 15))).toBeCloseTo(0.5);
      expect(
        share(
          instantOf(
            { year: 2026, month: 11, day: 2, hour: 7, minute: 0, second: 0 },
            zone,
          ),
        ),
      ).toBeCloseTo(0.5);
      // Were every day a working one, Saturday would count: 23 of 60 hours.
      expect(
        capacityShare(
          from,
          to,
          at(31, 15),
          NO_MARKS,
          zone,
          DEFAULT_WORK_DAY,
          '2026-10-30',
          '2026-11-02',
        ),
      ).toBeCloseTo(23 / 60);
    });

    it('is whole when there is no working time left at all', () => {
      expect(
        capacityShare(
          at(31, 8),
          at(31, 20),
          at(31, 9),
          marksOf(DEFAULT_RHYTHM),
          zone,
          DEFAULT_WORK_DAY,
          '2026-10-31',
          '2026-10-31',
        ),
      ).toBe(1);
    });
  },
);
