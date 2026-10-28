import {
  Body,
  Controller,
  Delete,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { Trace } from '../common/trace';
import { CatchUpInterceptor } from './catch-up.interceptor';
import { CreateEventDto } from './dto/create-event.dto';
import { EditEventDto } from './dto/edit-event.dto';
import { ExtendEventDto } from './dto/extend-event.dto';
import { SnoozeEventDto } from './dto/snooze-event.dto';
import { Timeline } from './entities/event.entity';
import { EventLayoutService } from './event-layout.service';
import {
  daysOf,
  owner,
  requireDelta,
  requireLength,
  requireEvent,
  requireEventEdit,
  requireSnooze,
} from './request';
import { TimelineService } from './timeline.service';

/**
 * The blocks whose hour is the point of them: fixed blocks and the days of
 * routines.
 *
 * Every route answers with the whole timeline, for the [days] the screen is
 * drawing, because an event that moves is an obstacle the tasks around it
 * flow around again.
 */
@Controller('events')
@UseGuards(SessionGuard)
@UseInterceptors(CatchUpInterceptor)
export class EventsController {
  constructor(
    private readonly timeline: TimelineService,
    private readonly layout: EventLayoutService,
  ) {}

  /** Writes a fixed block down at its hour. */
  @Post()
  async create(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateEventDto,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    const trace = Trace.start(user.id);
    await this.layout.createEvent(owner(user), requireEvent(dto), trace);

    return this._answer(user, days);
  }

  /** Renames a block, edits its notes, changes its length or its hour. */
  @Patch(':id')
  async edit(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: EditEventDto,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.editEvent(
      owner(user),
      id,
      requireEventEdit(dto),
      Trace.start(user.id, id),
    );

    return this._answer(user, days);
  }

  /** Marks a block done: a running one keeps the hour it really took. */
  @Post(':id/done')
  async done(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.doneEvent(owner(user), id, Trace.start(user.id, id));

    return this._answer(user, days);
  }

  /** The person said a fixed block began: its reminders stop asking. */
  @Post(':id/start')
  async start(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.startEvent(owner(user), id, Trace.start(user.id, id));

    return this._answer(user, days);
  }

  /**
   * Not yet: a fixed block whose start nobody answered starts [minutes]
   * (ten unless said) after the later of its hour and now.
   */
  @Post(':id/delay')
  async delay(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: SnoozeEventDto,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.delayEvent(
      owner(user),
      id,
      requireSnooze(dto.minutes),
      Trace.start(user.id, id),
    );

    return this._answer(user, days);
  }

  /** Takes a block off the calendar, keeping nothing of it. */
  @Delete(':id')
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.removeEvent(owner(user), id, Trace.start(user.id, id));

    return this._answer(user, days);
  }

  /** Pauses the running block, which then keeps its work owed. */
  @Post(':id/pause')
  async pause(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.pauseEvent(owner(user), id, Trace.start(user.id, id));

    return this._answer(user, days);
  }

  /** Runs a paused block again. */
  @Post(':id/resume')
  async resume(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.resumeEvent(owner(user), id, Trace.start(user.id, id));

    return this._answer(user, days);
  }

  /** Gives a block more time, or less. */
  @Post(':id/extend')
  async extend(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ExtendEventDto,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.extendEvent(
      owner(user),
      id,
      requireDelta(dto.minutes),
      Trace.start(user.id, id),
    );

    return this._answer(user, days);
  }

  /**
   * Gives a block a new length by its edge, and slides the run snapped to
   * its end by as much.
   */
  @Post(':id/resize')
  async resize(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ExtendEventDto,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.resizeEvent(
      owner(user),
      id,
      requireLength(dto.minutes),
      Trace.start(user.id, id),
    );

    return this._answer(user, days);
  }

  private async _answer(user: AuthUser, days?: string): Promise<Timeline> {
    return this.timeline.view(
      await this.timeline.day(owner(user), daysOf(days)),
    );
  }
}
