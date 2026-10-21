import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CalendarModule } from '../calendar/calendar.module';
import { EventsModule } from '../events/events.module';
import { ArtifactStoreModule } from '../artifacts/artifact-store.module';
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
    ArtifactStoreModule,
  ],
  controllers: [AgentController],
  providers: [
    AgentService,
    OpenRouterClient,
    { provide: ConversationStore, useClass: PgConversationStore },
  ],
})
export class AgentModule {}
