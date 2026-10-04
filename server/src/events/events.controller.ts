import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import * as adminAuth from 'firebase-admin/auth';
import {
  TimingAction,
  TimingDecision,
  TIMING_DECISIONS,
} from '../a2ui/a2ui.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { Thread } from '../threads/entities/thread.entity';
import { CreateEventDto } from './dto/create-event.dto';
import { EditEventDto } from './dto/edit-event.dto';
import { ExtendEventDto } from './dto/extend-event.dto';
import { MoveEventDto } from './dto/move-event.dto';
import { SnoozeEventDto } from './dto/snooze-event.dto';
import { TimingDto } from './dto/timing.dto';
import { EventCard, EventEdit, EventRequest } from './entities/event.entity';
import { EventLayoutService, TimingOutcome } from './event-layout.service';
import { EventsService, SyncOutcome } from './events.service';
import { EventThreadsService } from './event-threads.service';
import { PauseTickerService } from './pause-ticker.service';

type DecodedIdToken = adminAuth.DecodedIdToken;

/**
 * The day: what is on it, and everything that changes it.
 *
 * Every route here is about a block of time, which is to say about a Google
 * event. Conversations are `/threads` and have no opinion about hours; the
 * one place the two meet is [startThread], where talking about a block
 * creates the conversation and writes its name onto the event.
 */
@Controller('events')
@UseGuards(FirebaseAuthGuard)
export class EventsController {
  constructor(
    private readonly events: EventsService,
    private readonly layout: EventLayoutService,
    private readonly threads: EventThreadsService,
    private readonly ticker: PauseTickerService,
  ) {}

  /**
   * Every card the timeline draws, earliest first.
   *
   * A paused block is caught up first, so the day read back is the one the
   * clock says rather than the one from the last tick.
   */
  @Get()
  async findAll(@CurrentUser() user: DecodedIdToken): Promise<EventCard[]> {
    const who = owner(user);
    this.ticker.watch(who);
    await this.layout.catchUp(who, Trace.start(user.uid));

    return this.events.cards(who);
  }

  /**
   * Waits for the calendar to catch up, and says whether it did.
   *
   * The app calls this after a change, off the path the finger is on. It
   * answers `{ ok: true }` the moment the queue is empty, which is almost
   * always and almost immediately; when something did not make it, it answers
   * with the popup to draw instead.
   *
   * Declared before the `:id` routes so `sync` is read as this route and not
   * as an event called "sync".
   */
  @Get('sync')
  async sync(@CurrentUser() user: DecodedIdToken): Promise<SyncOutcome> {
    return this.events.awaitSync(user.uid, Trace.start(user.uid));
  }

  /** Pushes everything that did not make it to Google again. */
  @Post('sync')
  async retrySync(@CurrentUser() user: DecodedIdToken): Promise<SyncOutcome> {
    const trace = Trace.start(user.uid);
    trace.log('sync.retry', {});

    return this.events.retrySync(user.uid, trace);
  }

  /**
   * Answers a guard.
   *
   * Its own route rather than an action on an event, because a guard is about
   * where a card goes and not about one event in particular. Nothing here
   * reaches the agent: the answer is arithmetic over the calendar, and the
   * only thing that crosses to the other container is the booking itself.
   */
  @Post('timing')
  async applyTiming(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: TimingDto,
  ): Promise<TimingOutcome> {
    const action = requireTiming(dto.action ?? {});
    const trace = Trace.start(user.uid, action.eventId);
    trace.log('timing.received', {
      index: action.index,
      decision: action.decision,
    });

    return this.layout.move(owner(user), action, trace);
  }

  /** Writes something down on the timeline, with its hour. */
  @Post()
  async create(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: CreateEventDto,
  ): Promise<EventCard[]> {
    const trace = Trace.start(user.uid);
    trace.log('turn.begin', { kind: 'event' });

    return this.layout.create(owner(user), requireEvent(dto), trace);
  }

