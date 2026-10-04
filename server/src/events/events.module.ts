import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CalendarModule } from '../calendar/calendar.module';
import { EventLayoutService } from './event-layout.service';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';
import { PauseTickerService } from './pause-ticker.service';

/** The day. */
@Module({
  imports: [ConfigModule, CalendarModule],
  controllers: [EventsController],
  providers: [EventsService, EventLayoutService, PauseTickerService],
  exports: [EventsService, EventLayoutService],
})
export class EventsModule {}
