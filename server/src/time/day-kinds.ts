/**
 * What kind of day each date is: work, light or off.
 *
 * Three sources say it. **A date the person wrote down wins** (a holiday,
 * or a weekend day put back to work); otherwise the strictest of the
 * weekend's rule and the cycle's period (off over light over work). A date
 * put back to work undoes the weekend only: the period still applies over
 * it, so a worked Saturday in the period is a light day.
 *
 * Every date here is a calendar date (`YYYY-MM-DD`) in the person's zone,
 * and everything is arithmetic on the date alone. Which date an instant
 * falls on is the caller's to say ([isoDayIn]).
 *
 * The app's `Cycle` works the phases out the same way, to draw Ciclo's
 * grid; a change to one is a change to both.
 */
import { addDays, daysBetween } from '../artifacts/stretch';
import { Interval, WorkDay } from './work-hours';
import { atMinuteIn, instantOf, Zone } from './zone';

/** How much work a day takes. */
export type DayKind = 'work' | 'light' | 'off';

export const DAY_KINDS: readonly DayKind[] = ['work', 'light', 'off'];

/** Why a day is not a working day. */
export type DayReason = 'weekend' | 'period' | 'day_off';

/** The four phases of a cycle, in their order. */
export type CyclePhase = 'menstrual' | 'follicular' | 'ovulatory' | 'luteal';

/** The cycle, as the person tells it. */
export interface Cycle {
  /** The first day of the last period. */
  lastStart: string;
  /** Days from one period's first day to the next's: 21 to 45. */
  length: number;
  /** Days the period lasts: 1 to 10. */
  periodLength: number;
  /** What a day of the period is to the queue. */
  periodKind: DayKind;
  /** The next period's first day as the person corrected it, after today. */
  nextStart?: string;
}

/** What the weekend is, and how much a light day takes. */
export interface RestRules {
  saturday: DayKind;
  sunday: DayKind;
  /** Minutes of loose tasks the queue puts on a light day. */
  lightMinutes: number;
}

/** A date written down: a day off, or a weekend day put back to work. */
export interface DayOff {
  id: string;
  day: string;
  title: string;
  kind: 'off' | 'work';
}

/** Everything that decides the kind of a day. */
export interface Rhythm {
  /** Absent until a first period is written down. */
  cycle?: Cycle;
  rest: RestRules;
  /** Earliest first. */
  daysOff: DayOff[];
}

/** The weekend nobody has changed: both days off. */
export const DEFAULT_REST: RestRules = {
  saturday: 'off',
  sunday: 'off',
  lightMinutes: 180,
};

export const DEFAULT_CYCLE_LENGTH = 28;
export const DEFAULT_PERIOD_LENGTH = 5;

/** A rhythm with nothing set: the weekend off, no cycle, no dates. */
export const DEFAULT_RHYTHM: Rhythm = { rest: DEFAULT_REST, daysOff: [] };

/** Where a date is in its cycle. */
export interface CycleDay {
  /** From 1. */
  day: number;
  /** How long the cycle it falls in lasts. */
  length: number;
  phase: CyclePhase;
}

/** One date, as the timeline and the agent read it. */
export interface DayMark {
  day: string;
  kind: DayKind;
  /** Why it is not a working day; absent on one. */
  reason?: DayReason;
  /** Minutes of loose tasks a light day takes. */
  budgetMinutes?: number;
  /** Absent without a cycle, or before its first start. */
  cycle?: CycleDay;
}

/** Answers the mark of any date. */
export type Marks = (day: string) => DayMark;

/** Every date a plain working day: what a day with no rhythm reads. */
export const NO_MARKS: Marks = (day) => ({ day, kind: 'work' });

const STRICTNESS: Record<DayKind, number> = { work: 0, light: 1, off: 2 };

/** Where [day] falls in [cycle], or undefined before its first start. */
export function cycleDayOf(cycle: Cycle, day: string): CycleDay | undefined {
  const place = placeOf(cycle, day);
  if (place === undefined) return undefined;
  const [at, length] = place;
  // Ovulation falls fourteen days before the next period, the part of the
  // cycle that varies least.
  const ovulation = length - 14;
  const phase: CyclePhase =
    at <= cycle.periodLength
      ? 'menstrual'
      : at < ovulation - 1
        ? 'follicular'
        : at <= ovulation + 1
          ? 'ovulatory'
          : 'luteal';

  return { day: at, length, phase };
}

/**
 * The day of its cycle and that cycle's length. Before a corrected
 * [Cycle.nextStart] the cycle runs from the last start to it; from it on,
 * cycles of the set length.
 */
function placeOf(cycle: Cycle, day: string): [number, number] | undefined {
  const next = cycle.nextStart;
  if (next !== undefined && day >= next) {
    return [(daysBetween(next, day) % cycle.length) + 1, cycle.length];
  }
  const days = daysBetween(cycle.lastStart, day);
  if (days < 0) return undefined;
  if (next !== undefined) {
    return [days + 1, daysBetween(cycle.lastStart, next)];
  }

  return [(days % cycle.length) + 1, cycle.length];
}

/** The next period's first day after [today]: corrected, or predicted. */
export function nextPeriodOf(cycle: Cycle, today: string): string {
  if (cycle.nextStart !== undefined && cycle.nextStart > today) {
    return cycle.nextStart;
  }
  const place = placeOf(cycle, today);
  if (place === undefined) return cycle.lastStart;
  const [at, length] = place;

  return addDays(today, length - at + 1);
}

