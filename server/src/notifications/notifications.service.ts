import { createHash } from 'crypto';
import { Injectable } from '@nestjs/common';
import { CalendarEvent, CalendarUser } from '../calendar/calendar.types';
import { intervalOf } from '../events/event-sections';
import { Day, inOrder, TimelineService } from '../events/timeline.service';
import { STEP_MINUTES } from '../events/request';
import { Task } from '../tasks/task.types';
import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  Interval,
  WorkDay,
} from '../time/work-hours';
import {
  addDaysIn,
  atHourIn,
  atMinuteIn,
  formatDayIn,
  formatTimeIn,
  isoIn,
  Zone,
} from '../time/zone';
import {
  NotificationCard,
  NotificationEdge,
  NotificationItem,
  NotificationKind,
  NotificationPlan,
} from './dto/notification-plan.dto';
import {
  CONFIRM_START_BODY,
  ENDED_BODY,
  endedTitle,
  EVENING_MESSAGES,
  EVENING_TITLE,
  headsUpBody,
  headsUpTitle,
  MORNING_MESSAGES,
  MORNING_TITLE,
  startedBody,
  startedTitle,
} from './notification-copy';

/** How many days ahead a plan reaches when the app does not say. */
export const DEFAULT_HORIZON_DAYS = 7;

/** The furthest a plan reaches, whatever the app asks for. */
export const MAX_HORIZON_DAYS = 14;

/**
 * How many times an edge nobody answered is asked about: at the hour, then
 * again [STEP_MINUTES] later, and once more. Then it is quiet: an ignored
 * reminder means busy, not broken.
 */
export const ASKS_PER_EDGE = 3;

/**
 * How far ahead the re-asks are queued. The phone holds 64 reminders at
 * most, and re-asks for next week would crowd out its first asks.
 */
export const REASK_HOURS = 24;

/** How long before a fixed block its heads-up comes. */
export const HEADS_UP_MINUTES = 15;

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
 * no table of reminders to fall out of step with the day it describes. An
 * edge that was answered has no asks left in the next plan, which is how a
 * button's answer cancels the re-asks: the phone syncs after it.
 *
 * Only the blocks Lunna booked get a reminder. A meeting that arrived from
 * an outside calendar already has that calendar to announce it, and two
 * alerts for one event is worse than one.
 *
 * Of the tasks not begun, only the next one is asked about. Every other
 * task's hour moves each time the queue is reordered or something runs
 * late, so a reminder for each would be a stream of wrong times.
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
    const reask = now.getTime() + REASK_HOURS * 3_600_000;
    const day = await this._timeline.day(user, horizonDays + 1, now);

    const planned: Planned[] = [
      ...day.events.flatMap((event) => blockItems(day, event)),
      ...nextTaskItems(day),
      ...dailyItems(now, horizonDays, zone, day.workDay),
    ];
    const items = planned
      .filter((item) => {
        const at = Date.parse(item.fireAt);
        if (item.repeat === true && at > reask) return false;
        return at > now.getTime() && at <= until.getTime();
      })
      .map((item): NotificationItem => {
        const copy = { ...item };
        delete copy.repeat;
        return copy;
      })
      .sort((a, b) => Date.parse(a.fireAt) - Date.parse(b.fireAt));

    return { generatedAt: now.toISOString(), timeZone: zone, items };
  }
}

/** A reminder, and whether it is a re-ask, which only the next day gets. */
type Planned = NotificationItem & { repeat?: boolean };

/**
 * The asks the next task earns: at the hour it came due, asking rather than
 * announcing, because a task waits for the person to begin it.
 */
function nextTaskItems(day: Day): Planned[] {
  // The earliest, not the first in the queue: a lunch anchored at noon comes
  // before the queue's next task when the queue's runs past it.
  const next = inOrder(day).find((task) => !day.live.has(task.id));
  const slot = next === undefined ? undefined : day.placed.get(next.id);
  if (next === undefined || slot === undefined) return [];

  return asks({
    kind: 'askStart',
    edge: 'start',
    card: 'task',
    source: next.id,
    at: dueOf(day, next, slot),
    zone: day.zone,
    title: next.title,
    body: CONFIRM_START_BODY,
    eventId: next.id,
  });
}

/**
 * The hour a task came due.
 *
 * Its slot, while that is ahead. Once it has come, a task waiting to be
 * begun sits at the current minute, so the slot says only "now": it came
 * due at its anchor, or else when what was before it ended and the break
 * was over, or else when the working day opened. Without this the re-asks
 * would slide ahead of the clock on every sync and never fire.
 */
function dueOf(day: Day, task: Task, slot: Interval): Date {
  if (slot.start > day.now) return slot.start;

  let due = atMinuteIn(day.now, day.workDay.start, day.zone);
  if (task.notBefore !== undefined) {
    due = laterOf(due, new Date(task.notBefore));
  }
  for (const event of day.events) {
    const end = addMinutes(new Date(event.endTime), BLOCK_GAP_MINUTES);
    if (end <= day.now) due = laterOf(due, end);
  }

  return due > day.now ? slot.start : due;
}

