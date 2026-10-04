import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CalendarReaderService } from './calendar-reader.service';
import { CalendarSyncService } from './calendar-sync.service';
import { CalendarWriterService } from './calendar-writer.service';

/**
 * Everything the server knows about the calendar, which is what the agent
 * tells it when asked.
 *
 * No controller. Nothing calls in from outside about the calendar: the server
 * asks the agent, in the same direction as every other call between the two.
 */
@Module({
  imports: [ConfigModule],
  providers: [
    CalendarReaderService,
    CalendarSyncService,
    CalendarWriterService,
  ],
  exports: [CalendarReaderService, CalendarSyncService, CalendarWriterService],
})
export class CalendarModule {}
