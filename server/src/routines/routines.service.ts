import {
  BadGatewayException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CalendarReaderService } from '../calendar/calendar-reader.service';
import {
  CalendarWriteError,
  CalendarWriterService,
} from '../calendar/calendar-writer.service';
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
 * **The repeating is Google's.** A routine is one recurring event, and Focus
 * keeps no list of them: the menu reads the recurring events back, and the
 * timeline draws their instances like any other fixed block. Changing a
 * routine changes the event, and Google carries the change to every day.
 */
@Injectable()
export class RoutinesService {
  constructor(
    private readonly _reader: CalendarReaderService,
    private readonly _writer: CalendarWriterService,
  ) {}

  /** Every routine, earliest hour first. */
  async list(user: CalendarUser, trace: Trace): Promise<Routine[]> {
    const zone = await this._reader.zone(user);
    const routines = await this._call(() => this._writer.routines(user, trace));

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
    const zone = await this._reader.zone(user, now);

    trace.log('routine.create', { days: request.days, time: request.time });
    await this._call(() =>
      this._writer.createRoutine(
        user,
        {
          title: request.title,
          ...spanOf(
            request.time,
            request.durationMinutes,
            request.days,
            zone,
            now,
          ),
          days: request.days,
        },
        trace,
      ),
    );
    await this._reader.invalidate(user);

    return this.list(user, trace);
  }

  /**
   * Changes a routine, and so every day it repeats on.
   *
   * A new hour, length or set of days starts the series again from today:
   * the first instance has to fall on a day the new rule covers, and the days
   * already gone are history rather than something to rewrite.
   */
  async update(
    user: CalendarUser,
    routineId: string,
    request: RoutineRequest,
    trace: Trace,
    now = new Date(),
  ): Promise<Routine[]> {
    const current = (await this.list(user, trace)).find(
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
    const zone = await this._reader.zone(user, now);

    trace.log('routine.update', { routineId, retimed });
    await this._call(() =>
      this._writer.patchRoutine(
        user,
        routineId,
        {
          title: next.title,
          ...(retimed
            ? {
                ...spanOf(
                  next.time,
                  next.durationMinutes,
                  next.days,
                  zone,
                  now,
                ),
                days: next.days,
              }
            : {}),
        },
        trace,
      ),
    );
    await this._reader.invalidate(user);

    return this.list(user, trace);
  }

  /** Takes a routine off every day it was on. */
  async remove(
    user: CalendarUser,
    routineId: string,
    trace: Trace,
  ): Promise<Routine[]> {
    trace.log('routine.remove', { routineId });
    await this._call(() => this._writer.remove(user, routineId, trace));
    await this._reader.invalidate(user);

    return this.list(user, trace);
  }

  /** Runs a calendar call, turning a refusal into what the app shows. */
  private async _call<T>(call: () => Promise<T>): Promise<T> {
    try {
      return await call();
    } catch (error) {
      if (!(error instanceof CalendarWriteError)) throw error;
      throw new BadGatewayException('Não consegui falar com a sua agenda.');
    }
  }
}

/** A recurring event, read as the menu reads a routine. */
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

/** The first occurrence of a routine, as the two instants Google books. */
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
