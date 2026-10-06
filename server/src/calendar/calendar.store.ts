import { randomUUID } from 'crypto';
import { occurrencesBetween } from '../routines/routine-dates';
import { Zone } from '../time/zone';
import {
  CalendarEvent,
  CalendarRoutine,
  CalendarUser,
  RoutineDays,
} from './calendar.types';

/** What a new block is written down with. */
export interface NewEvent {
  title: string;
  startTime: string;
  endTime: string;
  fixed: boolean;
  /** False only for something that arrived from an outside calendar. */
  managed?: boolean;
  notBefore?: string;
  /** The task this is the hour of, for one that was just begun. */
  taskId?: string;
  /** Whether it was begun, which a task's hour always was. */
  started?: boolean;
}

/** What a routine is booked or changed with. */
export interface RoutinePatch {
  title?: string;
  /** ISO 8601, the first occurrence. */
  startTime?: string;
  endTime?: string;
  days?: RoutineDays;
}

/**
 * Where the calendar is kept.
 *
 * An abstract class rather than an interface so Nest can inject it by type.
 * Postgres in production ([PgCalendarStore]); memory in the tests that drive
 * the timeline end to end ([MemoryCalendarStore]), which have no database.
 *
 * **Routines are expanded here.** A read of a window first writes down every
 * day of every routine that falls in it and is not already there, so from
 * the moment the timeline can see a day of a routine it is an ordinary row
 * that moves, pauses and finishes like any other block.
 */
export abstract class CalendarStore {
  /** Every live event whose span touches [from, to], earliest first. */
  abstract window(
    user: CalendarUser,
    from: Date,
    to: Date,
    zone: Zone,
  ): Promise<CalendarEvent[]>;

  /** One event by id, wherever it is on the calendar. */
  abstract get(
    user: CalendarUser,
    eventId: string,
  ): Promise<CalendarEvent | undefined>;

  abstract insert(user: CalendarUser, event: NewEvent): Promise<CalendarEvent>;

  /** Writes [event] back whole: every field is the new truth. */
  abstract update(
    user: CalendarUser,
    event: CalendarEvent,
  ): Promise<CalendarEvent>;

  /**
   * Takes [event] off the day.
   *
   * A day of a routine is kept as cancelled instead, so the next read does
   * not write the same occurrence back.
   */
  abstract remove(user: CalendarUser, event: CalendarEvent): Promise<void>;

  abstract routines(user: CalendarUser): Promise<CalendarRoutine[]>;

  abstract insertRoutine(
    user: CalendarUser,
    routine: Required<RoutinePatch> & { title: string },
  ): Promise<CalendarRoutine>;

  /**
   * Changes a routine, and every day of it that has not begun yet.
   *
   * Those days are dropped and written again on the next read, at the new
   * hour and under the new name. The days already gone are history.
   */
  abstract updateRoutine(
    user: CalendarUser,
    routineId: string,
    patch: RoutinePatch,
    now: Date,
  ): Promise<CalendarRoutine | undefined>;

  /** Takes a routine off every day still ahead. Returns whether it existed. */
  abstract removeRoutine(
    user: CalendarUser,
    routineId: string,
    now: Date,
  ): Promise<boolean>;
}

/**
 * The calendar, in memory.
 *
 * Behaves like the Postgres store in everything the timeline can observe,
 * including routine expansion and cancelled days. [seed] puts an event on
 * the calendar directly, the way an outside calendar would.
 */
export class MemoryCalendarStore extends CalendarStore {
  private readonly _events = new Map<string, StoredEvent>();
  private readonly _routines = new Map<string, StoredRoutine>();

  /** Puts [event] on [user]'s calendar as it is, id and all. */
  seed(
    user: CalendarUser,
    event: Omit<CalendarEvent, 'notes'> & { notes?: string },
  ): void {
    this._events.set(event.id, {
      ...event,
      notes: event.notes ?? '',
      userId: user.id,
      cancelled: false,
    });
  }

  /** Every live event of [user], whatever its hour. */
  all(user: CalendarUser): CalendarEvent[] {
    return [...this._events.values()]
      .filter((it) => it.userId === user.id && !it.cancelled)
      .map(toEvent);
  }

  window(
    user: CalendarUser,
    from: Date,
    to: Date,
    zone: Zone,
  ): Promise<CalendarEvent[]> {
    for (const routine of this._routines.values()) {
      if (routine.userId !== user.id) continue;

      for (const day of occurrencesBetween(routine, from, to, zone)) {
        const key = `${routine.id}@${day.start.toISOString()}`;
        const exists = [...this._events.values()].some(
          (it) => it.occurrenceKey === key,
        );
        if (exists) continue;

        const id = randomUUID();
        this._events.set(id, {
          id,
          userId: user.id,
          title: routine.title,
          startTime: day.start.toISOString(),
          endTime: day.end.toISOString(),
          managed: true,
          fixed: true,
          notes: '',
          routineId: routine.id,
          routine: routine.days,
          occurrenceKey: key,
          cancelled: false,
        });
      }
    }

    return Promise.resolve(
      this.all(user)
        .filter(
          (it) =>
            Date.parse(it.startTime) < to.getTime() &&
            Date.parse(it.endTime) > from.getTime(),
        )
        .sort((a, b) => Date.parse(a.startTime) - Date.parse(b.startTime)),
    );
  }

