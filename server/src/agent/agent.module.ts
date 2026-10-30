import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CalendarModule } from '../calendar/calendar.module';
import { EventsModule } from '../events/events.module';
import { ArtifactStoreModule } from '../artifacts/artifact-store.module';
import { TasksModule } from '../tasks/tasks.module';
import { RhythmModule } from '../rhythm/rhythm.module';
import { UsersModule } from '../users/users.module';
import { AgentController } from './agent.controller';
import { AgentService } from './agent.service';
import { ConversationStore } from './conversation.store';
import { PgConversationStore } from './pg-conversation.store';
import { OpenRouterClient } from './openrouter.client';
import { PlanStore } from './plan';
import { PgPlanStore } from './pg-plan.store';
import { PgSuggestionStore } from './pg-suggestion.store';
import { SuggestionStore } from './suggestion.store';
import { SuggestionTimer } from './suggestion.timer';

/** Lunna, the agent: reads the day, proposes changes, applies them. */
@Module({
  imports: [
    ConfigModule,
    CalendarModule,
    EventsModule,
    TasksModule,
    ArtifactStoreModule,
    UsersModule,
    RhythmModule,
  ],
  controllers: [AgentController],
  providers: [
    AgentService,
    OpenRouterClient,
    { provide: ConversationStore, useClass: PgConversationStore },
    { provide: PlanStore, useClass: PgPlanStore },
    { provide: SuggestionStore, useClass: PgSuggestionStore },
    SuggestionTimer,
  ],
  exports: [SuggestionStore],
})
export class AgentModule {}