/** The reminders one block earns, before the past is dropped. */
function blockItems(day: Day, event: CalendarEvent): Planned[] {
  if (!event.managed || event.closedAt !== undefined) return [];

  const interval = intervalOf(event);
  if (interval === undefined) return [];

  // A tap opens the card, and a begun task's card is the task.
  const task = event.taskId !== undefined;
  const card: NotificationCard = task ? 'task' : 'event';
  const eventId = event.taskId ?? event.id;
  const zone = day.zone;
  const items: Planned[] = [];

  if (!task && event.confirmedAt === undefined) {
    items.push(
      ...asks({
        kind: 'askStart',
        edge: 'start',
        card,
        source: event.id,
        at: interval.start,
        zone,
        title: startedTitle(event.title),
        body: startedBody(formatTimeIn(interval.end, zone)),
        eventId,
      }),
    );
    if (runsUpTo(day, event, interval.start)) {
      items.push(
        itemOf({
          kind: 'headsUp',
          edge: 'start',
          card,
          source: event.id,
          at: addMinutes(interval.start, -HEADS_UP_MINUTES),
          zone,
          title: headsUpTitle(event.title, HEADS_UP_MINUTES),
          body: headsUpBody(
            formatTimeIn(interval.start, zone),
            formatTimeIn(interval.end, zone),
          ),
          eventId,
        }),
      );
    }
  }

  // A paused block's end is dragged along with the clock, so any hour
  // written down for it now is wrong by the next minute. It is asked about
  // again when it runs and the next sync sees a real end. One in overtime
  // is asked about from the end it was planned to have.
  if (event.pausedAt === undefined) {
    items.push(
      ...asks({
        kind: 'askEnd',
        edge: 'end',
        card,
        source: event.id,
        at: new Date(event.overtimeFrom ?? interval.end),
        zone,
        title: endedTitle(event.title),
        body: ENDED_BODY,
        eventId,
      }),
    );
  }

  return items;
}

/**
 * Whether something runs right up to [start], so the end ask of whatever
 * is before a fixed block would come too late to move it: a block or a
 * queued task that began before it and ends within the break of it.
 */
function runsUpTo(day: Day, fixed: CalendarEvent, start: Date): boolean {
  const near = addMinutes(start, -BLOCK_GAP_MINUTES).getTime();
  const spans = [
    ...day.events
      .filter((event) => event.id !== fixed.id)
      .flatMap((event) => intervalOf(event) ?? []),
    ...day.placed.values(),
  ];

  return spans.some((span) => span.start < start && span.end.getTime() >= near);
}

/**
 * The asks of one edge: at [spec.at], then again every [STEP_MINUTES], as
 * many as [ASKS_PER_EDGE]. Each repeat is its own reminder, with its own id.
 */
function asks(spec: Parameters<typeof itemOf>[0]): Planned[] {
  return Array.from({ length: ASKS_PER_EDGE }, (_, i) => ({
    ...itemOf({ ...spec, at: addMinutes(spec.at, i * STEP_MINUTES) }),
    ...(i === 0 ? {} : { repeat: true }),
  }));
}

/** The morning and evening reminders for each day from today on. */
function dailyItems(
  now: Date,
  horizonDays: number,
  zone: Zone,
  workDay: WorkDay,
): NotificationItem[] {
  const items: NotificationItem[] = [];

  for (let offset = 0; offset <= horizonDays; offset++) {
    const day = addDaysIn(now, offset, zone);
    const date = formatDayIn(day, zone);

    items.push(
      itemOf({
        kind: 'morning',
        source: date,
        at: atMinuteIn(day, workDay.start, zone),
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
  timeSensitive?: boolean;
  eventId?: string;
  card?: NotificationCard;
  edge?: NotificationEdge;
}): NotificationItem {
  const epoch = Math.floor(spec.at.getTime() / 1000);
  const text = hashOf(`${spec.title}\n${spec.body}`).slice(0, 8);

  return {
    id: `${spec.kind}:${spec.source}:${epoch}:${text}`,
    kind: spec.kind,
    fireAt: isoIn(spec.at, spec.zone),
    title: spec.title,
    body: spec.body,
    // Every ask breaks through a Focus mode; the day's greetings do not.
    timeSensitive: spec.timeSensitive ?? spec.edge !== undefined,
    ...(spec.eventId === undefined ? {} : { eventId: spec.eventId }),
    ...(spec.card === undefined ? {} : { card: spec.card }),
    ...(spec.edge === undefined ? {} : { edge: spec.edge }),
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

/** Whichever of [a] and [b] comes later. */
function laterOf(a: Date, b: Date): Date {
  return a > b ? a : b;
}
