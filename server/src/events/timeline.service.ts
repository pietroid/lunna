import { Injectable } from '@nestjs/common';
import { CalendarService } from '../calendar/calendar.service';
import { CalendarEvent, CalendarUser } from '../calendar/calendar.types';
import { relayout } from '../time/scheduling';
import { TaskStore } from '../tasks/task.store';
import { Task } from '../tasks/task.types';
import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  floorToMinute,
  Interval,
  minutesOf,
} from '../time/work-hours';
import { addDaysIn, startOfDayIn, Zone } from '../time/zone';
import { BacklogCard, Timeline, TimelineCard } from './entities/event.entity';
import { dayOf, intervalOf, sectionOf } from './event-sections';

/** How many days the calendar draws when the screen does not say. */
export const DEFAULT_DAYS = 2;

/** The most days one read draws, however far the screen was scrolled. */
export const MAX_DAYS = 120;

/**
 * How many times a read reaches further for the anchors the queue runs into.
 *
 * Each pass lays the queue out, and if it ran past the days that were read
 * the next pass reads up to where it ended. Anchors only ever push work
 * later, so this settles in two passes nearly always.
 */
const MAX_PASSES = 5;

/**
 * Everything about the day, read once.
 *
 * What a request works from: the events, the tasks, and where the queue
 * falls among them. Built by [TimelineService.day] and read by everything
 * that changes the day, so one request is one read of each store.
 */
export interface Day {
  now: Date;
  zone: Zone;
  /** The first instant the calendar no longer draws. */
  until: Date;
  /** Every event from a little before now to past the end of the queue. */
  events: CalendarEvent[];
  /** Every task still to do, in queue order, the ones begun included. */
  tasks: Task[];
  /**
   * Every task waiting in the backlog, in its order. None of them has an
   * hour, and the layout never saw them.
   */
  backlog: Task[];
  /** The hour of each task that was begun and is not over, by task id. */
  live: Map<string, CalendarEvent>;
  /** Where the queue puts each task that has not been begun, by task id. */
  placed: Map<string, Interval>;
}

/**
 * The day, read.
 *
 * Two sources: the calendar, which has every event, and the tasks, which
 * have the queue. A task's hour is not kept anywhere. It is worked out here
 * on every read by laying the queue out around the events, so the list and
 * the calendar are two drawings of one answer and cannot disagree.
 */
@Injectable()
export class TimelineService {
  constructor(
    private readonly _calendar: CalendarService,
    private readonly _tasks: TaskStore,
  ) {}

  /** The zone every hour on this person's day is measured in. */
  zone(user: CalendarUser): Zone {
    return this._calendar.zone(user);
  }

  /**
   * The day as it stands, drawn [days] days ahead counting today.
   *
   * The queue is laid out in full whatever [days] says, because the list
   * shows every task and each one's hour depends on all the ones before it.
   */
  async day(
    user: CalendarUser,
    days = DEFAULT_DAYS,
    now = new Date(),
  ): Promise<Day> {
    const zone = this.zone(user);
    const until = startOfDayIn(addDaysIn(now, days, zone), zone);
    const stored = await this._tasks.pending(user);
    const tasks = stored.filter((task) => !task.backlog);
    const backlog = stored.filter((task) => task.backlog);
    const pending = new Set(tasks.map((task) => task.id));

    let reach = until;
    let events: CalendarEvent[] = [];
    let live = new Map<string, CalendarEvent>();
    let placed = new Map<string, Interval>();

    for (let pass = 0; pass < MAX_PASSES; pass++) {
      events = await this._calendar.events(user, reach, now);

      // A task whose hour ran out is over, and the minute tick writes it
      // down as done. Until it does, it is neither running nor queued.
      const over = new Set<string>();
      live = new Map();
      for (const event of events) {
        if (event.taskId === undefined || !pending.has(event.taskId)) continue;
        if (Date.parse(event.endTime) > now.getTime()) {
          live.set(event.taskId, event);
        } else {
          over.add(event.taskId);
        }
      }

      const queue = tasks.filter(
        (task) => !live.has(task.id) && !over.has(task.id),
      );
      placed = relayout(
        queue.map((task) => ({
          id: task.id,
          minutes: task.minutes,
          notBefore:
            task.notBefore === undefined ? undefined : new Date(task.notBefore),
        })),
        events.flatMap((event) => intervalOf(event) ?? []),
        cursorOf(events, now),
        zone,
      );

      const last = Math.max(
        0,
        ...[...placed.values()].map((slot) => slot.end.getTime()),
      );
      const furthest = addDaysIn(now, MAX_DAYS, zone);
      if (last <= reach.getTime() || reach >= furthest) break;

      reach = startOfDayIn(addDaysIn(new Date(last), 1, zone), zone);
    }

    return {
      now,
      zone,
      until,
      events,
      tasks: tasks.filter((task) => live.has(task.id) || placed.has(task.id)),
      backlog,
      live,
      placed,
    };
  }

