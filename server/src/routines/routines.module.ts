import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CalendarModule } from '../calendar/calendar.module';
import { RoutinesController } from './routines.controller';
import { RoutinesService } from './routines.service';

/**
 * Routines: recurring events, written from the menu.
 *
 * No storage of its own. Google holds the series and repeats it, and the
 * timeline picks the instances up as fixed blocks like any other.
 */
@Module({
  imports: [AuthModule, CalendarModule],
  controllers: [RoutinesController],
  providers: [RoutinesService],
})
export class RoutinesModule {}
