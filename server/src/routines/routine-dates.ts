import { RoutineDays } from '../calendar/calendar.types';
import { addDaysIn, instantOf, wallOf, Zone } from '../time/zone';

/** Whether a routine on [days] happens on [weekday], where Sunday is 0. */
export function fallsOn(days: RoutineDays, weekday: number): boolean {
  const weekend = weekday === 0 || weekday === 6;

  switch (days) {
    case 'weekdays':
      return !weekend;
    case 'weekend':
      return weekend;
    default:
      return true;
  }
}

/** [time] as hours and minutes, or undefined when it is not "HH:MM". */
export function parseTime(
  time: string,
): { hour: number; minute: number } | undefined {
  const match = /^(\d{1,2}):(\d{2})$/.exec(time.trim());
  if (match === null) return undefined;

  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return undefined;

  return { hour, minute };
}

/**
 * The first occurrence of a routine at [time] on [days], from today on.
 *
 * Today counts even when the hour has gone by, so a routine written down at
 * three in the afternoon for noon still starts today; the instance that
 * already happened is simply one the timeline no longer draws. It has to land
 * on a day the rule covers, because the first instance of a recurring event
 * is its start whether or not the rule would have produced it.
 */
export function firstOccurrence(
  now: Date,
  time: { hour: number; minute: number },
  days: RoutineDays,
  zone: Zone,
): Date {
  for (let offset = 0; offset < 7; offset++) {
    const day = wallOf(addDaysIn(now, offset, zone), zone);
    const weekday = new Date(
      Date.UTC(day.year, day.month - 1, day.day),
    ).getUTCDay();

    if (fallsOn(days, weekday)) {
      return instantOf(
        { ...day, hour: time.hour, minute: time.minute, second: 0 },
        zone,
      );
    }
  }

  // Every rule covers some day of any week, so this is never reached.
  return now;
}

/** One day of a routine: the instant the rule puts it at, and its span. */
export interface Occurrence {
  start: Date;
  end: Date;
}

/**
 * Every day of [routine] whose span touches [from, to].
 *
 * The routine's first occurrence fixes two things: the wall-clock hour every
 * day starts at, in [zone], and the first day there is one. Each later day the
 * rule covers gets the same hour on its own date, so a routine at noon is at
 * noon whatever the offset that day.
 */
export function occurrencesBetween(
  routine: { startTime: string; endTime: string; days: RoutineDays },
  from: Date,
  to: Date,
  zone: Zone,
): Occurrence[] {
  const first = new Date(routine.startTime);
  const durationMs = Date.parse(routine.endTime) - first.getTime();
  const hour = wallOf(first, zone);
  const occurrences: Occurrence[] = [];

  // From the day before [from], so a day that started yesterday and is
  // still running is not missed.
  const startDay = addDaysIn(from > first ? from : first, -1, zone);
  for (let offset = 0; offset < 400; offset++) {
    const day = wallOf(addDaysIn(startDay, offset, zone), zone);
    const start = instantOf(
      { ...day, hour: hour.hour, minute: hour.minute, second: 0 },
      zone,
    );
    if (start >= to) break;

    const weekday = new Date(
      Date.UTC(day.year, day.month - 1, day.day),
    ).getUTCDay();
    const end = new Date(start.getTime() + durationMs);

    if (start >= first && end > from && fallsOn(routine.days, weekday)) {
      occurrences.push({ start, end });
    }
  }

  return occurrences;
}
