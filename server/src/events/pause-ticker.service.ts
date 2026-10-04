import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { EventLayoutService } from './event-layout.service';

/** How often a paused block's end is dragged along with the clock. */
const TICK_MS = 60_000;

/**
 * The minute tick that keeps a paused day honest.
 *
 * A paused block owes its work, so every minute it stays paused its end moves
 * a minute later and everything after it follows. Nobody has to be looking at
 * the app for that to be true on the calendar, so it runs here and not on a
 * screen.
 *
 * It only knows the people who have asked the server something since it
 * started, because a calendar call needs the person's address and name and
 * nothing on disk keeps them. After a restart the first read of the day runs
 * the same catch-up, so nothing is lost but the minutes nobody looked.
 */
@Injectable()
export class PauseTickerService implements OnModuleInit, OnModuleDestroy {
  private readonly _logger = new Logger(PauseTickerService.name);
  private readonly _users = new Map<string, CalendarUser>();
  private _timer?: NodeJS.Timeout;
  private _running = false;

  constructor(private readonly _layout: EventLayoutService) {}

  /** Remembers [user], so their paused blocks keep moving between requests. */
  watch(user: CalendarUser): void {
    this._users.set(user.id, user);
  }

  onModuleInit(): void {
    this._timer = setInterval(() => void this.tick(), TICK_MS);
    this._timer.unref();
  }

  onModuleDestroy(): void {
    clearInterval(this._timer);
  }

  /** One pass over everyone, skipped if the last one has not finished. */
  async tick(now = new Date()): Promise<void> {
    if (this._running) return;
    this._running = true;

    try {
      for (const user of this._users.values()) {
        try {
          await this._layout.catchUp(user, Trace.start(user.id), now);
        } catch (error) {
          this._logger.warn(`Pause tick failed: ${String(error)}`);
        }
      }
    } finally {
      this._running = false;
    }
  }
}
