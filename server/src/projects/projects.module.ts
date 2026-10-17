import { Module } from '@nestjs/common';
import { EventsModule } from '../events/events.module';
import { TasksModule } from '../tasks/tasks.module';
import { ProjectStoreModule } from './project-store.module';
import { ProjectsController } from './projects.controller';
import { ProjectsService } from './projects.service';

/** The projects, and the tasks they hold. */
@Module({
  imports: [EventsModule, TasksModule, ProjectStoreModule],
  controllers: [ProjectsController],
  providers: [ProjectsService],
})
export class ProjectsModule {}