  get(user: CalendarUser, eventId: string): Promise<CalendarEvent | undefined> {
    const stored = this._events.get(eventId);
    if (stored === undefined || stored.userId !== user.id || stored.cancelled) {
      return Promise.resolve(undefined);
    }

    return Promise.resolve(toEvent(stored));
  }

  insert(user: CalendarUser, event: NewEvent): Promise<CalendarEvent> {
    const id = randomUUID();
    const stored: StoredEvent = {
      id,
      userId: user.id,
      title: event.title,
      startTime: event.startTime,
      endTime: event.endTime,
      managed: event.managed ?? true,
      fixed: event.fixed,
      notBefore: event.notBefore,
      notes: '',
      cancelled: false,
      ...(event.taskId === undefined ? {} : { taskId: event.taskId }),
      ...(event.started === true ? { started: true } : {}),
    };
    this._events.set(id, stored);

    return Promise.resolve(toEvent(stored));
  }

  update(user: CalendarUser, event: CalendarEvent): Promise<CalendarEvent> {
    const stored = this._events.get(event.id);
    if (stored === undefined || stored.userId !== user.id) {
      return Promise.reject(new Error(`No event "${event.id}"`));
    }

    const next: StoredEvent = {
      ...event,
      userId: user.id,
      occurrenceKey: stored.occurrenceKey,
      cancelled: stored.cancelled,
    };
    this._events.set(event.id, next);

    return Promise.resolve(toEvent(next));
  }

  remove(user: CalendarUser, event: CalendarEvent): Promise<void> {
    const stored = this._events.get(event.id);
    if (stored === undefined || stored.userId !== user.id) {
      return Promise.resolve();
    }

    if (stored.occurrenceKey !== undefined) {
      stored.cancelled = true;
    } else {
      this._events.delete(event.id);
    }

    return Promise.resolve();
  }

  routines(user: CalendarUser): Promise<CalendarRoutine[]> {
    return Promise.resolve(
      [...this._routines.values()]
        .filter((it) => it.userId === user.id)
        .map(toRoutine),
    );
  }

  insertRoutine(
    user: CalendarUser,
    routine: Required<RoutinePatch> & { title: string },
  ): Promise<CalendarRoutine> {
    const stored: StoredRoutine = {
      ...routine,
      id: randomUUID(),
      userId: user.id,
    };
    this._routines.set(stored.id, stored);

    return Promise.resolve(toRoutine(stored));
  }

  updateRoutine(
    user: CalendarUser,
    routineId: string,
    patch: RoutinePatch,
    now: Date,
  ): Promise<CalendarRoutine | undefined> {
    const stored = this._routines.get(routineId);
    if (stored === undefined || stored.userId !== user.id) {
      return Promise.resolve(undefined);
    }

    const next = { ...stored, ...definedOf(patch) };
    this._routines.set(routineId, next);
    this._dropAhead(routineId, now);

    return Promise.resolve(toRoutine(next));
  }

  removeRoutine(
    user: CalendarUser,
    routineId: string,
    now: Date,
  ): Promise<boolean> {
    const stored = this._routines.get(routineId);
    if (stored === undefined || stored.userId !== user.id) {
      return Promise.resolve(false);
    }

    this._dropAhead(routineId, now);
    this._routines.delete(routineId);
    for (const event of this._events.values()) {
      if (event.routineId === routineId) {
        event.routineId = undefined;
        event.routine = undefined;
      }
    }

    return Promise.resolve(true);
  }

  /** Forgets every day of [routineId] that has not begun by [now]. */
  private _dropAhead(routineId: string, now: Date): void {
    for (const [id, event] of this._events) {
      if (
        event.routineId === routineId &&
        Date.parse(event.startTime) > now.getTime()
      ) {
        this._events.delete(id);
      }
    }
  }
}

interface StoredEvent extends CalendarEvent {
  userId: string;
  /** Which day of which routine, for the ones that are. */
  occurrenceKey?: string;
  cancelled: boolean;
}

interface StoredRoutine extends CalendarRoutine {
  userId: string;
}

function toEvent(stored: StoredEvent): CalendarEvent {
  const event: Partial<StoredEvent> = { ...stored };
  delete event.userId;
  delete event.occurrenceKey;
  delete event.cancelled;

  return event as CalendarEvent;
}

function toRoutine(stored: StoredRoutine): CalendarRoutine {
  const routine: Partial<StoredRoutine> = { ...stored };
  delete routine.userId;

  return routine as CalendarRoutine;
}

/** [patch] without the keys it leaves alone. */
function definedOf(patch: RoutinePatch): RoutinePatch {
  return Object.fromEntries(
    Object.entries(patch).filter(([, value]) => value !== undefined),
  );
}
