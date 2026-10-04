import { BadRequestException, Injectable } from '@nestjs/common';
import { startNowGuard } from '../a2ui/a2ui.guards';
import { A2uiComponent, TimingAction } from '../a2ui/a2ui.types';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { ThreadsStore } from '../threads/threads.store';
import { moved, PlannedBlock, relayout } from '../time/scheduling';
import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  earliestStart,
  floorToMinute,
  Interval,
  minutesOf,
  nextFreeSlot,
  roundUpToFiveMinutes,
} from '../time/work-hours';
import { Zone } from '../time/zone';
import { CalendarEvent } from '../calendar/calendar.types';
import { EventCard, EventEdit, EventRequest } from './entities/event.entity';
import { awaitsStart, intervalOf, isRunning } from './event-sections';
import { EventsService, TimeBlock, workSecondsOf } from './events.service';

/** What a move produced: the timeline, and a question if one is still open. */
export interface TimingOutcome {
  cards: EventCard[];
  /** The guard to draw. Absent means the move went through. */
  guard?: A2uiComponent;
}

/**
 * When things happen.
 *
 * Three operations, and one rule underneath all of them. The rule is that the
 * day is a queue of flexible blocks flowing around a handful of fixed ones,
 * packed as close to now as they will go. Adding drops something into the
 * first gap that fits without disturbing anybody; dragging rewrites the queue
 * order and lets the whole thing repack; finishing something takes it out and
 * closes the hole it left.
 *
 * No model is involved, and nothing is asked that arithmetic can answer. The
 * single surviving question is what to do with the thing that was already
 * running when something else was dragged on top of it.
 *
 * Every hour this works out is written to the calendar, because the calendar
 * is the only place an hour is kept. The write does not hold up the drop: see
 * [EventsService] for the order, and [CalendarSyncService] for what the user
 * sees on the rare occasion Google will not take it.
 */
@Injectable()
export class EventLayoutService {
  constructor(
    private readonly _events: EventsService,
    private readonly _threads: ThreadsStore,
  ) {}

  /**
   * Writes something down and puts it on the timeline.
   *
   * A flexible block takes the first gap that fits, which is what "as close
   * to now as possible without moving anything" means in one line. A fixed
   * one takes the hour it was given, whatever else is there: the user named
   * it, so it is not the server's to negotiate.
   *
   * A flexible block written down from a tap on empty room later in the day
   * starts looking there rather than now, and keeps that as its floor, so
   * the next repack does not pull it back to the top of the day.
   *
   * Nothing is said and no thread is started. It is a block of time, and a
   * block of time that nobody has anything to say about yet is the normal
   * case rather than a thread waiting to happen.
   */
  async create(
    user: CalendarUser,
    request: EventRequest,
    trace: Trace,
    now = new Date(),
  ): Promise<EventCard[]> {
    const blocks = await this._events.blocks(user);
    const floor = floorOf(request, now);
    const slot = slotFor(
      request,
      blocks,
      floor ?? now,
      await this._events.zone(user, now),
    );

    trace.log('event.create', {
      fixed: request.fixed,
      start: slot.start.toISOString(),
    });

    await this._events.book(
      user,
      { title: request.title, slot, fixed: request.fixed, notBefore: floor },
      trace,
    );

    return this._events.cards(user, now);
  }

