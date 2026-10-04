import { promises as fs } from 'fs';
import * as path from 'path';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { systemZone, Zone } from '../time/zone';
import {
  CalendarEvent,
  CalendarSnapshot,
  CalendarUser,
  readCalendarEvent,
} from './calendar.types';

/**
 * How long a read of the calendar is reused before going back for another.
 *
 * The timeline is rebuilt on every list and every guard, and a day does not
 * change between two taps. Half a minute keeps the screen honest without
 * turning one person scrolling into a few hundred calls an hour.
 */
const CACHE_TTL_MS = 30_000;

/** How far back a window reaches: enough to keep a running event visible. */
const LOOK_BACK_HOURS = 2;

/** How far ahead: the rest of today and the whole of tomorrow. */
const LOOK_AHEAD_HOURS = 36;

/** One person's cached answer. */
interface Cached {
  snapshot: CalendarSnapshot;
  /** When it was read, so staleness is per person and not global. */
  readAt: number;
  inFlight?: Promise<CalendarEvent[]>;
}

/**
 * The calendar, read through the agent.
 *
 * The server never talks to Google and never holds its credentials. It asks
 * the agent, which is the same direction everything else runs in: the server
 * calls the agent, the agent answers, and the agent has no idea the server
 * exists beyond the request it is answering. Nothing calls in the other way,
 * so there is no inbound route to authenticate and no key to keep in step.
 *
 * The route it calls runs no model and no prompt. It is a list call against
 * one person's calendar, so a drag costs a round trip and not a generation.
 *
 * **A cache, not a copy.** Google decides what is true; this only remembers
 * the last answer so the screen can be drawn without asking again, and writes
 * it back the moment the server changes something so a drag does not have to
 * wait for Google to agree. A read that fails falls back to the last one that
 * worked, mirrored to disk per person so a restart does not start from an
 * empty calendar. A timeline half a minute stale is a small lie; one that
 * says the afternoon is free because Google timed out is a large one.
 *
 * Everything here is per person. One Google account holds the ecosystem and
 * each person has a calendar of their own inside it, so a cache keyed by
 * nothing was one user's afternoon showing up in another's day.
 */
@Injectable()
export class CalendarReaderService {
  private readonly _logger = new Logger(CalendarReaderService.name);

  private readonly _root =
    process.env.FOCUS_DATA_DIR ?? path.join(process.cwd(), 'data', 'threads');

  private readonly _cache = new Map<string, Cached>();

  constructor(private readonly _config: ConfigService) {}

  /** Every event worth knowing about now, from cache when it is fresh. */
  async events(user: CalendarUser, now = new Date()): Promise<CalendarEvent[]> {
    const cached = await this._load(user);

    if (Date.now() - cached.readAt < CACHE_TTL_MS)
      return cached.snapshot.events;

    // One refresh at a time per person. A list and a guard arriving together
    // are two requests asking the same question, and asking Google twice
    // would answer it no better.
    cached.inFlight ??= this._refresh(user, now).finally(() => {
      cached.inFlight = undefined;
    });

    return cached.inFlight;
  }

  /** The snapshot itself, for working out how stale the timeline is. */
  async snapshot(user: CalendarUser): Promise<CalendarSnapshot> {
    return (await this._load(user)).snapshot;
  }

  /**
   * The zone this person's calendar is kept in.
   *
   * Every piece of arithmetic about when a working day starts, which day a
   * block is on and what a card reads is done in this zone. It arrives with
   * the events, is mirrored with them, and only falls back to the server's
   * own zone before the very first read has landed.
   *
   * Read off the cache rather than from Google: a calendar's zone is a
   * setting, not a fact that moves during an afternoon, and a timeline
   * rebuild asks for it a few hundred times.
   */
  async zone(user: CalendarUser, now = new Date()): Promise<Zone> {
    const cached = await this._load(user);
    if (cached.snapshot.timeZone !== undefined) return cached.snapshot.timeZone;

    // Nothing mirrored and nothing read yet. One read now, rather than laying
    // out a whole day against the wrong clock and writing the result to
    // Google.
    await this.events(user, now);

    return (await this._load(user)).snapshot.timeZone ?? systemZone();
  }

  /** One event, as the cache last saw it. */
  async find(
    user: CalendarUser,
    eventId: string,
  ): Promise<CalendarEvent | undefined> {
    return (await this.events(user)).find((event) => event.id === eventId);
  }

  /**
   * Writes one event into the cache without waiting for the next read.
   *
   * A drag has changed the day and already knows what it did. Waiting half a
   * minute to believe itself would mean the card the user just moved sitting
   * at its old hour while the cache aged out.
   */
  async upsert(user: CalendarUser, event: CalendarEvent): Promise<void> {
    const cached = await this._load(user);

    await this._store(user, [
      ...cached.snapshot.events.filter((it) => it.id !== event.id),
      event,
    ]);
  }

  /** Takes one event out of the cache, for the same reason. */
  async remove(user: CalendarUser, eventId: string): Promise<void> {
    const cached = await this._load(user);
    await this._store(
      user,
      cached.snapshot.events.filter((it) => it.id !== eventId),
    );
  }

