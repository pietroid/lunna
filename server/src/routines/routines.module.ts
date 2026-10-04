import { Module } from '@nestjs/common';
import { CalendarModule } from '../calendar/calendar.module';
import { RoutinesController } from './routines.controller';
import { RoutinesService } from './routines.service';

/**
 * Routines, written from the menu.
 *
 * Kept by the calendar, which expands each one into its days as the timeline
 * reaches them.
 */
@Module({
  imports: [CalendarModule],
  controllers: [RoutinesController],
  providers: [RoutinesService],
})
export class RoutinesModule {}