  /**
   * Moves one block to [index] in the day's queue and repacks around it.
   *
   * The index is a place in the whole timeline rather than in a section,
   * because the sections are only the clock reading itself back: there is one
   * list, and a drop is a place in it.
   *
   * A day of a routine moves like any fixed block. It is one instance of the
   * recurring event, and Google keeps a moved instance as an exception to the
   * series, so the other days stay where the routine puts them.
   */
  async move(
    user: CalendarUser,
    action: TimingAction,
    trace: Trace,
    now = new Date(),
  ): Promise<TimingOutcome> {
    const event = await this._events.require(user, action.eventId);
    if (!event.managed) {
      throw new BadRequestException('A meeting cannot be moved here');
    }

    const zone = await this._events.zone(user, now);
    const cards = await this._events.cards(user, now);
    // A block still waiting for the user to begin it has not displaced
    // anything, so dragging something over it is not the destructive move.
    const running = cards.find(
      (card) =>
        card.managed &&
        !card.awaitingStart &&
        card.id !== action.eventId &&
        Date.parse(card.startTime) <= now.getTime() &&
        Date.parse(card.endTime) > now.getTime(),
    );

    // The only destructive drag there is: something else is happening, and
    // the user has just said this is what they are doing instead.
    if (action.index === 0 && running !== undefined && !action.decision) {
      return {
        cards,
        guard: startNowGuard(
          action.eventId,
          action.index,
          {
            title: running.title,
            interval: {
              start: new Date(running.startTime),
              end: new Date(running.endTime),
            },
          },
          zone,
        ),
      };
    }

    const closed =
      action.decision === 'solve_current' && running !== undefined
        ? running.id
        : undefined;

    // The two blocks a drag is allowed to move out of their hour. Normally it
    // is just the card under the finger; when the user chose to keep what was
    // running and do it later, it is that one instead, because pushing it
    // down the day is the whole of what they asked for.
    const thawed =
      action.decision === 'postpone_current' ? running?.id : action.eventId;

    if (closed !== undefined) await this._complete(user, closed, trace, now);

    // A drop into a gap asks for that gap, so the block is not laid out any
    // earlier than where it starts. A drop between two cards asks for no
    // such thing, and lifts whatever floor the block had.
    const floor =
      action.after === undefined
        ? undefined
        : laterOf(floorToMinute(new Date(action.after)), floorToMinute(now));
    if (floor?.toISOString() !== event.notBefore) {
      await this._events.revise(
        user,
        event,
        { notBefore: floor?.toISOString() },
        trace,
      );
    }

    // The block that was just closed is out of the day, so it is out of the
    // queue too. Laying it out again would leave a hole in the afternoon the
    // shape of something nobody is going to do.
    await this._repack(
      user,
      queueOf(cards, action, now, { closed, thawed, floor }),
      trace,
      now,
      zone,
    );

    // Dropping a block at the top is the user saying they are doing it now,
    // which is as clear a yes as the button that asks.
    if (action.index === 0) await this._markStarted(user, event.id, trace, now);

    return { cards: await this._events.cards(user, now) };
  }

