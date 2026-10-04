import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CalendarModule } from '../calendar/calendar.module';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

/**
 * Reminders, derived from the calendar.
 *
 * No storage of its own. The schedule is worked out from the day on every
 * ask, so there is nothing here that can disagree with the calendar.
 */
@Module({
  imports: [AuthModule, CalendarModule],
  controllers: [NotificationsController],
  providers: [NotificationsService],
})
export class NotificationsModule {}
