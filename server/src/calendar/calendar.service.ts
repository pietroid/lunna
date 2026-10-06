import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { systemZone, Zone } from '../time/zone';
import { CalendarStore, NewEvent, RoutinePatch } from './calendar.store';
import { CalendarEvent, CalendarRoutine, CalendarUser } from './calendar.types';

/**
 * How long a read of the day is reused before going back for another.
 *
 * Every write goes through here and lands in the cache too, so this is not
 * about staleness from outside: it is how often the window slides forward and
 * the days of routines that came into it get written down.
 */
const CACHE_TTL_MS = 30_000;

/** How far back a window reaches: enough to keep a running event visible. */
const LOOK_BACK_HOURS = 2;

/**
 * How far ahead a window reaches at the least: the rest of today and the
 * whole of tomorrow. A caller that needs further, because the queue runs on
 * or the screen was scrolled to next week, says so.
 */
const LOOK_AHEAD_HOURS = 36;

/** One person's cached days. */
interface Cached {
  events: CalendarEvent[];
  readAt: number;
  /** How far ahead [events] reaches. */
  until: number;
  inFlight?: Promise<CalendarEvent[]>;
  /** How far ahead the read in flight reaches. */
  inFlightUntil?: number;
}

/**
 * The day, read and written.
 *
 * A thin cache over [CalendarStore]. The timeline is rebuilt on every list
 * and every drag, and one rebuild asks for the day dozens of times; this
 * keeps that to one query per person every half minute. Writes go to the
 * store first and only then to the cache, so the cache never holds anything
 * the database does not.
 *
 * One server process owns the cache, which is the deployment: one container
 * on the Pi.
 */
@Injectable()
export class CalendarService {
  private readonly _cache = new Map<string, Cached>();
  private readonly _defaultZone: Zone;

  constructor(
    private readonly _store: CalendarStore,
    config: ConfigService,
  ) {
    this._defaultZone = config.get<string>('LUNNA_TIMEZONE') ?? systemZone();
  }

  /**
   * Every event from a little before [now] to at least [until], from cache
   * when it is fresh and reaches that far.
   *
   * The days of routines are written down as far as the read reaches, so a
   * screen scrolled a month ahead finds that month's routines on it.
   */
  async events(
    user: CalendarUser,
    until?: Date,
    now = new Date(),
  ): Promise<CalendarEvent[]> {
    const reach = Math.max(
      until?.getTime() ?? 0,
      now.getTime() + LOOK_AHEAD_HOURS * 3_600_000,
    );
    const cached = this._entry(user);
    if (Date.now() - cached.readAt < CACHE_TTL_MS && cached.until >= reach) {
      return cached.events;
    }

    // One read at a time per person: a list and a drag arriving together are
    // the same question asked twice.
    if (cached.inFlight !== undefined && (cached.inFlightUntil ?? 0) >= reach) {
      return cached.inFlight;
    }

    const read = this._refresh(user, now, new Date(reach)).finally(() => {
      if (cached.inFlight === read) {
        cached.inFlight = undefined;
        cached.inFlightUntil = undefined;
      }
    });
    cached.inFlight = read;
    cached.inFlightUntil = reach;

    return read;
  }

  /** Every event between [from] and [to], read fresh. For reminders. */
  async between(
    user: CalendarUser,
    from: Date,
    to: Date,
  ): Promise<CalendarEvent[]> {
    return this._store.window(user, from, to, this.zone(user));
  }

  /** The zone this person's day is measured in. */
  zone(user: CalendarUser): Zone {
    return user.timeZone ?? this._defaultZone;
  }

  /** One event, from the day when it is on it and from the store otherwise. */
  async find(
    user: CalendarUser,
    eventId: string,
  ): Promise<CalendarEvent | undefined> {
    const onDay = (await this.events(user)).find((it) => it.id === eventId);
    return onDay ?? this._store.get(user, eventId);
  }

  async create(user: CalendarUser, event: NewEvent): Promise<CalendarEvent> {
    const created = await this._store.insert(user, event);
    this._put(user, created);

    return created;
  }

  /** Writes [event] whole, and answers with what was stored. */
  async save(user: CalendarUser, event: CalendarEvent): Promise<CalendarEvent> {
    const saved = await this._store.update(user, event);
    this._put(user, saved);

    return saved;
  }

  async remove(user: CalendarUser, event: CalendarEvent): Promise<void> {
    await this._store.remove(user, event);

    const cached = this._entry(user);
    cached.events = cached.events.filter((it) => it.id !== event.id);
  }

  async routines(user: CalendarUser): Promise<CalendarRoutine[]> {
    return this._store.routines(user);
  }

  async createRoutine(
    user: CalendarUser,
    routine: Required<RoutinePatch> & { title: string },
  ): Promise<CalendarRoutine> {
    const created = await this._store.insertRoutine(user, routine);
    this._invalidate(user);

    return created;
  }

  async updateRoutine(
    user: CalendarUser,
    routineId: string,
    patch: RoutinePatch,
    now = new Date(),
  ): Promise<CalendarRoutine | undefined> {
    const updated = await this._store.updateRoutine(
      user,
      routineId,
      patch,
      now,
    );
    this._invalidate(user);

    return updated;
  }

  async removeRoutine(
    user: CalendarUser,
    routineId: string,
    now = new Date(),
  ): Promise<boolean> {
    const removed = await this._store.removeRoutine(user, routineId, now);
    this._invalidate(user);

    return removed;
  }

  private async _refresh(
    user: CalendarUser,
    now: Date,
    until: Date,
  ): Promise<CalendarEvent[]> {
    const from = new Date(now.getTime() - LOOK_BACK_HOURS * 3_600_000);
    const events = await this._store.window(user, from, until, this.zone(user));

    const cached = this._entry(user);
    cached.events = events;
    cached.readAt = Date.now();
    cached.until = until.getTime();

    return events;
  }

  /** Puts [event] in the cached day in place of whatever had its id. */
  private _put(user: CalendarUser, event: CalendarEvent): void {
    const cached = this._entry(user);
    cached.events = [
      ...cached.events.filter((it) => it.id !== event.id),
      event,
    ];
  }

  /** Forgets the cached day, so the next ask goes to the store. */
  private _invalidate(user: CalendarUser): void {
    this._entry(user).readAt = 0;
  }

  private _entry(user: CalendarUser): Cached {
    let cached = this._cache.get(user.id);
    if (cached === undefined) {
      cached = { events: [], readAt: 0, until: 0 };
      this._cache.set(user.id, cached);
    }

    return cached;
  }
}
