import { Interval } from '../time/work-hours';
import { isoDayIn, Zone } from '../time/zone';
import { CalendarEvent } from '../calendar/calendar.types';
import { TimelineSection } from './entities/event.entity';

/** [event] as an interval, or undefined when its ends do not parse. */
export function intervalOf(
  event: Pick<CalendarEvent, 'startTime' | 'endTime'> | undefined,
): Interval | undefined {
  if (event === undefined) return undefined;

  const start = new Date(event.startTime);
  const end = new Date(event.endTime);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    return undefined;
  }

  return { start, end };
}

/** Whether [interval] is the hour being lived through at [now]. */
export function isRunning(now: Date, interval: Interval): boolean {
  return interval.start <= now && now < interval.end;
}

/** Whether [interval] is over at [now]. */
export function isSpent(now: Date, interval: Interval): boolean {
  return interval.end <= now;
}

/**
 * The section [interval] falls in at [now], or undefined when the timeline
 * does not draw it at all.
 *
 * Nothing else in the app decides this. A heading says what time it is, so it
 * has to be worked out from the clock every time the list is read, and this
 * is the one place that does it.
 *
 * Two answers. What is running is "agora"; everything else is under the day
 * it falls on, which [dayOf] names, as far ahead as the screen was scrolled.
 *
 * An hour that has run out is not a section. A block booked 11:20 to 11:25 is
 * finished at 11:26 — that was the hour, the hour is gone, and leaving it on
 * the screen would make "Agora" mean "now, and also everything now used to
 * be". The event stays on the calendar, because it happened; the timeline simply
 * stops drawing it.
 */
export function sectionOf(
  now: Date,
  interval: Interval,
): TimelineSection | undefined {
  if (isSpent(now, interval)) return undefined;
  if (isRunning(now, interval)) return 'agora';

  return 'dia';
}

/**
 * The day [interval] starts on, "2026-09-21", in [zone].
 *
 * [zone] is the person's, and so the user's day. Asking the server's clock
 * instead is how an evening block ended up under "Amanhã" on a machine
 * running in UTC.
 */
export function dayOf(interval: Interval, zone: Zone): string {
  return isoDayIn(interval.start, zone);
}
