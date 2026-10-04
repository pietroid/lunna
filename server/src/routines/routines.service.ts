import { Injectable, NotFoundException } from '@nestjs/common';
import { CalendarService } from '../calendar/calendar.service';
import {
  CalendarRoutine,
  CalendarUser,
  RoutineDays,
} from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { addMinutes, minutesOf } from '../time/work-hours';
import { formatTimeIn, Zone } from '../time/zone';
import { Routine, RoutineRequest } from './entities/routine.entity';
import { firstOccurrence, parseTime } from './routine-dates';

/**
 * The blocks that happen every day, or every weekday, or every weekend.
 *
 * A routine is one row with a rule; the calendar writes down each day of it
 * as the timeline reaches that day, and from then on that day is a fixed
 * block like any other. Changing a routine changes every day of it that has
 * not begun yet.
 */
@Injectable()
export class RoutinesService {
  constructor(private readonly _calendar: CalendarService) {}

  /** Every routine, earliest hour first. */
  async list(user: CalendarUser): Promise<Routine[]> {
    const zone = this._calendar.zone(user);
    const routines = await this._calendar.routines(user);

    return routines
      .map((routine) => routineOf(routine, zone))
      .sort((a, b) => a.time.localeCompare(b.time));
  }

  /** Writes a routine down, and answers with every routine. */
  async create(
    user: CalendarUser,
    request: Required<RoutineRequest>,
    trace: Trace,
    now = new Date(),
  ): Promise<Routine[]> {
    const zone = this._calendar.zone(user);

    trace.log('routine.create', { days: request.days, time: request.time });
    await this._calendar.createRoutine(user, {
      title: request.title,
      ...spanOf(request.time, request.durationMinutes, request.days, zone, now),
      days: request.days,
    });

    return this.list(user);
  }

  /**
   * Changes a routine, and so every day it repeats on.
   *
   * A new hour, length or set of days starts the series again from today:
   * the first day has to fall on a day the new rule covers, and the days
   * already gone are history rather than something to rewrite.
   */
  async update(
    user: CalendarUser,
    routineId: string,
    request: RoutineRequest,
    trace: Trace,
    now = new Date(),
  ): Promise<Routine[]> {
    const current = (await this.list(user)).find(
      (routine) => routine.id === routineId,
    );
    if (current === undefined) {
      throw new NotFoundException(`No routine "${routineId}"`);
    }

    const next = { ...current, ...request };
    const retimed =
      next.time !== current.time ||
      next.durationMinutes !== current.durationMinutes ||
      next.days !== current.days;
    const zone = this._calendar.zone(user);

    trace.log('routine.update', { routineId, retimed });
    await this._calendar.updateRoutine(
      user,
      routineId,
      {
        title: next.title,
        ...(retimed
          ? {
              ...spanOf(next.time, next.durationMinutes, next.days, zone, now),
              days: next.days,
            }
          : {}),
      },
      now,
    );

    return this.list(user);
  }

  /** Takes a routine off every day still ahead. */
  async remove(
    user: CalendarUser,
    routineId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<Routine[]> {
    trace.log('routine.remove', { routineId });
    const removed = await this._calendar.removeRoutine(user, routineId, now);
    if (!removed) throw new NotFoundException(`No routine "${routineId}"`);

    return this.list(user);
  }
}

/** A stored routine, read as the menu reads it. */
function routineOf(routine: CalendarRoutine, zone: Zone): Routine {
  const start = new Date(routine.startTime);

  return {
    id: routine.id,
    title: routine.title,
    time: formatTimeIn(start, zone),
    durationMinutes: minutesOf({ start, end: new Date(routine.endTime) }),
    days: routine.days,
  };
}

/** The first occurrence of a routine, as the two instants it is stored as. */
function spanOf(
  time: string,
  durationMinutes: number,
  days: RoutineDays,
  zone: Zone,
  now: Date,
): { startTime: string; endTime: string } {
  // Already validated by the controller; the fallback only keeps the types
  // honest.
  const start = firstOccurrence(
    now,
    parseTime(time) ?? { hour: 7, minute: 0 },
    days,
    zone,
  );

  return {
    startTime: start.toISOString(),
    endTime: addMinutes(start, durationMinutes).toISOString(),
  };
}
