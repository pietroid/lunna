import { ConfigService } from '@nestjs/config';
import { CalendarService } from '../calendar/calendar.service';
import { MemoryCalendarStore } from '../calendar/calendar.store';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { intervalOf } from '../events/event-sections';
import { EventLayoutService } from '../events/event-layout.service';
import {
  Day,
  inList,
  intervalOfTask,
  isAnchored,
  TimelineService,
} from '../events/timeline.service';
import { MemoryTaskStore, TaskStore } from '../tasks/task.store';
import { addMinutes, BLOCK_GAP_MINUTES } from '../time/work-hours';
import { Gesture, Undo } from './plan';

/**
 * What a gesture is made with: the person's own day, or a sandbox copy of
 * it. The same code runs on both, so a plan that held in the dry run is the
 * plan Aplicar makes.
 */
export interface Hands {
  timeline: TimelineService;
  layout: EventLayoutService;
  calendar: CalendarService;
  tasks: TaskStore;
}

/**
 * A throwaway copy of [day]: the same layout, over memory stores seeded with
 * the rows it was read from. Nothing made here reaches the database or the
 * calendar's cache.
 *
 * Routines are left out: their days within reach are already rows, and the
 * copy never reads further than the real day did.
 */
export function sandbox(user: CalendarUser, day: Day): Hands {
  const events = new MemoryCalendarStore();
  for (const event of day.events) events.seed(user, event);
  const tasks = new MemoryTaskStore();
  for (const task of [...day.tasks, ...day.backlog]) tasks.seed(user, task);

  const calendar = new CalendarService(
    events,
    new ConfigService({ LUNNA_TIMEZONE: day.zone }),
  );
  const timeline = new TimelineService(calendar, tasks);

  return {
    timeline,
    layout: new EventLayoutService(timeline, calendar, tasks),
    calendar,
    tasks,
  };
}

/**
 * Makes [gesture] with [hands], noting in [undo] how to take it back.
 * Answers the id of the card it made or moved.
 */
export async function make(
  hands: Hands,
  user: CalendarUser,
  gesture: Gesture,
  undo: Undo[],
  trace: Trace,
  now: Date,
): Promise<string> {
  const { layout, tasks, calendar } = hands;

  switch (gesture.do) {
    case 'place': {
      const day = await hands.timeline.day(user, 1, now);
      const where = placeOf(day, gesture.id, gesture.after, gesture.before);

      if (gesture.new !== undefined) {
        const id = await layout.createTask(
          user,
          {
            title: gesture.new.title,
            minutes: gesture.new.minutes,
            backlog: false,
            ...('at' in where
              ? { notBefore: where.at.toISOString() }
              : { index: where.index }),
          },
          trace,
          now,
        );
        undo.push({ kind: 'remove_task', id });
        return id;
      }

      const id = gesture.id!;
      await keep(hands, user, id, undo);
      await layout.moveTask(
        user,
        'at' in where
          ? {
              taskId: id,
              index: indexAt(day, where.at, id),
              after: where.at.toISOString(),
            }
          : { taskId: id, index: where.index },
        trace,
        now,
      );
      return id;
    }

    case 'at_hour': {
      if (gesture.new?.fixed === true) {
        const id = await layout.createEvent(
          user,
          {
            title: gesture.new.title,
            durationMinutes: gesture.new.minutes,
            startTime: gesture.at,
          },
          trace,
        );
        undo.push({ kind: 'remove_event', id });
        return id;
      }

      if (gesture.new !== undefined) {
        const id = await layout.createTask(
          user,
          {
            title: gesture.new.title,
            minutes: gesture.new.minutes,
            backlog: false,
            notBefore: gesture.at,
          },
          trace,
          now,
        );
        undo.push({ kind: 'remove_task', id });
        return id;
      }

      const id = gesture.id!;
      if ((await tasks.get(user, id)) === undefined) {
        const event = await calendar.find(user, id);
        if (event === undefined) throw new Error(`No card "${id}"`);
        await layout.editEvent(user, id, { startTime: gesture.at }, trace, now);
        undo.push({ kind: 'restore_event', event });
        return id;
      }

      const day = await hands.timeline.day(user, 1, now);
      await keep(hands, user, id, undo);
      await layout.moveTask(
        user,
        {
          taskId: id,
          index: indexAt(day, new Date(gesture.at), id),
          after: gesture.at,
        },
        trace,
        now,
      );
      return id;
    }

    case 'to_backlog': {
      if (gesture.new !== undefined) {
        const id = await layout.createTask(
          user,
          {
            title: gesture.new.title,
            minutes: gesture.new.minutes,
            backlog: true,
          },
          trace,
          now,
        );
        undo.push({ kind: 'remove_task', id });
        return id;
      }

      const id = gesture.id!;
      const day = await hands.timeline.day(user, 1, now);
      await keep(hands, user, id, undo);
      await layout.moveTask(
        user,
        { taskId: id, backlog: true, index: day.backlog.length },
        trace,
        now,
      );
      return id;
    }

    case 'swap': {
      await keep(hands, user, gesture.id, undo);
      await keep(hands, user, gesture.with, undo);
      await layout.swapTasks(user, gesture.id, gesture.with, trace, now);
      return gesture.id;
    }
  }
}

