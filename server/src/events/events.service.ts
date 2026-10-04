import { Injectable, NotFoundException } from '@nestjs/common';
import { CalendarService } from '../calendar/calendar.service';
import { CalendarEvent, CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { PlannedBlock } from '../time/scheduling';
import { Interval, minutesOf } from '../time/work-hours';
import { Zone } from '../time/zone';
import { EventCard } from './entities/event.entity';
import { awaitsStart, intervalOf, sectionOf } from './event-sections';

/** One block of occupied time, as the layout sees it. */
export interface TimeBlock extends PlannedBlock {
  title: string;
  /** Whether Lunna booked it, and so may move it. */
  managed: boolean;
}

/**
 * The day, read and written.
 *
 * One source: the calendar. A card on the timeline is an event, its hour is
 * the event's hour, and there is no second copy of any of that to fall out
 * of step. Every write lands in Postgres before the request answers, so the
 * card under the finger and the row behind it never disagree.
 */
@Injectable()
export class EventsService {
  constructor(private readonly _calendar: CalendarService) {}

  /**
   * Every card the timeline draws, earliest first.
   *
   * An hour that has run out is simply not in the list. The event stays on
   * the calendar, because it happened, and nothing has to be swept, closed or
   * rewritten as the day goes by: the clock decides what is drawn, on every
   * read.
   */
  async cards(user: CalendarUser, now = new Date()): Promise<EventCard[]> {
    const cards: EventCard[] = [];
    const zone = await this.zone(user);

    for (const event of await this._calendar.events(user, now)) {
      const interval = intervalOf(event);
      if (interval === undefined) continue;

      const section = sectionOf(now, interval, zone);
      if (section === undefined) continue;

      cards.push({
        id: event.id,
        title: event.title,
        section,
        startTime: interval.start.toISOString(),
        endTime: interval.end.toISOString(),
        durationMinutes: minutesOf(interval),
        fixed: event.fixed,
        managed: event.managed,
        notes: event.notes,
        pausedAt: event.pausedAt,
        remainingSeconds: event.remainingSeconds,
        pausedSeconds: event.pausedSeconds ?? 0,
        workMinutes: Math.round(workSecondsOf(event) / 60),
        awaitingStart: awaitsStart(event, now),
        notBefore: event.notBefore,
        routine: event.routine,
      });
    }

    return cards.sort(
      (a, b) => Date.parse(a.startTime) - Date.parse(b.startTime),
    );
  }

  /**
   * Every block of time that is spoken for, [excludeId] aside.
   *
   * The block being moved is left out, because otherwise it collides with
   * itself the moment anyone tries to move it half an hour.
   */
  async blocks(
    user: CalendarUser,
    options: { excludeId?: string } = {},
  ): Promise<TimeBlock[]> {
    const blocks: TimeBlock[] = [];

    for (const event of await this._calendar.events(user)) {
      if (event.id === options.excludeId) continue;

      const interval = intervalOf(event);
      if (interval === undefined) continue;

      blocks.push({
        id: event.id,
        title: event.title,
        minutes: minutesOf(interval),
        fixed: event.fixed,
        managed: event.managed,
        interval,
      });
    }

    return blocks.sort(
      (a, b) => a.interval.start.getTime() - b.interval.start.getTime(),
    );
  }

  /**
   * The zone every hour on this person's day is measured in.
   *
   * Everything that decides an hour — the working window, which day a block
   * falls on, the range printed in a guard — takes it from here, so there is
   * one answer to "what time is it for this person".
   */
  zone(user: CalendarUser): Promise<Zone> {
    return Promise.resolve(this._calendar.zone(user));
  }

  /** One event, or a 404 when the calendar has nothing by that id. */
  async require(user: CalendarUser, eventId: string): Promise<CalendarEvent> {
    const event = await this._calendar.find(user, eventId);
    if (event === undefined) {
      throw new NotFoundException(`No event "${eventId}"`);
    }

    return event;
  }

  /** Books a block. */
  async book(
    user: CalendarUser,
    event: {
      title: string;
      slot: Interval;
      fixed: boolean;
      notBefore?: Date;
    },
    trace: Trace,
  ): Promise<CalendarEvent> {
    const created = await this._calendar.create(user, {
      title: event.title,
      startTime: event.slot.start.toISOString(),
      endTime: event.slot.end.toISOString(),
      fixed: event.fixed,
      notBefore: event.notBefore?.toISOString(),
    });
    trace.log('event.booked', { eventId: created.id });

    return created;
  }

  /**
   * Changes anything about one block.
   *
   * A key named in [changes] with an undefined value clears it, which is how
   * a pause or a floor is lifted.
   */
  async revise(
    user: CalendarUser,
    event: CalendarEvent,
    changes: Partial<Omit<CalendarEvent, 'id' | 'managed'>>,
    trace: Trace,
  ): Promise<CalendarEvent> {
    trace.log('event.revise', {
      eventId: event.id,
      keys: Object.keys(changes),
    });

    return this._calendar.save(user, { ...event, ...changes });
  }

  /** Every event on the calendar that is paused, whatever its hour now says. */
  async paused(user: CalendarUser): Promise<CalendarEvent[]> {
    return (await this._calendar.events(user)).filter(
      (event) => event.managed && event.pausedAt !== undefined,
    );
  }

  /** Every block whose hour came and that is still waiting to be begun. */
  async waiting(
    user: CalendarUser,
    now = new Date(),
  ): Promise<CalendarEvent[]> {
    return (await this._calendar.events(user, now)).filter((event) =>
      awaitsStart(event, now),
    );
  }

  /** Takes a block off the day. */
  async erase(
    user: CalendarUser,
    event: CalendarEvent,
    trace: Trace,
  ): Promise<void> {
    trace.log('event.erase', { eventId: event.id });
    await this._calendar.remove(user, event);
  }
}

/**
 * How long the work in [event] takes, every pause left out.
 *
 * While paused the end is being dragged along with the clock, so the span on
 * the calendar says nothing useful: what is known is what was done before the
 * pause and what was still owed at it.
 */
export function workSecondsOf(event: CalendarEvent): number {
  const start = Date.parse(event.startTime);
  const before = event.pausedSeconds ?? 0;

  if (event.pausedAt !== undefined) {
    const done = (Date.parse(event.pausedAt) - start) / 1000 - before;
    return Math.max(0, done) + (event.remainingSeconds ?? 0);
  }

  return Math.max(0, (Date.parse(event.endTime) - start) / 1000 - before);
}
