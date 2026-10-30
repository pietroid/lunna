import { Module } from '@nestjs/common';
import { AgentModule } from '../agent/agent.module';
import { EventsModule } from '../events/events.module';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

/**
 * Reminders, derived from the calendar.
 *
 * No storage of its own. The schedule is worked out from the day on every
 * ask, so there is nothing here that can disagree with the timeline.
 */
@Module({
  imports: [EventsModule, AgentModule],
  controllers: [NotificationsController],
  providers: [NotificationsService],
})
export class NotificationsModule {}
