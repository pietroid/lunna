import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { A2uiModule } from '../a2ui/a2ui.module';
import { AuthModule } from '../auth/auth.module';
import { CalendarModule } from '../calendar/calendar.module';
import { AgentService } from './agent.service';
import { ThreadsController } from './threads.controller';
import { ThreadsService } from './threads.service';
import { ThreadsStore } from './threads.store';

/**
 * Conversations, and almost nothing about the clock.
 *
 * It reads the calendar for one thing only: the zone to write the prompt's
 * "now" line in. A thread still has no hour to keep in step with the day, and
 * the module that draws the day is still the only one that gives it one.
 */
@Module({
  imports: [ConfigModule, AuthModule, A2uiModule, CalendarModule],
  controllers: [ThreadsController],
  providers: [ThreadsService, ThreadsStore, AgentService],
  exports: [ThreadsService, ThreadsStore],
})
export class ThreadsModule {}
