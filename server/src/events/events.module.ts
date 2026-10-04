import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { A2uiModule } from '../a2ui/a2ui.module';
import { AuthModule } from '../auth/auth.module';
import { CalendarModule } from '../calendar/calendar.module';
import { ThreadsModule } from '../threads/threads.module';
import { EventLayoutService } from './event-layout.service';
import { EventThreadsService } from './event-threads.service';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';
import { PauseTickerService } from './pause-ticker.service';

/**
 * The day.
 *
 * Depends on threads, and not the other way round: a card can say which
 * conversation belongs to it, while a conversation has no idea whether it has
 * an hour. That direction is the whole separation.
 */
@Module({
  imports: [
    ConfigModule,
    AuthModule,
    A2uiModule,
    CalendarModule,
    ThreadsModule,
  ],
  controllers: [EventsController],
  providers: [
    EventsService,
    EventLayoutService,
    EventThreadsService,
    PauseTickerService,
  ],
  exports: [EventsService, EventLayoutService],
})
export class EventsModule {}