/** The weekday of "2026-10-16", 0 for Sunday. */
function weekdayOf(day: string): number {
  return new Date(`${day}T00:00:00Z`).getUTCDay();
}

/** The mark of [day] under [rhythm]. */
export function markOf(rhythm: Rhythm, day: string): DayMark {
  const cycle =
    rhythm.cycle === undefined ? undefined : cycleDayOf(rhythm.cycle, day);
  const written = rhythm.daysOff.find((it) => it.day === day);

  const sources: [DayKind, DayReason][] = [];
  if (written?.kind === 'off') {
    sources.push(['off', 'day_off']);
  } else {
    // A date put back to work undoes the weekend, never the period.
    if (written === undefined) {
      const weekday = weekdayOf(day);
      if (weekday === 6) sources.push([rhythm.rest.saturday, 'weekend']);
      if (weekday === 0) sources.push([rhythm.rest.sunday, 'weekend']);
    }
    if (cycle?.phase === 'menstrual' && rhythm.cycle !== undefined) {
      sources.push([rhythm.cycle.periodKind, 'period']);
    }
  }
  // The strictest wins; between two as strict, the first said.
  let kind: DayKind = 'work';
  let reason: DayReason | undefined;
  for (const [to, why] of sources) {
    if (STRICTNESS[to] > STRICTNESS[kind]) {
      kind = to;
      reason = why;
    }
  }

  return {
    day,
    kind,
    ...(reason === undefined ? {} : { reason }),
    ...(kind === 'light' ? { budgetMinutes: rhythm.rest.lightMinutes } : {}),
    ...(cycle === undefined ? {} : { cycle }),
  };
}

/** [rhythm]'s marks, worked out once per date. */
export function marksOf(rhythm: Rhythm): Marks {
  const known = new Map<string, DayMark>();
  return (day) => {
    let mark = known.get(day);
    if (mark === undefined) {
      mark = markOf(rhythm, day);
      known.set(day, mark);
    }
    return mark;
  };
}

/**
 * The marks the timeline sends for [days] days from [today]: every date
 * that is not a plain working day, or that has a cycle to tell.
 */
export function marksFor(marks: Marks, today: string, days: number): DayMark[] {
  const out: DayMark[] = [];
  for (let i = 0; i < days; i++) {
    const mark = marks(addDays(today, i));
    if (mark.kind !== 'work' || mark.cycle !== undefined) out.push(mark);
  }
  return out;
}

/** Noon of "2026-10-16" in [zone], safely inside that day. */
function noonOf(day: string, zone: Zone): Date {
  const [year, month, date] = day.split('-').map(Number);
  return instantOf(
    { year, month, day: date, hour: 12, minute: 0, second: 0 },
    zone,
  );
}

/** The working hours of [day] in [zone]. */
export function workWindowOn(
  day: string,
  zone: Zone,
  workDay: WorkDay,
): Interval {
  const noon = noonOf(day, zone);
  return {
    start: atMinuteIn(noon, workDay.start, zone),
    end: atMinuteIn(noon, workDay.end, zone),
  };
}

/**
 * The share of the working time from [from] to [to] that has gone by at
 * [now], 0 to 1.
 *
 * Working time is each working day's hours: a day off counts nothing, and
 * neither does a light day, since a delivery's tasks never go there and a
 * goal is billed from deliveries. So a week of rest does not turn a
 * delivery red. With no working time at all between the two, the share is
 * whole: there is nothing left to do it in.
 */
export function capacityShare(
  from: Date,
  to: Date,
  now: Date,
  marks: Marks,
  zone: Zone,
  workDay: WorkDay,
  firstDay: string,
  lastDay: string,
): number {
  let total = 0;
  let gone = 0;
  const until = Math.min(now.getTime(), to.getTime());
  for (let day = firstDay; day <= lastDay; day = addDays(day, 1)) {
    if (marks(day).kind !== 'work') continue;
    const window = workWindowOn(day, zone, workDay);
    const start = Math.max(window.start.getTime(), from.getTime());
    const end = Math.min(window.end.getTime(), to.getTime());
    if (end <= start) continue;
    total += end - start;
    if (until > start) gone += Math.min(until, end) - start;
  }
  if (total <= 0) return now >= from ? 1 : 0;

  return Math.min(1, Math.max(0, gone / total));
}

/**
 * The share of a goal's working time gone at [now]: from its first day
 * ([starts]) to the end of its last ([deadline]).
 */
export function goalShare(
  starts: string,
  deadline: string,
  now: Date,
  marks: Marks,
  zone: Zone,
  workDay: WorkDay,
): number {
  return capacityShare(
    workWindowOn(starts, zone, { start: 0, end: 0 }).start,
    workWindowOn(addDays(deadline, 1), zone, { start: 0, end: 0 }).start,
    now,
    marks,
    zone,
    workDay,
    starts,
    deadline,
  );
}

/**
 * The share of a delivery's working time gone at [now]: from when it was
 * begun ([startedAt]) to the end of its deadline's day. The red of its bar.
 */
export function deliveryShare(
  startedAt: Date,
  deadline: string,
  now: Date,
  marks: Marks,
  zone: Zone,
  workDay: WorkDay,
  firstDay: string,
): number {
  const due = workWindowOn(addDays(deadline, 1), zone, { start: 0, end: 0 });
  return capacityShare(
    startedAt,
    due.start,
    now,
    marks,
    zone,
    workDay,
    firstDay,
    deadline,
  );
}
