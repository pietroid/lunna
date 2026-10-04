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
