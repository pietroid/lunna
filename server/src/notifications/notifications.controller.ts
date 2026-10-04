import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import * as adminAuth from 'firebase-admin/auth';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { NotificationPlan } from './dto/notification-plan.dto';
import {
  DEFAULT_HORIZON_DAYS,
  MAX_HORIZON_DAYS,
  NotificationsService,
} from './notifications.service';

type DecodedIdToken = adminAuth.DecodedIdToken;

/**
 * The reminders the phone should be holding.
 *
 * The server says when to fire and what to say. The phone mirrors the list
 * into its own notification queue, which is what lets a reminder arrive with
 * no network and no push entitlement.
 */
@Controller('notifications')
@UseGuards(FirebaseAuthGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get('schedule')
  async schedule(
    @CurrentUser() user: DecodedIdToken,
    @Query('horizonDays') horizonDays?: string,
  ): Promise<NotificationPlan> {
    const name = typeof user.name === 'string' ? user.name : undefined;

    return this.notifications.plan(
      { id: user.uid, email: user.email, name },
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
