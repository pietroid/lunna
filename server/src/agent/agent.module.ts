import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CalendarModule } from '../calendar/calendar.module';
import { EventsModule } from '../events/events.module';
import { ProjectStoreModule } from '../projects/project-store.module';
import { TasksModule } from '../tasks/tasks.module';
import { AgentController } from './agent.controller';
import { AgentService } from './agent.service';
import { ConversationStore } from './conversation.store';
import { PgConversationStore } from './pg-conversation.store';
import { OpenRouterClient } from './openrouter.client';

/** Lunna, the agent: reads the day, proposes changes, applies them. */
@Module({
  imports: [
    ConfigModule,
    CalendarModule,
    EventsModule,
    TasksModule,
    ProjectStoreModule,
  ],
  controllers: [AgentController],
  providers: [
    AgentService,
    OpenRouterClient,
    { provide: ConversationStore, useClass: PgConversationStore },
  ],
})
export class AgentModule {}