  /**
   * Forgets when the calendar was last read, so the next ask goes to Google.
   *
   * For the one change whose result the cache cannot work out by itself: a
   * routine written or rewritten is a whole series of instances, and only
   * Google knows which days they fall on.
   */
  async invalidate(user: CalendarUser): Promise<void> {
    (await this._load(user)).readAt = 0;
  }

  /** Replaces what is cached. Used by tests to stand in for the agent. */
  async replace(
    user: CalendarUser,
    events: CalendarEvent[],
    timeZone?: string,
  ): Promise<void> {
    const cached = await this._load(user);
    await this._store(user, events, timeZone);
    cached.readAt = Date.now();
  }

  private async _refresh(
    user: CalendarUser,
    now: Date,
  ): Promise<CalendarEvent[]> {
    const from = new Date(now.getTime() - LOOK_BACK_HOURS * 3_600_000);
    const to = new Date(now.getTime() + LOOK_AHEAD_HOURS * 3_600_000);
    const cached = await this._load(user);

    try {
      const window = await this._fetchWindow(user, from, to);
      await this._store(user, window.events, window.timeZone);
      cached.readAt = Date.now();
      return window.events;
    } catch (error) {
      // Logged, not raised. The caller is drawing a timeline or pricing a
      // slot, and the last good answer is a better input to either than an
      // exception.
      this._logger.warn(`Could not read the calendar: ${String(error)}`);
      cached.readAt = Date.now();
      return cached.snapshot.events;
    }
  }

  private async _fetchWindow(
    user: CalendarUser,
    from: Date,
    to: Date,
  ): Promise<{ events: CalendarEvent[]; timeZone?: string }> {
    const agentUrl =
      this._config.get<string>('AGENT_URL') ?? 'http://localhost:3002';

    const query = new URLSearchParams({
      userId: user.id,
      from: from.toISOString(),
      to: to.toISOString(),
    });
    if (user.email !== undefined) query.set('userEmail', user.email);
    if (user.name !== undefined) query.set('userName', user.name);

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10_000);

    try {
      const response = await fetch(
        `${agentUrl}/calendar/window?${query.toString()}`,
        { signal: controller.signal },
      );

      if (!response.ok) {
        throw new Error(`agent returned ${response.status}`);
      }

      const body = (await response.json()) as {
        events?: unknown[];
        timeZone?: unknown;
      };

      return {
        events: (body.events ?? [])
          .map(readCalendarEvent)
          .filter((event): event is CalendarEvent => event !== null),
        timeZone:
          typeof body.timeZone === 'string' && body.timeZone !== ''
            ? body.timeZone
            : undefined,
      };
    } finally {
      clearTimeout(timeoutId);
    }
  }

  /** Keeps [events] in memory and mirrors them for the next restart. */
  private async _store(
    user: CalendarUser,
    events: CalendarEvent[],
    timeZone?: string,
  ): Promise<void> {
    const cached = await this._load(user);
    cached.snapshot = {
      receivedAt: new Date().toISOString(),
      events,
      // Kept when this write is a local edit rather than a read from the
      // agent. A drag knows the new hour and knows nothing about zones, and
      // blanking it here would drop the whole day back onto the server's
      // clock until the cache next aged out.
      timeZone: timeZone ?? cached.snapshot.timeZone,
    };

    try {
      const file = this._file(user);
      await fs.mkdir(path.dirname(file), { recursive: true });
      // Through a temp file and a rename: this is written from a queue and
      // read on a restart, and half a file parses as an empty calendar.
      const temp = `${file}.tmp`;
      await fs.writeFile(
        temp,
        JSON.stringify(cached.snapshot, null, 2),
        'utf8',
      );
      await fs.rename(temp, file);
    } catch (error) {
      // The cache is still good in memory, so a disk that will not take it
      // costs nothing until the next restart.
      this._logger.warn(`Could not persist the calendar: ${String(error)}`);
    }
  }

  /** Reads the mirrored snapshot once per person, after a restart. */
  private async _load(user: CalendarUser): Promise<Cached> {
    const known = this._cache.get(user.id);
    if (known !== undefined) return known;

    const cached: Cached = {
      snapshot: { receivedAt: '', events: [] },
      readAt: 0,
    };
    this._cache.set(user.id, cached);

    try {
      const content = await fs.readFile(this._file(user), 'utf8');
      const parsed = JSON.parse(content) as Partial<CalendarSnapshot>;

      cached.snapshot = {
        receivedAt: parsed.receivedAt ?? '',
        events: Array.isArray(parsed.events)
          ? parsed.events
              .map(readCalendarEvent)
              .filter((event): event is CalendarEvent => event !== null)
          : [],
        timeZone:
          typeof parsed.timeZone === 'string' && parsed.timeZone !== ''
            ? parsed.timeZone
            : undefined,
      };
    } catch {
      // Nothing mirrored yet, which is the first request after a fresh
      // install and nothing to say about.
    }

    return cached;
  }

  /** Where one person's mirrored snapshot lives. */
  private _file(user: CalendarUser): string {
    return path.join(
      this._root,
      user.id.replace(/[^a-zA-Z0-9._-]/g, '-'),
      'calendar-cache.json',
    );
  }
}
