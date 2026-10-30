import {
  Inject,
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnModuleDestroy,
  Optional,
} from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { user as users } from '../db/schema';
import { EventLayoutService } from '../events/event-layout.service';
import { AgentService } from './agent.service';

/** Never more than this between a timer's arming and its firing (setTimeout's limit). */
const MAX_DELAY_MS = 2_147_483_647;

/**
 * One timer per person, at their suggestion's `nextAt`, so the next turn is
 * written when the phone's notification says it is there.
 *
 * Armed whenever a `nextAt` is written, and once at boot for every one still
 * to come. It fires once and asks nothing on a schedule: a timer is how the
 * suggestion is on time, never how it is found, since the next read writes
 * a passed one anyway (a timer lost to a restart costs seconds, not a
 * suggestion). This is the one exception to "nothing on a timer touches
 * Postgres": a one-shot at an hour someone was told to look, never periodic.
 */
@Injectable()
export class SuggestionTimer
  implements OnApplicationBootstrap, OnModuleDestroy
{
  private readonly _timers = new Map<string, NodeJS.Timeout>();
  private readonly _log = new Logger('SuggestionTimer');

  constructor(
    private readonly _agent: AgentService,
    private readonly _layout: EventLayoutService,
    @Optional() @Inject(DB) private readonly _db?: Database,
  ) {
    _agent.onNextAt = (userId, at) => this.arm(userId, at);
  }

  async onApplicationBootstrap(): Promise<void> {
    const pending = await this._agent.pendingSuggestions(new Date());
    for (const { userId, nextAt } of pending) this.arm(userId, nextAt);
    if (pending.length > 0) {
      this._log.log(`${pending.length} suggestion timers armed`);
    }
  }

  onModuleDestroy(): void {
    for (const timer of this._timers.values()) clearTimeout(timer);
    this._timers.clear();
  }

  /** How many people have a timer armed. */
  get armed(): number {
    return this._timers.size;
  }

  /** Fires [fire] for [userId] at [at], in place of any timer they had. */
  arm(userId: string, at: Date): void {
    clearTimeout(this._timers.get(userId));
    const delay = Math.min(
      MAX_DELAY_MS,
      Math.max(0, at.getTime() - Date.now()),
    );
    const timer = setTimeout(() => {
      this._timers.delete(userId);
      void this.fire(userId);
    }, delay);
    // A timer never keeps the process up.
    timer.unref();
    this._timers.set(userId, timer);
  }

  /** Settles [userId]'s day and writes their next suggestion. */
  async fire(userId: string): Promise<void> {
    try {
      const person = await this._user(userId);
      if (person === undefined) return;
      await this._layout.catchUp(person, Trace.start(userId, 'suggestion'));
      await this._agent.suggestion(person, new Date());
    } catch (error) {
      this._log.warn(
        `suggestion for ${userId} failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  /** The person, as a request would put them on it. */
  protected async _user(userId: string): Promise<CalendarUser | undefined> {
    if (this._db === undefined) return undefined;
    const [row] = await this._db
      .select()
      .from(users)
      .where(eq(users.id, userId));
    if (row === undefined) return undefined;

    return {
      id: row.id,
      email: row.email,
      name: row.name,
      timeZone: row.timeZone,
      workDay: { start: row.dayStart, end: row.dayEnd },
    };
  }
}
