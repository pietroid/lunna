import { Module } from '@nestjs/common';
import { CalendarModule } from '../calendar/calendar.module';
import { TasksModule } from '../tasks/tasks.module';
import { RoutinesController } from './routines.controller';
import { RoutinesService } from './routines.service';

/**
 * Routines, written from the menu.
 *
 * Kept by the calendar. A fixed routine's days are events the calendar writes
 * as the timeline reaches them; a flexible one's are tasks the timeline
 * writes.
 */
@Module({
  imports: [CalendarModule, TasksModule],
  controllers: [RoutinesController],
  providers: [RoutinesService],
})
export class RoutinesModule {}
