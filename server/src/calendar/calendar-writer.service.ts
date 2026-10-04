import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Trace } from '../common/trace';
import {
  CalendarEvent,
  CalendarRoutine,
  CalendarUser,
  readCalendarEvent,
  readCalendarRoutine,
  RoutineDays,
} from './calendar.types';

/** Raised when the calendar could not be changed. */
export class CalendarWriteError extends Error {}

/** What a create or a patch says about an event. */
export interface EventPatch {
  title?: string;
  startTime?: string;
  endTime?: string;
  fixed?: boolean;
  /** Links a conversation to this event. Only ever set, never cleared. */
  threadSlug?: string;
  /** When it was paused. An empty string says it runs again. */
  pausedAt?: string;
  remainingSeconds?: number;
  pausedSeconds?: number;
  started?: boolean;
  /** The earliest a layout may start it. An empty string lifts it. */
  notBefore?: string;
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
 * Changes to the calendar, made through the agent.
 *
 * The rule that the server never holds an integration secret still stands:
 * this asks the agent to do it, over the same private network and with the
 * same lack of ceremony as `/generate`. The routes it calls run no model and
 * have no prompt, so a guard that reserves a block is a plain HTTP call and
 * not a turn, which is what keeps a reorder from costing a generation.
 *
 * Every call names the person, because every person has their own calendar
 * inside the one account.
 */
@Injectable()
export class CalendarWriterService {
  constructor(private readonly _config: ConfigService) {}

  /** Books [event] on this person's calendar and returns it with its id. */
  async create(
    user: CalendarUser,
    event: EventPatch,
    trace: Trace,
  ): Promise<CalendarEvent> {
    return trace.span('calendar.create', { title: event.title }, async () =>
      this._event(
        await this._fetch<unknown>('POST', '/calendar/events', {
          ...event,
          userId: user.id,
          userEmail: user.email,
          userName: user.name,
        }),
      ),
    );
  }

  /** Changes an event already on the calendar. */
  async patch(
    user: CalendarUser,
    eventId: string,
    patch: EventPatch,
    trace: Trace,
  ): Promise<CalendarEvent> {
    return trace.span('calendar.patch', { eventId }, async () =>
      this._event(
        await this._fetch<unknown>(
          'PATCH',
          `/calendar/events/${encodeURIComponent(eventId)}`,
          {
            ...patch,
            userId: user.id,
            userEmail: user.email,
            userName: user.name,
          },
        ),
      ),
    );
  }

  /** Takes one event off the calendar entirely. */
  async remove(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
  ): Promise<void> {
    await trace.span('calendar.remove', { eventId }, async () =>
      this._fetch<unknown>(
        'DELETE',
        `/calendar/events/${encodeURIComponent(eventId)}?userId=${encodeURIComponent(user.id)}`,
      ),
    );
  }

  /** Every routine on this person's calendar, as recurring events. */
  async routines(user: CalendarUser, trace: Trace): Promise<CalendarRoutine[]> {
    return trace.span('calendar.routines', {}, async () => {
      const body = await this._fetch<{ routines?: unknown[] }>(
        'GET',
        `/calendar/routines?${userQuery(user)}`,
      );

      return (body.routines ?? [])
        .map(readCalendarRoutine)
        .filter((routine): routine is CalendarRoutine => routine !== null);
    });
  }

  /** Books a routine, which Google then repeats on its days. */
  async createRoutine(
    user: CalendarUser,
    routine: RoutinePatch,
    trace: Trace,
  ): Promise<CalendarRoutine> {
    return trace.span(
      'calendar.createRoutine',
      { title: routine.title },
      async () =>
        this._routine(
          await this._fetch<unknown>('POST', '/calendar/routines', {
            ...routine,
            userId: user.id,
            userEmail: user.email,
            userName: user.name,
          }),
        ),
    );
  }

  /** Changes a routine, and so every day it repeats on. */
  async patchRoutine(
    user: CalendarUser,
    routineId: string,
    routine: RoutinePatch,
    trace: Trace,
  ): Promise<CalendarRoutine> {
    return trace.span('calendar.patchRoutine', { routineId }, async () =>
      this._routine(
        await this._fetch<unknown>(
          'PATCH',
          `/calendar/routines/${encodeURIComponent(routineId)}`,
          {
            ...routine,
            userId: user.id,
            userEmail: user.email,
            userName: user.name,
          },
        ),
      ),
    );
  }

  private _routine(body: unknown): CalendarRoutine {
    const routine = readCalendarRoutine(body);
    if (routine === null) {
      throw new CalendarWriteError('The calendar returned an unusable routine');
    }

    return routine;
  }

  /** What the agent answered, refused if it is not an event. */
  private _event(body: unknown): CalendarEvent {
    const event = readCalendarEvent(body);
    if (event === null) {
      throw new CalendarWriteError('The calendar returned an unusable event');
    }

    return event;
  }

  private async _fetch<T>(
    method: 'GET' | 'POST' | 'PATCH' | 'DELETE',
    path: string,
    body?: unknown,
  ): Promise<T> {
    const agentUrl =
      this._config.get<string>('AGENT_URL') ?? 'http://localhost:3002';

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15_000);

    try {
      const response = await fetch(`${agentUrl}${path}`, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: controller.signal,
      });

      if (!response.ok) {
        const detail = await response.text().catch(() => '');
        throw new CalendarWriteError(
          `Agent ${path} returned ${response.status}: ${detail.slice(0, 300)}`,
        );
      }

      return (await response.json()) as T;
    } catch (error) {
      if (error instanceof CalendarWriteError) throw error;
      const message = error instanceof Error ? error.message : String(error);
      throw new CalendarWriteError(`Agent ${path} failed: ${message}`);
    } finally {
      clearTimeout(timeoutId);
    }
  }
}

/** The person, as the query string of a route that carries no body. */
function userQuery(user: CalendarUser): string {
  const query = new URLSearchParams({ userId: user.id });
  if (user.email !== undefined) query.set('userEmail', user.email);
  if (user.name !== undefined) query.set('userName', user.name);

  return query.toString();
}
