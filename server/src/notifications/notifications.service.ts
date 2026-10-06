import { createHash } from 'crypto';
import { Injectable } from '@nestjs/common';
import { CalendarEvent, CalendarUser } from '../calendar/calendar.types';
import { intervalOf } from '../events/event-sections';
import { Day, TimelineService } from '../events/timeline.service';
import { addMinutes, minutesOf, WORK_DAY_START_HOUR } from '../time/work-hours';
import {
  addDaysIn,
  atHourIn,
  formatDayIn,
  formatTimeIn,
  isoIn,
  Zone,
} from '../time/zone';
import {
  NotificationItem,
  NotificationKind,
  NotificationPlan,
} from './dto/notification-plan.dto';
import {
  almostFinishingBody,
  CONFIRM_START_BODY,
  EVENING_MESSAGES,
  EVENING_TITLE,
  MORNING_MESSAGES,
  MORNING_TITLE,
  startingBody,
} from './notification-copy';

/** How many days ahead a plan reaches when the app does not say. */
export const DEFAULT_HORIZON_DAYS = 7;

/** The furthest a plan reaches, whatever the app asks for. */
export const MAX_HORIZON_DAYS = 14;

/** How long before a block ends the "almost finishing" reminder fires. */
export const ALMOST_FINISHING_MINUTES = 10;

/**
 * The shortest block that gets an "almost finishing" reminder.
 *
 * Below this, ten minutes before the end is at or right after the start,
 * and the two reminders would arrive on top of each other.
 */
export const ALMOST_FINISHING_MIN_BLOCK_MINUTES = 20;

/**
 * The hour the evening reminder fires.
 *
 * The morning one is the start of the working day and reads it from
 * `work-hours.ts`. This one is not the end of the working day: it is an hour
 * before, early enough to wind down rather than to be told the day is over.
 */
export const EVENING_HOUR = 21;

/**
 * Every reminder the phone should be holding, worked out from the day.
 *
 * Derived, never stored. The server owns the schedule and the phone only
 * mirrors it, so the plan is rebuilt from the day on every ask and there is
 * no table of reminders to fall out of step with the day it describes.
 *
 * Only the blocks Lunna booked get a reminder. A meeting that arrived from
 * an outside calendar already has that calendar to announce it, and two
 * alerts for one event is worse than one.
 *
 * Of the tasks, only the next one gets a reminder. Every other task's hour
 * moves each time the queue is reordered or something runs late, so a
 * reminder for each would be a stream of wrong times.
 */
@Injectable()
export class NotificationsService {
  constructor(private readonly _timeline: TimelineService) {}

  async plan(
    user: CalendarUser,
    horizonDays: number,
    now = new Date(),
  ): Promise<NotificationPlan> {
    const zone = this._timeline.zone(user);
    const until = addDaysIn(now, horizonDays, zone);
    const day = await this._timeline.day(user, horizonDays + 1, now);

    const items = [
      ...day.events.flatMap((event) => blockItems(day, event)),
      ...nextTaskItems(day),
      ...dailyItems(now, horizonDays, zone),
    ]
      .filter((item) => {
        const at = Date.parse(item.fireAt);
        return at > now.getTime() && at <= until.getTime();
      })
      .sort((a, b) => Date.parse(a.fireAt) - Date.parse(b.fireAt));

    return { generatedAt: now.toISOString(), timeZone: zone, items };
  }
}

/**
 * The reminder the next task earns: at its hour, asking rather than
 * announcing, because a task waits for the user to begin it.
 */
function nextTaskItems(day: Day): NotificationItem[] {
  const next = day.tasks.find((task) => !day.live.has(task.id));
  const slot = next === undefined ? undefined : day.placed.get(next.id);
  if (next === undefined || slot === undefined) return [];

  return [
    itemOf({
      kind: 'confirmStart',
      source: next.id,
      at: slot.start,
      zone: day.zone,
      title: next.title,
      body: CONFIRM_START_BODY,
      timeSensitive: true,
      eventId: next.id,
    }),
  ];
}

