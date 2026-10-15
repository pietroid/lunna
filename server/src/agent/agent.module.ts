import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CalendarModule } from '../calendar/calendar.module';
import { EventsModule } from '../events/events.module';
import { TasksModule } from '../tasks/tasks.module';
import { AgentController } from './agent.controller';
import { AgentService } from './agent.service';
import { OpenRouterClient } from './openrouter.client';

/** Lunna, the agent: reads the day, proposes changes, applies them. */
@Module({
  imports: [ConfigModule, CalendarModule, EventsModule, TasksModule],
  controllers: [AgentController],
  providers: [AgentService, OpenRouterClient],
})
export class AgentModule {}
