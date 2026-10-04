import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CalendarService } from './calendar.service';
import { CalendarStore } from './calendar.store';
import { PgCalendarStore } from './pg-calendar.store';

/**
 * The calendar: Lunna's own, in Postgres.
 *
 * No controller. The timeline and the routines are the two ways in, and both
 * go through [CalendarService].
 */
@Module({
  imports: [ConfigModule],
  providers: [
    CalendarService,
    { provide: CalendarStore, useClass: PgCalendarStore },
  ],
  exports: [CalendarService],
})
export class CalendarModule {}