/** The reminders one block earns, before the past is dropped. */
function blockItems(day: Day, event: CalendarEvent): NotificationItem[] {
  if (!event.managed) return [];

  const interval = intervalOf(event);
  if (interval === undefined) return [];

  // A tap opens the card, and a begun task's card is the task.
  const card = event.taskId ?? event.id;
  const zone = day.zone;
  const items = [
    itemOf({
      kind: 'starting',
      source: event.id,
      at: interval.start,
      zone,
      title: event.title,
      body: startingBody(formatTimeIn(interval.end, zone)),
      timeSensitive: true,
      eventId: card,
    }),
  ];

  // A paused block's end is dragged along with the clock, so any hour
  // written down for it now is wrong by the next minute. It gets its
  // reminder back when it runs again and the next sync sees a real end.
  const paused = event.pausedAt !== undefined;
  if (!paused && minutesOf(interval) >= ALMOST_FINISHING_MIN_BLOCK_MINUTES) {
    items.push(
      itemOf({
        kind: 'almostFinishing',
        source: event.id,
        at: addMinutes(interval.end, -ALMOST_FINISHING_MINUTES),
        zone,
        title: event.title,
        body: almostFinishingBody(ALMOST_FINISHING_MINUTES),
        timeSensitive: false,
        eventId: card,
      }),
    );
  }

  return items;
}

/** The morning and evening reminders for each day from today on. */
function dailyItems(
  now: Date,
  horizonDays: number,
  zone: Zone,
): NotificationItem[] {
  const items: NotificationItem[] = [];

  for (let offset = 0; offset <= horizonDays; offset++) {
    const day = addDaysIn(now, offset, zone);
    const date = formatDayIn(day, zone);

    items.push(
      itemOf({
        kind: 'morning',
        source: date,
        at: atHourIn(day, WORK_DAY_START_HOUR, zone),
        zone,
        title: MORNING_TITLE,
        body: pick(MORNING_MESSAGES, `morning:${date}`),
        timeSensitive: false,
      }),
      itemOf({
        kind: 'evening',
        source: date,
        at: atHourIn(day, EVENING_HOUR, zone),
        zone,
        title: EVENING_TITLE,
        body: pick(EVENING_MESSAGES, `evening:${date}`),
        timeSensitive: false,
      }),
    );
  }

  return items;
}

/**
 * One reminder, with its id.
 *
 * The id is the kind, what it is about, the instant it fires and a short
 * hash of what it says. A block that moves gets a new id, and so does one
 * that is renamed: the phone keeps any reminder whose id it already holds,
 * so an id that survived a rename would keep the old title on the queue.
 */
function itemOf(spec: {
  kind: NotificationKind;
  source: string;
  at: Date;
  zone: Zone;
  title: string;
  body: string;
  timeSensitive: boolean;
  eventId?: string;
}): NotificationItem {
  const epoch = Math.floor(spec.at.getTime() / 1000);
  const text = hashOf(`${spec.title}\n${spec.body}`).slice(0, 8);

  return {
    id: `${spec.kind}:${spec.source}:${epoch}:${text}`,
    kind: spec.kind,
    fireAt: isoIn(spec.at, spec.zone),
    title: spec.title,
    body: spec.body,
    timeSensitive: spec.timeSensitive,
    ...(spec.eventId === undefined ? {} : { eventId: spec.eventId }),
  };
}

/**
 * One of [messages], chosen by [seed].
 *
 * Seeded rather than random so that asking twice on the same day gives the
 * same message. A random pick would change the text, and so the id, on every
 * sync, and the phone would cancel and reschedule the same reminder each
 * time the app opened.
 */
function pick(messages: readonly string[], seed: string): string {
  return messages[parseInt(hashOf(seed).slice(0, 8), 16) % messages.length];
}

function hashOf(text: string): string {
  return createHash('sha1').update(text).digest('hex');
}
