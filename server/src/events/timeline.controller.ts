import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { Trace } from '../common/trace';
import { Timeline } from './entities/event.entity';
import { EventLayoutService } from './event-layout.service';
import { PauseTickerService } from './pause-ticker.service';
import { daysOf, owner } from './request';
import { TimelineService } from './timeline.service';

/**
 * The day, read: the list of tasks and the calendar, from one read.
 *
 * Every route that changes the day answers with the same thing, for the
 * same number of days, so the screen never has to ask twice.
 */
@Controller('timeline')
@UseGuards(SessionGuard)
export class TimelineController {
  constructor(
    private readonly timeline: TimelineService,
    private readonly layout: EventLayoutService,
    private readonly ticker: PauseTickerService,
  ) {}

  /**
   * Every task, and everything the calendar draws for [days] days counting
   * today.
   *
   * A paused block is caught up first, so the day read back is the one the
   * clock says rather than the one from the last tick.
   */
  @Get()
  async read(
    @CurrentUser() user: AuthUser,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    const who = owner(user);
    this.ticker.watch(who);
    await this.layout.catchUp(who, Trace.start(user.id));

    return this.timeline.view(await this.timeline.day(who, daysOf(days)));
  }
}
