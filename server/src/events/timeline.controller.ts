import {
  Controller,
  Get,
  Query,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { CatchUpInterceptor } from './catch-up.interceptor';
import { Timeline } from './entities/event.entity';
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
@UseInterceptors(CatchUpInterceptor)
export class TimelineController {
  constructor(private readonly timeline: TimelineService) {}

  /**
   * Every task, and everything the calendar draws for [days] days counting
   * today.
   *
   * A paused block is caught up first ([CatchUpInterceptor]), so the day
   * read back is the one the clock says.
   */
  @Get()
  async read(
    @CurrentUser() user: AuthUser,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    return this.timeline.view(
      await this.timeline.day(owner(user), daysOf(days)),
    );
  }
}