  /**
   * The user began a block that was waiting for them.
   *
   * One that has not reached its hour yet is the same request as dragging it
   * to the top, and goes the same way, guard and all.
   */
  async start(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<TimingOutcome> {
    const event = await this._managed(user, eventId);
    const interval = intervalOf(event);

    if (interval !== undefined && interval.start > now) {
      return this.move(user, { type: 'timing', eventId, index: 0 }, trace, now);
    }

    trace.log('event.start', { eventId });
    await this._markStarted(user, eventId, trace, now);

    return { cards: await this._events.cards(user, now) };
  }

  /**
   * Not yet: the block waits [minutes] more before asking again.
   *
   * Written as a floor rather than as an hour, so the rest of the day keeps
   * flowing around it and the next repack does not pull it straight back.
   */
  async snooze(
    user: CalendarUser,
    eventId: string,
    minutes: number,
    trace: Trace,
    now = new Date(),
  ): Promise<EventCard[]> {
    const event = await this._managed(user, eventId);
    if (event.fixed) {
      throw new BadRequestException('Um bloco fixo começa na hora dele.');
    }

    const floor = floorToMinute(addMinutes(now, minutes));
    trace.log('event.snooze', { eventId, until: floor.toISOString() });

    await this._events.revise(
      user,
      event,
      { notBefore: floor.toISOString(), started: undefined },
      trace,
    );

    return this._relayout(user, trace, now);
  }

  /**
   * Marks a block done.
   *
   * A block that is running is cut off at this minute and stays on the
   * calendar as what actually happened. The rest of the day then starts five
   * minutes from now, which is the break between one thing and the next. A
   * block that never started had no hour to keep, so it simply leaves.
   *
   * A calendar that refuses does not put the block back. It is done whatever
   * Google thinks, and having the card spring back onto the timeline because
   * a rebooking timed out would be the app arguing with the user about
   * something they already know.
   */
  async done(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<EventCard[]> {
    const zone = await this._events.zone(user, now);
    const cards = await this._events.cards(user, now);
    const wasRunning = await this._complete(user, eventId, trace, now);

    await this._safeRepack(
      user,
      blocksOf(cards, now, { closed: eventId }),
      trace,
      wasRunning ? addMinutes(now, BLOCK_GAP_MINUTES) : now,
      zone,
    );

    return this._events.cards(user, now);
  }

  /**
   * Takes a block off the calendar entirely, as if it had never been booked.
   *
   * Unlike [done] nothing of it is kept, and the day closes up over the space
   * from now, with no break: nothing was finished, so there is nothing to
   * rest from.
   */
  async remove(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<EventCard[]> {
    const zone = await this._events.zone(user, now);
    const cards = await this._events.cards(user, now);
    const event = await this._managed(user, eventId);

    trace.log('event.remove', { eventId, slug: event.threadSlug });
    await this._events.erase(user, event, trace);
    await this._closeThread(user, event);

    await this._safeRepack(
      user,
      blocksOf(cards, now, { closed: eventId }),
      trace,
      now,
      zone,
    );

    return this._events.cards(user, now);
  }

  /**
   * Pauses the block that is running.
   *
   * Nothing moves yet. What is written down is the moment it stopped and how
   * much work was still owed, and from then on [catchUp] drags its end along
   * with the clock so the owed work is always still ahead of it.
   */
  async pause(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<EventCard[]> {
    const event = await this._managed(user, eventId);
    const interval = intervalOf(event);
    if (interval === undefined || !isRunning(now, interval)) {
      throw new BadRequestException('Só dá para pausar o que está rodando.');
    }
    if (awaitsStart(event, now)) {
      throw new BadRequestException('Comece o bloco antes de pausar.');
    }

    if (event.pausedAt === undefined) {
      trace.log('event.pause', { eventId });
      await this._events.revise(
        user,
        event,
        {
          pausedAt: now.toISOString(),
          remainingSeconds: Math.max(
            0,
            (interval.end.getTime() - now.getTime()) / 1000,
          ),
        },
        trace,
      );
    }

    return this._events.cards(user, now);
  }

  /** Runs a paused block again, owing exactly what it owed when it stopped. */
  async resume(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<EventCard[]> {
    const event = await this._managed(user, eventId);
    if (event.pausedAt === undefined) return this._events.cards(user, now);

    const pausedFor = Math.max(
      0,
      (now.getTime() - Date.parse(event.pausedAt)) / 1000,
    );

    trace.log('event.resume', { eventId, pausedFor });
    await this._events.revise(
      user,
      event,
      {
        endTime: pausedEnd(event, now).toISOString(),
        pausedAt: undefined,
        remainingSeconds: undefined,
        pausedSeconds: (event.pausedSeconds ?? 0) + pausedFor,
      },
      trace,
    );

    return this._relayout(user, trace, now);
  }

  /**
   * Gives a block [minutes] more, and pushes whatever comes after it.
   *
   * The estimate was wrong, which is the whole of it: the end moves, and the
   * day repacks behind it. A paused block owes the extra minutes too.
   */
  async extend(
    user: CalendarUser,
    eventId: string,
    minutes: number,
    trace: Trace,
    now = new Date(),
  ): Promise<EventCard[]> {
    const event = await this._managed(user, eventId);
    const end = addMinutes(new Date(event.endTime), minutes);

    if (end <= now || end.getTime() <= Date.parse(event.startTime)) {
      throw new BadRequestException('Essa duração já passou.');
    }

    trace.log('event.extend', { eventId, minutes });
    await this._events.revise(
      user,
      event,
      {
        endTime: end.toISOString(),
        ...(event.pausedAt === undefined
          ? {}
          : {
              remainingSeconds: Math.max(
                0,
                (event.remainingSeconds ?? 0) + minutes * 60,
              ),
            }),
      },
      trace,
    );

    return this._relayout(user, trace, now);
  }

  /**
   * Renames a block, changes how long it takes, or pins it to an hour.
   *
   * The duration is the work, pauses left out, so it goes through [extend]
   * as the difference from what it was. An hour can only be named for
   * something that has not started: a running block's start is a fact.
   */
  async edit(
    user: CalendarUser,
    eventId: string,
    edit: EventEdit,
    trace: Trace,
    now = new Date(),
  ): Promise<EventCard[]> {
    let event = await this._managed(user, eventId);

    if (edit.title !== undefined && edit.title !== event.title) {
      event = await this._events.revise(
        user,
        event,
        { title: edit.title },
        trace,
      );
    }

    if (edit.startTime !== undefined) {
      const interval = intervalOf(event);
      if (interval !== undefined && interval.start <= now) {
        throw new BadRequestException(
          'Não dá para mudar o início de algo que já começou.',
        );
      }

      const start = floorToMinute(new Date(edit.startTime));
      const work = edit.workMinutes ?? Math.round(workSecondsOf(event) / 60);

      trace.log('event.pin', { eventId, start: start.toISOString() });
      await this._events.revise(
        user,
        event,
        {
          startTime: start.toISOString(),
          endTime: addMinutes(start, work).toISOString(),
          fixed: true,
          pausedAt: undefined,
          remainingSeconds: undefined,
          pausedSeconds: undefined,
          started: undefined,
          notBefore: undefined,
        },
        trace,
      );

      return this._relayout(user, trace, now);
    }

    if (edit.workMinutes !== undefined) {
      const delta = edit.workMinutes - Math.round(workSecondsOf(event) / 60);
      if (delta !== 0) return this.extend(user, eventId, delta, trace, now);
    }

    return this._events.cards(user, now);
  }

  /**
   * Drags every paused block's end along with the clock.
   *
   * Run by the minute tick and before every read of the day, and safe to run
   * any number of times: the end is always now plus what is still owed, so a
   * second call in the same minute changes nothing and a call after the
   * server was down for an hour catches the whole hour up at once.
   */
  async catchUp(
    user: CalendarUser,
    trace: Trace,
    now = new Date(),
  ): Promise<boolean> {
    let changed = false;

    for (const event of await this._events.paused(user)) {
      const end = pausedEnd(event, now);
      if (end.getTime() === Date.parse(event.endTime)) continue;

      await this._events.revise(
        user,
        event,
        { endTime: end.toISOString() },
        trace,
      );
      changed = true;
    }

    // A block whose hour came and that nobody began slides with the clock,
    // a minute at a time, until the user says so. It is moved here rather
    // than left to the repack because one whose whole span has gone by would
    // no longer be on the day at all, and the repack only sees the day.
    const minute = floorToMinute(now);
    for (const event of await this._events.waiting(user, now)) {
      const interval = intervalOf(event);
      if (interval === undefined || interval.start >= minute) continue;

      await this._events.revise(
        user,
        event,
        {
          startTime: minute.toISOString(),
          endTime: addMinutes(minute, minutesOf(interval)).toISOString(),
        },
        trace,
      );
      changed = true;
    }

    if (changed) await this._relayout(user, trace, now);

    return changed;
  }

  /**
   * Off the day, as done.
   *
   * Returns whether it was running, which is what decides whether the next
   * thing waits five minutes for it.
   */
  private async _complete(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
    now: Date,
  ): Promise<boolean> {
    const event = await this._managed(user, eventId);
    const interval = intervalOf(event);
    // A block still waiting to be begun never ran, so there is no hour of it
    // to keep.
    const running =
      interval !== undefined &&
      isRunning(now, interval) &&
      !awaitsStart(event, now);

    trace.log('event.done', { eventId, running, slug: event.threadSlug });

    // Kept on the calendar as the hour it really took. A block that started
    // this very second has no hour to keep, so it goes like one that never
    // started.
    if (running && interval.start < now) {
      await this._events.revise(
        user,
        event,
        {
          endTime: now.toISOString(),
          pausedAt: undefined,
          remainingSeconds: undefined,
        },
        trace,
      );
    } else {
      await this._events.erase(user, event, trace);
    }

    await this._closeThread(user, event);

    return running;
  }

  /**
   * The conversation about a block, closed with it.
   *
   * The thread is not a mirror of the block, but it is about it: a block the
   * user has finished with is not something they still have an open question
   * about, and leaving the conversation in Coisas would be the app asking
   * them to close the same thing twice.
   */
  private async _closeThread(
    user: CalendarUser,
    event: CalendarEvent,
  ): Promise<void> {
    if (event.threadSlug === undefined) return;

    await this._threads.updateState(user.id, event.threadSlug, {
      solved: true,
    });
  }

  /** Says on [eventId] that the user began it, when it has begun. */
  private async _markStarted(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
    now: Date,
  ): Promise<void> {
    const event = await this._events.require(user, eventId);
    const interval = intervalOf(event);
    if (interval === undefined || interval.start > now) return;
    if (event.started === true && event.notBefore === undefined) return;

    await this._events.revise(
      user,
      event,
      { started: true, notBefore: undefined },
      trace,
    );
  }

  /** One event Focus booked, or a refusal. */
  private async _managed(
    user: CalendarUser,
    eventId: string,
  ): Promise<CalendarEvent> {
    const event = await this._events.require(user, eventId);
    if (!event.managed) {
      throw new BadRequestException('Uma reunião não pode ser mudada aqui.');
    }

    return event;
  }

  /** The day as it stands, repacked from now, and then read back. */
  private async _relayout(
    user: CalendarUser,
    trace: Trace,
    now: Date,
  ): Promise<EventCard[]> {
    const zone = await this._events.zone(user, now);
    const cards = await this._events.cards(user, now);

    await this._safeRepack(user, blocksOf(cards, now), trace, now, zone);

    return this._events.cards(user, now);
  }

  /**
   * [_repack], with a failure logged rather than raised.
   *
   * By the time this runs the change the user asked for has landed, and a
   * rearrangement that could not be written is not a reason to tell them it
   * did not.
   */
  private async _safeRepack(
    user: CalendarUser,
    queue: PlannedBlock[],
    trace: Trace,
    from: Date,
    zone: Zone,
  ): Promise<void> {
    try {
      await this._repack(user, queue, trace, from, zone);
    } catch (error) {
      trace.warn('event.repackFailed', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /** Lays the queue out from [from] and writes everything that moved. */
  private async _repack(
    user: CalendarUser,
    queue: PlannedBlock[],
    trace: Trace,
    from: Date,
    zone: Zone,
  ): Promise<void> {
    const anchors = queue
      .filter((block) => block.fixed)
      .map((block) => block.interval);

    const placed = relayout(queue, anchors, earliestStart(from, zone), zone);

    for (const block of queue) {
      const slot = placed.get(block.id);
      if (slot === undefined || !moved(block, slot)) continue;

      trace.log('event.repack', {
        eventId: block.id,
        from: block.interval.start.toISOString(),
        to: slot.start.toISOString(),
      });

      const event = await this._events.require(user, block.id);

      // A paused block only ever moves when the user pushed it down the day,
      // and a block that is no longer running is no longer paused: it starts
      // again later owing what it owed. For the same reason a block that had
      // been begun and is moved has to be begun again when its hour comes.
      await this._events.revise(
        user,
        event,
        {
          startTime: slot.start.toISOString(),
          endTime: slot.end.toISOString(),
          ...(event.started === true ? { started: undefined } : {}),
          ...(event.pausedAt === undefined
            ? {}
            : {
                pausedAt: undefined,
                remainingSeconds: undefined,
                pausedSeconds: undefined,
              }),
        },
        trace,
      );
    }
  }
}

/**
 * Where a paused block ends at [now]: what it still owes, from now.
 *
 * Rounded up to the minute, so the tick moves the calendar once a minute and
 * not once a second.
 */
function pausedEnd(event: CalendarEvent, now: Date): Date {
  const end = new Date(now.getTime() + (event.remainingSeconds ?? 0) * 1000);
  if (end.getSeconds() !== 0 || end.getMilliseconds() !== 0) {
    end.setSeconds(60, 0);
  }

  return end;
}

/**
 * Where a new flexible block starts looking, when it was asked to start
 * later than now. A floor already behind the clock is no floor at all.
 */
function floorOf(request: EventRequest, now: Date): Date | undefined {
  if (request.fixed || request.notBefore === undefined) return undefined;

  const floor = floorToMinute(new Date(request.notBefore));
  return floor > now ? floor : undefined;
}

/** The hour a new block gets, looking from [from]. */
function slotFor(
  request: EventRequest,
  blocks: TimeBlock[],
  from: Date,
  zone: Zone,
): Interval {
  if (request.fixed && request.startTime !== undefined) {
    const start = roundUpToFiveMinutes(new Date(request.startTime));
    return { start, end: addMinutes(start, request.durationMinutes) };
  }

  return nextFreeSlot(
    earliestStart(from, zone),
    request.durationMinutes,
    blocks.map((block) => block.interval),
    zone,
  );
}

/**
 * The day as a queue: every card in screen order, [closed] left out.
 *
 * The order on screen is the order of the queue, which is the whole of what
 * the sections are. Nothing here decides an hour; that is the layout's job,
 * and this only says what is in the day, in what order, and which of it is
 * allowed to move.
 */
function blocksOf(
  cards: EventCard[],
  now: Date,
  options: { closed?: string; thawed?: string } = {},
): PlannedBlock[] {
  return cards
    .filter((card) => card.id !== options.closed)
    .map((card): PlannedBlock => {
      const interval = {
        start: new Date(card.startTime),
        end: new Date(card.endTime),
      };

      return {
        id: card.id,
        minutes: card.durationMinutes,
        fixed: anchored(card, interval, now, options.thawed),
        interval,
        notBefore:
          card.notBefore === undefined ? undefined : new Date(card.notBefore),
      };
    });
}

/**
 * Whether a layout has to leave this block exactly where it is.
 *
 * Three reasons, and the third is the subtle one. A meeting is somebody
 * else's hour and a pinned block's hour is the point of it — neither is the
 * layout's to move. And **a block that has already started keeps the hour it
 * started at**: "Agora" says what the user is working on, not that they began
 * it this second, so rearranging the afternoon must not quietly rewrite a
 * block that has been running since eleven to say it began now. Its start is
 * a fact by then, not a plan.
 *
 * [thawed] is the one block the user has just said to move anyway: the card
 * under their finger, or the running one they chose to push down. Being asked
 * to move something beats every reason it would otherwise hold still.
 */
function anchored(
  card: EventCard,
  interval: Interval,
  now: Date,
  thawed?: string,
): boolean {
  if (card.id === thawed) return card.fixed;

  // A block waiting to be begun has no start to keep yet: it is the one
  // running block the clock is allowed to push.
  return (
    card.fixed ||
    !card.managed ||
    (isRunning(now, interval) && !card.awaitingStart)
  );
}

/** Whichever of [a] and [b] comes later. */
function laterOf(a: Date, b: Date): Date {
  return a > b ? a : b;
}

/**
 * The day's queue after the drop: every card in screen order, with the
 * dragged one lifted out and put back at [action.index].
 *
 * Meetings stay in the queue so a drop counted past one lands where the
 * finger was, but they are anchors and so nothing ever assigns them a new
 * hour.
 */
function queueOf(
  cards: EventCard[],
  action: TimingAction,
  now: Date,
  options: { closed?: string; thawed?: string; floor?: Date } = {},
): PlannedBlock[] {
  const blocks = blocksOf(cards, now, options);

  const from = blocks.findIndex((block) => block.id === action.eventId);
  if (from === -1) return blocks;

  const [dragged] = blocks.splice(from, 1);
  // Dropping a card at the top is the user saying "now", and dropping it into
  // a gap is the user naming where it goes; either overrules the hour it was
  // pinned to. Nothing else about the drop can.
  const landing: PlannedBlock = {
    ...dragged,
    fixed: action.index === 0 || options.floor ? false : dragged.fixed,
    notBefore: options.floor,
    minutes: action.minutes ?? dragged.minutes,
  };
  blocks.splice(Math.min(action.index, blocks.length), 0, landing);

  return blocks;
}
