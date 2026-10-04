/**
 * The working day, and the arithmetic every hour in Focus is measured
 * against.
 *
 * One file owns the hours, and `scheduling.ts` is its only real caller. Two
 * copies of "the day ends at ten" would have disagreed the first time one of
 * them changed.
 *
 * **Every hour here is a wall-clock hour in a named zone**, and the zone is
 * always passed in. Seven in the morning means seven where the person is, so
 * nothing in this file may ask a `Date` what hour it is: that answers in the
 * server's zone, and a server in UTC would call half past seven in the
 * evening in São Paulo half past ten and push the block to tomorrow. See
 * `zone.ts` for the arithmetic.
 */
import { addDaysIn, atHourIn, formatTimeIn, Zone } from './zone';

/** The first hour of the working day. Nothing is proposed before it. */
export const WORK_DAY_START_HOUR = 7;

/** The hour the working day ends. Nothing is proposed to start after it. */
export const WORK_DAY_END_HOUR = 22;

/**
 * The breathing room between two blocks.
 *
 * Blocks are proposed and postponed with this gap already in them, so a day
 * built by the guards never has one thing ending exactly as the next begins.
 */
export const BLOCK_GAP_MINUTES = 5;

/** A span of time, start inclusive and end exclusive. */
export interface Interval {
  start: Date;
  end: Date;
}

/** [at] moved by [minutes], which may be negative. */
export function addMinutes(at: Date, minutes: number): Date {
  return new Date(at.getTime() + minutes * 60_000);
}

/** How many minutes [interval] lasts, rounded to the nearest minute. */
export function minutesOf(interval: Interval): number {
  return Math.round(
    (interval.end.getTime() - interval.start.getTime()) / 60_000,
  );
}

/**
 * The working window [at] is in, or the next one if it is outside them.
 *
 * Late evening and the small hours both answer "tomorrow morning", which is
 * what makes a thread created at midnight propose a time someone could
 * actually keep.
 */
export function workWindowFor(at: Date, zone: Zone): Interval {
  const start = atHourIn(at, WORK_DAY_START_HOUR, zone);
  const end = atHourIn(at, WORK_DAY_END_HOUR, zone);

  if (at < start) return { start, end };
  if (at < end) return { start, end };

  const tomorrow = addDaysIn(at, 1, zone);
  return {
    start: atHourIn(tomorrow, WORK_DAY_START_HOUR, zone),
    end: atHourIn(tomorrow, WORK_DAY_END_HOUR, zone),
  };
}

/**
 * The start of the working day after [window].
 *
 * Written out rather than asked of [workWindowFor], because the end of a
 * window and the start of the next one are a day and nine hours apart, and
 * feeding one into the other lands on the morning after the one meant.
 */
export function nextWorkWindowStart(window: Interval, zone: Zone): Date {
  return atHourIn(addDaysIn(window.end, 1, zone), WORK_DAY_START_HOUR, zone);
}

/**
 * The earliest moment something could start, given [now].
 *
 * Always a fresh date, never the one that was passed in: callers trim the
 * seconds off the result, and handing back the caller's own clock would let
 * that trim travel backwards into whatever else is reading it.
 */
export function earliestStart(now: Date, zone: Zone): Date {
  const window = workWindowFor(now, zone);
  return new Date(now < window.start ? window.start : now);
}

/** Whether two intervals share any time at all. */
function overlaps(a: Interval, b: Interval): boolean {
  return a.start < b.end && b.start < a.end;
}

/** Everything in [busy] that [candidate] runs into, earliest first. */
function conflictsWith(candidate: Interval, busy: Interval[]): Interval[] {
  return busy
    .filter((interval) => overlaps(candidate, interval))
    .sort((a, b) => a.start.getTime() - b.start.getTime());
}

/** [at] with its seconds dropped. */
export function floorToMinute(at: Date): Date {
  const result = new Date(at);
  result.setSeconds(0, 0);
  return result;
}

/** The next minute divisible by five, so a proposal never reads "14:07". */
export function roundUpToFiveMinutes(at: Date): Date {
  const result = new Date(at);
  result.setSeconds(0, 0);
  const remainder = result.getMinutes() % 5;
  if (remainder !== 0) result.setMinutes(result.getMinutes() + (5 - remainder));
  return result;
}

/**
 * The first slot of [durationMinutes] that fits, from [from] onwards.
 *
 * Walks forward through [busy] rather than searching: each collision moves the
 * candidate to the end of whatever it hit, plus the gap, and a candidate that
 * runs past the end of the working day starts again at the top of the next
 * one. Days are short and calendars are small, so the simple pass is fast
 * enough and says exactly what it did.
 */
export function nextFreeSlot(
  from: Date,
  durationMinutes: number,
  busy: Interval[],
  zone: Zone,
): Interval {
  // [from] is used as given rather than rounded up, so the first thing on a
  // day can start at this minute. That is what makes "Agora" ever contain
  // anything: a block nudged to the next multiple of five would be a block
  // the clock says has not started.
  const start0 = earliestStart(from, zone);
  start0.setSeconds(0, 0);
  let start = start0;

  // One iteration per block it has to step over, and one more per day it
  // spills out of. The bound is what keeps a pathological calendar from
  // turning this into a hang.
  for (let attempt = 0; attempt < 500; attempt++) {
    const candidate = { start, end: addMinutes(start, durationMinutes) };
    const window = workWindowFor(start, zone);

    if (candidate.end > window.end) {
      start = nextWorkWindowStart(window, zone);
      continue;
    }

    const hit = conflictsWith(candidate, busy)[0];
    if (hit === undefined) return candidate;

    // Exactly the gap after whatever it hit, not the next tidy five. A
    // paused block ends on whatever minute the clock dragged it to, and
    // snapping what follows to the grid would open a gap nobody asked for.
    start = floorToMinute(addMinutes(hit.end, BLOCK_GAP_MINUTES));
  }

  return { start, end: addMinutes(start, durationMinutes) };
}

/** "14:30-15:15", the way a card and a guard both write a span. */
export function formatRange(interval: Interval, zone: Zone): string {
  return `${formatTimeIn(interval.start, zone)}-${formatTimeIn(interval.end, zone)}`;
}
