import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthUser } from '../auth/auth.tokens';
import { SessionGuard } from '../auth/session.guard';
import { NotificationPlan } from './dto/notification-plan.dto';
import {
  DEFAULT_HORIZON_DAYS,
  MAX_HORIZON_DAYS,
  NotificationsService,
} from './notifications.service';

/**
 * The reminders the phone should be holding.
 *
 * The server says when to fire and what to say. The phone mirrors the list
 * into its own notification queue, which is what lets a reminder arrive with
 * no network and no push entitlement.
 */
@Controller('notifications')
@UseGuards(SessionGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get('schedule')
  async schedule(
    @CurrentUser() user: AuthUser,
    @Query('horizonDays') horizonDays?: string,
  ): Promise<NotificationPlan> {
    return this.notifications.plan(
      {
        id: user.id,
        email: user.email,
        name: user.name,
        timeZone: user.timeZone,
      },
      horizonOf(horizonDays),
    );
  }
}

/** The horizon asked for, defaulted when absent or unreadable and capped. */
function horizonOf(raw: string | undefined): number {
  const days = raw === undefined ? NaN : Number(raw);
  if (!Number.isInteger(days) || days < 1) return DEFAULT_HORIZON_DAYS;

  return Math.min(days, MAX_HORIZON_DAYS);
}
