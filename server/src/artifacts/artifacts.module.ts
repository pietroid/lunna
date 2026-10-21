import { Module } from '@nestjs/common';
import { EventsModule } from '../events/events.module';
import { TasksModule } from '../tasks/tasks.module';
import { ArtifactStoreModule } from './artifact-store.module';
import { ArtifactsController } from './artifacts.controller';
import { ArtifactsService } from './artifacts.service';

/** The artifacts, and the tasks they hold. */
@Module({
  imports: [EventsModule, TasksModule, ArtifactStoreModule],
  controllers: [ArtifactsController],
  providers: [ArtifactsService],
})
export class ArtifactsModule {}
