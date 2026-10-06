import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CalendarModule } from '../calendar/calendar.module';
import { TasksModule } from '../tasks/tasks.module';
import { EventLayoutService } from './event-layout.service';
import { EventsController } from './events.controller';
import { PauseTickerService } from './pause-ticker.service';
import { TasksController } from './tasks.controller';
import { TimelineController } from './timeline.controller';
import { TimelineService } from './timeline.service';

/** The day: the tasks, the events, and where the one falls among the other. */
@Module({
  imports: [ConfigModule, CalendarModule, TasksModule],
  controllers: [TimelineController, EventsController, TasksController],
  providers: [TimelineService, EventLayoutService, PauseTickerService],
  exports: [TimelineService, EventLayoutService],
})
export class EventsModule {}
