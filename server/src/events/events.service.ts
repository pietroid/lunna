import {
  BadGatewayException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { syncFailedUi } from '../a2ui/a2ui.guards';
import { A2uiComponent } from '../a2ui/a2ui.types';
import { CalendarReaderService } from '../calendar/calendar-reader.service';
import {
  CalendarSyncService,
  SyncFailure,
} from '../calendar/calendar-sync.service';
import {
  CalendarWriteError,
  CalendarWriterService,
  EventPatch,
} from '../calendar/calendar-writer.service';
import { CalendarEvent, CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { previewFrom } from '../threads/thread-markdown';
import { ThreadsStore } from '../threads/threads.store';
import { PlannedBlock } from '../time/scheduling';
import { Interval, minutesOf } from '../time/work-hours';
import { Zone } from '../time/zone';
import { EventCard } from './entities/event.entity';
import { awaitsStart, intervalOf, sectionOf } from './event-sections';

/** How the calendar catch-up went: nothing to say, or something to draw. */
export interface SyncOutcome {
  ok: boolean;
  /** The popup, when the calendar did not keep up. */
  guard?: A2uiComponent;
}

/** One block of occupied time, as the layout sees it. */
export interface TimeBlock extends PlannedBlock {
  title: string;
  /** Whether Focus booked it, and so may move it. */
  managed: boolean;
}

/**
 * The day, read and written.
 *
 * One source: the calendar. A card on the timeline is an event on Google, its
 * hour is the event's hour, and there is no second copy of any of that to
 * fall out of step. What a thread adds, when a block has one, is the last
 * line of the conversation about it — read from the thread at the moment the
 * list is built, never stored on the card.
 *
 * Writes go to the cached day first and to Google from a queue behind the
 * response. A drag has to land under the finger, and waiting for Google to
 * agree before the card settles is what made it feel like a form. The cache
 * is only ever a cache: it holds what was pushed, the push is a
 * reconciliation that can run twice, and the next read from Google overwrites
 * it whatever it said.
 */
@Injectable()
export class EventsService {
  constructor(
    private readonly _reader: CalendarReaderService,
    private readonly _writer: CalendarWriterService,
    private readonly _syncs: CalendarSyncService,
    private readonly _threads: ThreadsStore,
  ) {}

  /**
   * Every card the timeline draws, earliest first.
   *
   * An hour that has run out is simply not in the list. The event stays on
   * the calendar, because it happened, and nothing has to be swept, closed or
   * rewritten as the day goes by: the clock decides what is drawn, on every
   * read.
   */
  async cards(user: CalendarUser, now = new Date()): Promise<EventCard[]> {
    const cards: EventCard[] = [];
    const zone = await this.zone(user, now);

    for (const event of await this._reader.events(user, now)) {
      const interval = intervalOf(event);
      if (interval === undefined) continue;

      const section = sectionOf(now, interval, zone);
      if (section === undefined) continue;

      cards.push({
        id: event.id,
        title: event.title,
        section,
        startTime: interval.start.toISOString(),
        endTime: interval.end.toISOString(),
        durationMinutes: minutesOf(interval),
        fixed: event.fixed,
        managed: event.managed,
        threadSlug: event.threadSlug,
        ...(await this._conversation(user, event)),
        pausedAt: event.pausedAt,
        remainingSeconds: event.remainingSeconds,
        pausedSeconds: event.pausedSeconds ?? 0,
        workMinutes: Math.round(workSecondsOf(event) / 60),
        awaitingStart: awaitsStart(event, now),
        notBefore: event.notBefore,
        routine: event.routine,
      });
    }

    return cards.sort(
      (a, b) => Date.parse(a.startTime) - Date.parse(b.startTime),
    );
  }

  /**
   * Every block of time that is spoken for, [excludeId] aside.
   *
   * The block being moved is left out, because otherwise it collides with
   * itself the moment anyone tries to move it half an hour.
   */
  async blocks(
    user: CalendarUser,
    options: { excludeId?: string } = {},
  ): Promise<TimeBlock[]> {
    const blocks: TimeBlock[] = [];

    for (const event of await this._reader.events(user)) {
      if (event.id === options.excludeId) continue;

      const interval = intervalOf(event);
      if (interval === undefined) continue;

      blocks.push({
        id: event.id,
        title: event.title,
        minutes: minutesOf(interval),
        fixed: event.fixed,
        managed: event.managed,
        interval,
      });
    }

    return blocks.sort(
      (a, b) => a.interval.start.getTime() - b.interval.start.getTime(),
    );
  }

  /**
   * The zone every hour on this person's day is measured in.
   *
   * The calendar's own, not the server's. Everything that decides an hour —
   * the working window, which day a block falls on, the range printed in a
   * guard — takes it from here, so there is one answer to "what time is it
   * for this person" and it is the one their calendar gives.
   */
  async zone(user: CalendarUser, now = new Date()): Promise<Zone> {
    return this._reader.zone(user, now);
  }

  /** One event, or a 404 when the day has nothing by that id. */
  async require(user: CalendarUser, eventId: string): Promise<CalendarEvent> {
    const event = await this._reader.find(user, eventId);
    if (event === undefined) {
      throw new NotFoundException(`No event "${eventId}"`);
    }

    return event;
  }

  /**
   * Books a block and waits for it.
   *
   * The one write that is not queued. A create has no id until Google gives
   * it one, and a card with no id is a card nothing can move, finish or talk
   * to. It is also the one write nobody is dragging: it comes from a sheet
   * that is closing, which is the one moment in the app where a few hundred
   * milliseconds is affordable.
   */
  async book(
    user: CalendarUser,
    event: {
      title: string;
      slot: Interval;
      fixed: boolean;
      threadSlug?: string;
      notBefore?: Date;
    },
    trace: Trace,
  ): Promise<CalendarEvent> {
    let created: CalendarEvent;

    try {
      created = await this._writer.create(
        user,
        {
          title: event.title,
          startTime: event.slot.start.toISOString(),
          endTime: event.slot.end.toISOString(),
          fixed: event.fixed,
          threadSlug: event.threadSlug,
          notBefore: event.notBefore?.toISOString(),
        },
        trace,
      );
    } catch (error) {
      if (!(error instanceof CalendarWriteError)) throw error;

      // Nothing was written down. There is no second store to fall back on
      // and no ghost to leave behind: the sheet says so and stays open.
      trace.error('event.bookFailed', { error: error.message });
      throw new BadGatewayException('Não consegui falar com a sua agenda.');
    }

    await this._reader.upsert(user, created);

    return created;
  }

  /**
   * Moves one block, on screen now and on Google shortly.
   *
   * The cache moves first so the next layout, which may well run before
   * Google has answered, prices the day against the hour the user can see
   * rather than the one it used to have.
   */
  async moveTo(
    user: CalendarUser,
    event: CalendarEvent,
    to: Interval,
    trace: Trace,
  ): Promise<void> {
    const when = {
      startTime: to.start.toISOString(),
      endTime: to.end.toISOString(),
    };

    await this._reader.upsert(user, { ...event, ...when });

    this._enqueue(user, event.id, event.title, trace, async () => {
      const current = await this._reader.find(user, event.id);

      // Pushed from the cache rather than from the closure, so a card dragged
      // three times in five seconds costs three instant drops and one
      // calendar that ends up at the third one.
      await this._writer.patch(
        user,
        event.id,
        {
          startTime: current?.startTime ?? when.startTime,
          endTime: current?.endTime ?? when.endTime,
        },
        trace,
      );
    });
  }

  /**
   * Changes anything about one block, on screen now and on Google shortly.
   *
   * The general form of [moveTo]. The patch sent to Google is read from the
   * cache when the job runs, not from [changes], so a paused block rewritten
   * every minute costs one instant change per minute and a calendar that ends
   * up at the latest one.
   */
  async revise(
    user: CalendarUser,
    event: CalendarEvent,
    changes: Partial<Omit<CalendarEvent, 'id' | 'managed'>>,
    trace: Trace,
  ): Promise<CalendarEvent> {
    const next = { ...event, ...changes };
    // A pause key named in [changes] has to reach Google even when it is
    // being cleared, which is exactly when the cache no longer carries it.
    const touchesPause =
      'pausedAt' in changes ||
      'remainingSeconds' in changes ||
      'pausedSeconds' in changes;

    await this._reader.upsert(user, next);

    this._enqueue(user, event.id, event.title, trace, async () => {
      const current = (await this._reader.find(user, event.id)) ?? next;
      await this._writer.patch(
        user,
        event.id,
        patchOf(current, touchesPause || current.pausedAt !== undefined),
        trace,
      );
    });

    return next;
  }

  /** Every event on the calendar that is paused, whatever its hour now says. */
  async paused(user: CalendarUser): Promise<CalendarEvent[]> {
    return (await this._reader.events(user)).filter(
      (event) => event.managed && event.pausedAt !== undefined,
    );
  }

  /** Every block whose hour came and that is still waiting to be begun. */
  async waiting(
    user: CalendarUser,
    now = new Date(),
  ): Promise<CalendarEvent[]> {
    return (await this._reader.events(user, now)).filter((event) =>
      awaitsStart(event, now),
    );
  }

  /** Takes a block off the day, and off Google behind the response. */
  async erase(
    user: CalendarUser,
    event: CalendarEvent,
    trace: Trace,
  ): Promise<void> {
    await this._reader.remove(user, event.id);

    this._enqueue(user, event.id, event.title, trace, async () => {
      await this._writer.remove(user, event.id, trace);
    });
  }

  /**
   * Says on the event which conversation it belongs to.
   *
   * Awaited, not queued: the app is about to open that conversation, and a
   * link that has not landed yet is a block that opens a second thread the
   * next time it is tapped.
   */
  async link(
    user: CalendarUser,
    event: CalendarEvent,
    slug: string,
    trace: Trace,
  ): Promise<CalendarEvent> {
    const linked = await this._writer.patch(
      user,
      event.id,
      { threadSlug: slug },
      trace,
    );

    await this._reader.upsert(user, linked);

    return linked;
  }

  /**
   * Waits for the queued calendar work and reports what the user should see.
   *
   * Nothing to say is the usual answer and the good one. When there is
   * something, it is a tree rather than an error: the day on screen is not
   * wrong, only its copy on Google, and the user needs a button rather than
   * an apology.
   */
  async awaitSync(userId: string, trace: Trace): Promise<SyncOutcome> {
    const failure = await this._syncs.settle(userId);
    if (failure !== undefined) {
      trace.warn('sync.behind', {
        title: failure.title,
        error: failure.error,
      });
    }

    return outcomeOf(failure);
  }

  /** Runs the failed calendar work again. */
  async retrySync(userId: string, trace: Trace): Promise<SyncOutcome> {
    return outcomeOf(await this._syncs.retry(userId, trace));
  }

  /** The last line of the conversation about [event], when it has one. */
  private async _conversation(
    user: CalendarUser,
    event: CalendarEvent,
  ): Promise<{ preview: string; messageCount: number }> {
    if (event.threadSlug === undefined) {
      return { preview: '', messageCount: 0 };
    }

    const thread = await this._threads.read(user.id, event.threadSlug);
    if (thread === null) return { preview: '', messageCount: 0 };

    const last = thread.messages[thread.messages.length - 1];

    return {
      preview: last === undefined ? '' : previewFrom(last),
      messageCount: thread.messages.length,
    };
  }

  private _enqueue(
    user: CalendarUser,
    eventId: string,
    title: string,
    trace: Trace,
    job: () => Promise<void>,
  ): void {
    this._syncs.enqueue(user.id, eventId, title, job, trace);
  }
}

/**
 * The whole of an event as a patch.
 *
 * The pause keys ride along only when [withPause] says so: writing them makes
 * the agent read the event before patching it, and almost nothing is paused.
 */
function patchOf(event: CalendarEvent, withPause: boolean): EventPatch {
  const patch: EventPatch = {
    title: event.title,
    startTime: event.startTime,
    endTime: event.endTime,
    fixed: event.fixed,
    // Both ride along on every patch: [fixed] already makes the agent read
    // the event's private bag first, so they cost nothing extra, and a key
    // that is only sent when set is a key that can never be cleared.
    started: event.started === true,
    notBefore: event.notBefore ?? '',
  };
  if (!withPause) return patch;

  return {
    ...patch,
    pausedAt: event.pausedAt ?? '',
    remainingSeconds: event.remainingSeconds ?? 0,
    pausedSeconds: event.pausedSeconds ?? 0,
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

function outcomeOf(failure: SyncFailure | undefined): SyncOutcome {
  if (failure === undefined) return { ok: true };

  return { ok: false, guard: syncFailedUi(failure.title) };
}
