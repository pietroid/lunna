import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { CreateEventDto } from './dto/create-event.dto';
import { EditEventDto } from './dto/edit-event.dto';
import { ExtendEventDto } from './dto/extend-event.dto';
import { MoveEventDto } from './dto/move-event.dto';
import { SnoozeEventDto } from './dto/snooze-event.dto';
import { TimingDto } from './dto/timing.dto';
import { EventCard, EventEdit, EventRequest } from './entities/event.entity';
import { EventLayoutService, TimingOutcome } from './event-layout.service';
import { EventsService } from './events.service';
import { PauseTickerService } from './pause-ticker.service';
import { TimingAction, TimingDecision, TIMING_DECISIONS } from './timing';

/**
 * The day: what is on it, and everything that changes it.
 *
 * Every route here is about a block of time, which is to say about one event
 * on the calendar.
 */
@Controller('events')
@UseGuards(SessionGuard)
export class EventsController {
  constructor(
    private readonly events: EventsService,
    private readonly layout: EventLayoutService,
    private readonly ticker: PauseTickerService,
  ) {}

  /**
   * Every card the timeline draws, earliest first.
   *
   * A paused block is caught up first, so the day read back is the one the
   * clock says rather than the one from the last tick.
   */
  @Get()
  async findAll(@CurrentUser() user: AuthUser): Promise<EventCard[]> {
    const who = owner(user);
    this.ticker.watch(who);
    await this.layout.catchUp(who, Trace.start(user.id));

    return this.events.cards(who);
  }

  /** One block, for its own screen. */
  @Get(':id')
  async findOne(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<EventCard> {
    const card = (await this.events.cards(owner(user))).find(
      (it) => it.id === id,
    );
    if (card === undefined) throw new NotFoundException(`No event "${id}"`);

    return card;
  }

  /**
   * Answers a guard.
   *
   * Its own route rather than an action on an event, because a guard is about
   * where a card goes and not about one event in particular.
   */
  @Post('timing')
  async applyTiming(
    @CurrentUser() user: AuthUser,
    @Body() dto: TimingDto,
  ): Promise<TimingOutcome> {
    const action = requireTiming(dto.action ?? {});
    const trace = Trace.start(user.id, action.eventId);
    trace.log('timing.received', {
      index: action.index,
      decision: action.decision,
    });

    return this.layout.move(owner(user), action, trace);
  }

  /** Writes something down on the timeline, with its hour. */
  @Post()
  async create(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateEventDto,
  ): Promise<EventCard[]> {
    const trace = Trace.start(user.id);
    trace.log('turn.begin', { kind: 'event' });

    return this.layout.create(owner(user), requireEvent(dto), trace);
  }

  /** Moves a card to a new place in the day's list. */
  @Post(':id/move')
  async move(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: MoveEventDto,
  ): Promise<TimingOutcome> {
    const trace = Trace.start(user.id, id);

    return this.layout.move(
      owner(user),
      {
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
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<TimingOutcome> {
    return this.layout.start(owner(user), id, Trace.start(user.id, id));
  }

  /** Not yet: a waiting block waits a few minutes more before asking again. */
  @Post(':id/snooze')
  async snooze(
    @CurrentUser() user: AuthUser,
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
      Trace.start(user.id, id),
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
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<EventCard[]> {
    return this.layout.done(owner(user), id, Trace.start(user.id, id));
  }

  /** Takes a block off the calendar, keeping nothing of it. */
  @Delete(':id')
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<EventCard[]> {
    return this.layout.remove(owner(user), id, Trace.start(user.id, id));
  }

  /** Pauses the running block, which then keeps its work owed. */
  @Post(':id/pause')
  async pause(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<EventCard[]> {
    const who = owner(user);
    this.ticker.watch(who);

    return this.layout.pause(who, id, Trace.start(user.id, id));
  }

  /** Runs a paused block again. */
  @Post(':id/resume')
  async resume(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<EventCard[]> {
    return this.layout.resume(owner(user), id, Trace.start(user.id, id));
  }

  /** Gives a block more time, pushing what comes after it. */
  @Post(':id/extend')
  async extend(
    @CurrentUser() user: AuthUser,
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
      Trace.start(user.id, id),
    );
  }

  /** Renames a block, edits its notes, changes its duration, or pins it. */
  @Patch(':id')
  async edit(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: EditEventDto,
  ): Promise<EventCard[]> {
    return this.layout.edit(
      owner(user),
      id,
      requireEdit(dto),
      Trace.start(user.id, id),
    );
  }
}

/** The person this request is for, and the zone their day is in. */
function owner(user: AuthUser): CalendarUser {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    timeZone: user.timeZone,
  };
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

  if (dto.notes !== undefined) {
    if (typeof dto.notes !== 'string' || dto.notes.length > 20_000) {
      throw new BadRequestException('notes must be a string of at most 20000');
    }
    edit.notes = dto.notes;
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
    eventId,
    index: requireIndex(action.index ?? 0),
    decision: decision as TimingDecision | undefined,
  };
}
