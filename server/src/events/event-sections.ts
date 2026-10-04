import { Interval } from '../time/work-hours';
import { addDaysIn, sameDayIn, Zone } from '../time/zone';
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

/**
 * Whether [event] has reached its hour and is waiting for the user to begin.
 *
 * Only a flexible block Focus booked waits. A fixed block's hour is the
 * point of it and a meeting is somebody else's, so both simply start. A
 * paused block has plainly been begun.
 */
export function awaitsStart(event: CalendarEvent, now: Date): boolean {
  if (!event.managed || event.fixed || event.routine !== undefined) {
    return false;
  }
  if (event.started === true || event.pausedAt !== undefined) return false;

  const interval = intervalOf(event);
  return interval !== undefined && interval.start <= now;
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
 * An hour that has run out is not a section. A block booked 11:20 to 11:25 is
 * finished at 11:26 — that was the hour, the hour is gone, and leaving it on
 * the screen would make "Agora" mean "now, and also everything now used to
 * be". The event stays on Google, because it happened; the timeline simply
 * stops drawing it.
 *
 * "Hoje" is today in [zone], which is the calendar's zone and so the user's
 * day. Asking the server's clock instead is how an evening block ended up
 * under "Amanhã" on a machine running in UTC.
 */
export function sectionOf(
  now: Date,
  interval: Interval,
  zone: Zone,
): TimelineSection | undefined {
  if (isSpent(now, interval)) return undefined;
  if (isRunning(now, interval)) return 'agora';
  if (sameDayIn(interval.start, now, zone)) return 'hoje';
  if (sameDayIn(interval.start, addDaysIn(now, 1, zone), zone)) return 'amanha';

  return undefined;
}