/** Undoes [undo] with [hands], last change first. */
export async function takeBack(
  hands: Hands,
  user: CalendarUser,
  undo: Undo[],
  trace: Trace,
): Promise<void> {
  for (const step of [...undo].reverse()) {
    switch (step.kind) {
      case 'remove_task':
        await hands.layout.removeTask(user, step.id, trace);
        break;
      case 'remove_event':
        await hands.layout.removeEvent(user, step.id, trace);
        break;
      case 'restore_task':
        await hands.tasks.update(user, step.task);
        break;
      case 'restore_event':
        await hands.calendar.save(user, step.event);
        break;
    }
  }
}

/** Notes task [id] as it is, so undoing puts it back exactly. */
async function keep(
  hands: Hands,
  user: CalendarUser,
  id: string,
  undo: Undo[],
): Promise<void> {
  const task = await hands.tasks.get(user, id);
  if (task === undefined) throw new Error(`No task "${id}"`);
  undo.push({ kind: 'restore_task', task });
}

/**
 * Where a drop between [after] and [before] lands, as the app works it
 * out: a place in the list of tasks, counting the tasks above it; right
 * under a card that keeps an hour (an event, or an anchored task), that
 * card's end plus the pause, since a place in the queue says nothing about
 * where such a card is. Neither named is the end of the queue.
 */
export function placeOf(
  day: Day,
  self: string | undefined,
  after: string | undefined,
  before: string | undefined,
): { index: number } | { at: Date } {
  const list = inList(day).filter((task) => task.id !== self);
  const indexOf = (id: string) => list.findIndex((task) => task.id === id);
  const queued = (id: string) => {
    const task = list.find((it) => it.id === id);
    return task !== undefined && !isAnchored(day, task);
  };

  if (after !== undefined && queued(after))
    return { index: indexOf(after) + 1 };
  if (before !== undefined && indexOf(before) >= 0) {
    return { index: indexOf(before) };
  }

  const above = after === undefined ? undefined : hourOf(day, after);
  if (above !== undefined) {
    return { at: addMinutes(above.end, BLOCK_GAP_MINUTES) };
  }

  const below = before === undefined ? undefined : hourOf(day, before);
  if (below !== undefined) {
    return { index: indexAt(day, below.start, self) };
  }

  return { index: list.length };
}

/** How many tasks of the list start before [at]: a drop's place there. */
function indexAt(day: Day, at: Date, self: string | undefined): number {
  return inList(day).filter(
    (task) =>
      task.id !== self &&
      (intervalOfTask(day, task.id)?.start.getTime() ?? Infinity) <
        at.getTime(),
  ).length;
}

/** The hour card [id] takes on [day], a task or an event. */
function hourOf(day: Day, id: string) {
  const task = intervalOfTask(day, id);
  if (task !== undefined) return task;

  const event = day.events.find((it) => it.id === id);
  return event === undefined ? undefined : intervalOf(event);
}