  /** The day as the screen draws it: the list, and the calendar. */
  view(day: Day): Timeline {
    const tasks = [
      ...day.tasks
        .filter((task) => day.live.has(task.id))
        .sort(
          (a, b) =>
            Date.parse(day.live.get(a.id)!.startTime) -
            Date.parse(day.live.get(b.id)!.startTime),
        ),
      ...day.tasks.filter((task) => !day.live.has(task.id)),
    ].flatMap((task) => taskCard(day, task) ?? []);

    const events = day.events.flatMap((event) => {
      // A begun task is drawn as its task, and a finished one's hour is
      // history the timeline no longer draws.
      if (event.taskId !== undefined) return [];
      return eventCard(day, event) ?? [];
    });

    const cards = [...tasks, ...events]
      .filter((card) => Date.parse(card.startTime) < day.until.getTime())
      .sort(
        (a, b) =>
          Date.parse(a.startTime) - Date.parse(b.startTime) ||
          // Two things starting together: the one with its own hour first.
          (a.kind === b.kind ? 0 : a.kind === 'event' ? -1 : 1),
      );

    return { tasks, backlog: day.backlog.map(backlogCard), cards };
  }
}

/** Where a task's hour is: the one it is taking, or the one it is given. */
export function intervalOfTask(day: Day, taskId: string): Interval | undefined {
  const live = day.live.get(taskId);
  return live === undefined ? day.placed.get(taskId) : intervalOf(live);
}

/**
 * Where the queue starts: this minute, or five minutes after something that
 * has just ended, which is the break between one thing and the next.
 */
function cursorOf(events: CalendarEvent[], now: Date): Date {
  let cursor = floorToMinute(now);
  const recent = now.getTime() - BLOCK_GAP_MINUTES * 60_000;

  for (const event of events) {
    const end = Date.parse(event.endTime);
    if (end > now.getTime() || end <= recent) continue;

    const rested = floorToMinute(addMinutes(new Date(end), BLOCK_GAP_MINUTES));
    if (rested > cursor) cursor = rested;
  }

  return cursor;
}

function taskCard(day: Day, task: Task): TimelineCard | undefined {
  const live = day.live.get(task.id);
  const interval = intervalOfTask(day, task.id);
  if (interval === undefined) return undefined;

  const awaiting = live === undefined && interval.start <= day.now;

  return {
    id: task.id,
    kind: 'task',
    title: task.title,
    // A task that has not been begun is never over: it is laid out from now.
    section: sectionOf(day.now, interval) ?? 'dia',
    day: dayOf(interval, day.zone),
    startTime: interval.start.toISOString(),
    endTime: interval.end.toISOString(),
    durationMinutes: minutesOf(interval),
    fixed: false,
    managed: true,
    notes: task.notes,
    pausedAt: live?.pausedAt,
    remainingSeconds: live?.remainingSeconds,
    pausedSeconds: live?.pausedSeconds ?? 0,
    workMinutes:
      live === undefined ? task.minutes : Math.round(workSecondsOf(live) / 60),
    started: live !== undefined,
    awaitingStart: awaiting,
    notBefore: task.notBefore,
  };
}

function backlogCard(task: Task): BacklogCard {
  return {
    id: task.id,
    kind: 'task',
    title: task.title,
    section: 'backlog',
    durationMinutes: task.minutes,
    workMinutes: task.minutes,
    notes: task.notes,
  };
}

function eventCard(day: Day, event: CalendarEvent): TimelineCard | undefined {
  const interval = intervalOf(event);
  if (interval === undefined) return undefined;

  const section = sectionOf(day.now, interval);
  if (section === undefined) return undefined;

  return {
    id: event.id,
    kind: 'event',
    title: event.title,
    section,
    day: dayOf(interval, day.zone),
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
    started: false,
    awaitingStart: false,
    routine: event.routine,
  };
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