  /** Moves a card to a new place in the day's list. */
  @Post(':id/move')
  async move(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
    @Body() dto: MoveEventDto,
  ): Promise<TimingOutcome> {
    const trace = Trace.start(user.uid, id);

    return this.layout.move(
      owner(user),
      {
        type: 'timing',
        eventId: id,
        index: requireIndex(dto.index),
        ...requireGap(dto),
      },
      trace,
    );
  }

  /**
   * The user began a block.
   *
   * What a waiting block's notification and its card both ask for. A block
   * whose hour has not come yet goes to the top of the day instead, which can
   * raise the guard, so this answers the way a move does.
   */
  @Post(':id/start')
  async start(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<TimingOutcome> {
    return this.layout.start(owner(user), id, Trace.start(user.uid, id));
  }

  /** Not yet: a waiting block waits a few minutes more before asking again. */
  @Post(':id/snooze')
  async snooze(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
    @Body() dto: SnoozeEventDto,
  ): Promise<EventCard[]> {
    const minutes = dto.minutes ?? 15;
    if (!Number.isInteger(minutes) || minutes <= 0 || minutes > 240) {
      throw new BadRequestException('minutes must be between 1 and 240');
    }

    return this.layout.snooze(
      owner(user),
      id,
      minutes,
      Trace.start(user.uid, id),
    );
  }

  /**
   * Takes a block off the day.
   *
   * Separate from the move route because it is a different question: a move
   * is when something happens, this is whether it still happens at all.
   */
  @Post(':id/done')
  async done(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<EventCard[]> {
    return this.layout.done(owner(user), id, Trace.start(user.uid, id));
  }

  /** Takes a block off the calendar, keeping nothing of it. */
  @Delete(':id')
  async remove(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<EventCard[]> {
    return this.layout.remove(owner(user), id, Trace.start(user.uid, id));
  }

  /** Pauses the running block, which then keeps its work owed. */
  @Post(':id/pause')
  async pause(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<EventCard[]> {
    const who = owner(user);
    this.ticker.watch(who);

    return this.layout.pause(who, id, Trace.start(user.uid, id));
  }

  /** Runs a paused block again. */
  @Post(':id/resume')
  async resume(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<EventCard[]> {
    return this.layout.resume(owner(user), id, Trace.start(user.uid, id));
  }

  /** Gives a block more time, pushing what comes after it. */
  @Post(':id/extend')
  async extend(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
    @Body() dto: ExtendEventDto,
  ): Promise<EventCard[]> {
    const minutes = dto.minutes;
    if (
      typeof minutes !== 'number' ||
      !Number.isInteger(minutes) ||
      minutes === 0
    ) {
      throw new BadRequestException('minutes must be a non-zero integer');
    }

    return this.layout.extend(
      owner(user),
      id,
      minutes,
      Trace.start(user.uid, id),
    );
  }

  /** Renames a block, changes its duration, or pins it to an hour. */
  @Patch(':id')
  async edit(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
    @Body() dto: EditEventDto,
  ): Promise<EventCard[]> {
    return this.layout.edit(
      owner(user),
      id,
      requireEdit(dto),
      Trace.start(user.uid, id),
    );
  }

  /**
   * The conversation about this block, started if there is not one yet.
   *
   * A block has no thread by default: most of the day is hours, not
   * discussions. Tapping into one is the moment that changes, and the event
   * is where the pairing is written down.
   */
  @Post(':id/thread')
  async startThread(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<Thread> {
    return this.threads.open(owner(user), id, Trace.start(user.uid, id));
  }
}

/** The person this request is for, and how to reach them on Google. */
function owner(user: DecodedIdToken): CalendarUser {
  const name = typeof user.name === 'string' ? user.name : undefined;
  return { id: user.uid, email: user.email, name };
}

/** A non-negative place in the day's list. */
function requireIndex(index: number | undefined): number {
  if (typeof index !== 'number' || !Number.isInteger(index) || index < 0) {
    throw new BadRequestException('index must be a non-negative integer');
  }

  return index;
}

/** The gap a drop landed in and the length it was cut to, when either. */
function requireGap(dto: MoveEventDto): { after?: string; minutes?: number } {
  const gap: { after?: string; minutes?: number } = {};

  if (dto.after !== undefined) {
    if (typeof dto.after !== 'string' || Number.isNaN(Date.parse(dto.after))) {
      throw new BadRequestException('after must be an ISO 8601 date-time');
    }
    gap.after = dto.after;
  }

  if (dto.minutes !== undefined) {
    if (!Number.isInteger(dto.minutes) || dto.minutes < 5) {
      throw new BadRequestException('minutes must be an integer of at least 5');
    }
    gap.minutes = dto.minutes;
  }

  return gap;
}

/** Reads what the creation sheet said, refusing anything unusable. */
function requireEvent(dto: CreateEventDto): EventRequest {
  const title = dto.title?.trim() ?? '';
  if (title === '') throw new BadRequestException('title is required');

  const durationMinutes = dto.durationMinutes;
  if (
    typeof durationMinutes !== 'number' ||
    !Number.isFinite(durationMinutes) ||
    durationMinutes <= 0
  ) {
    throw new BadRequestException('durationMinutes must be positive');
  }

  const fixed = dto.fixed === true;
  const startTime = dto.startTime;
  if (startTime !== undefined && Number.isNaN(Date.parse(startTime))) {
    throw new BadRequestException('startTime must be an ISO 8601 date-time');
  }
  const notBefore = dto.notBefore;
  if (notBefore !== undefined && Number.isNaN(Date.parse(notBefore))) {
    throw new BadRequestException('notBefore must be an ISO 8601 date-time');
  }

  // Only a fixed block names its hour. Carrying one on a flexible block would
  // be the app asking for a slot the server is about to pick anyway. A
  // flexible one may say where to start looking instead, which a fixed one
  // has no use for.
  return {
    title,
    durationMinutes,
    fixed,
    startTime: fixed ? startTime : undefined,
    notBefore: fixed ? undefined : notBefore,
  };
}

/** Reads what the detail screen changed, refusing anything unusable. */
function requireEdit(dto: EditEventDto): EventEdit {
  const edit: EventEdit = {};

  if (dto.title !== undefined) {
    const title = typeof dto.title === 'string' ? dto.title.trim() : '';
    if (title === '') throw new BadRequestException('title cannot be empty');
    edit.title = title;
  }

  if (dto.workMinutes !== undefined) {
    const minutes = dto.workMinutes;
    if (
      typeof minutes !== 'number' ||
      !Number.isInteger(minutes) ||
      minutes <= 0
    ) {
      throw new BadRequestException('workMinutes must be a positive integer');
    }
    edit.workMinutes = minutes;
  }

  if (dto.startTime !== undefined) {
    if (
      typeof dto.startTime !== 'string' ||
      Number.isNaN(Date.parse(dto.startTime))
    ) {
      throw new BadRequestException('startTime must be an ISO 8601 date-time');
    }
    edit.startTime = dto.startTime;
  }

  return edit;
}

/** Reads a guard's answer off the wire, refusing anything it cannot trust. */
function requireTiming(action: {
  eventId?: string;
  index?: number;
  decision?: string;
}): TimingAction {
  const eventId = action.eventId?.trim() ?? '';
  if (eventId === '') throw new BadRequestException('eventId is required');

  const decision = action.decision;
  if (
    decision !== undefined &&
    !TIMING_DECISIONS.includes(decision as TimingDecision)
  ) {
    throw new BadRequestException(`Unknown decision "${decision}"`);
  }

  return {
    type: 'timing',
    eventId,
    index: requireIndex(action.index ?? 0),
    decision: decision as TimingDecision | undefined,
  };
}
