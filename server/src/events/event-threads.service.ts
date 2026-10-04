import { Injectable } from '@nestjs/common';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { Thread } from '../threads/entities/thread.entity';
import { ThreadsService } from '../threads/threads.service';
import { EventsService } from './events.service';

/**
 * Where a block of time and a conversation about it meet.
 *
 * The two are separate things and stay separate: an hour is on the calendar,
 * a conversation is a file, and neither carries a copy of the other. What
 * joins them is one slug written onto the Google event, set the first time
 * somebody opens a block to talk about it and read back whenever the
 * timeline is drawn.
 *
 * Most blocks never get one. A day is mostly hours, not discussions, and a
 * thread per event would be a folder full of conversations nobody had.
 */
@Injectable()
export class EventThreadsService {
  constructor(
    private readonly _events: EventsService,
    private readonly _threads: ThreadsService,
  ) {}

  /**
   * The conversation about [eventId], started if there is not one yet.
   *
   * Idempotent, because the app calls it on a tap and a tap can be a double
   * tap. A block that already names a thread gives that thread back; one
   * whose thread has since been deleted starts a new one rather than opening
   * a 404.
   */
  async open(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
  ): Promise<Thread> {
    const event = await this._events.require(user, eventId);

    if (event.threadSlug !== undefined) {
      const existing = await this._threads.find(user.id, event.threadSlug);
      if (existing !== null) return existing;
    }

    trace.log('event.startThread', { eventId, title: event.title });

    // Named after the block, because that is what the user called it when
    // they wrote it down. Nothing is said yet: the thread is an empty
    // conversation until they type, and the agent answers then, not now.
    const thread = await this._threads.createEmpty(user.id, event.title);

    await this._events.link(user, event, thread.slug, trace);

    return thread;
  }
}
