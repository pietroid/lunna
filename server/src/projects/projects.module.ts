import { Module } from '@nestjs/common';
import { EventsModule } from '../events/events.module';
import { TasksModule } from '../tasks/tasks.module';
import { PgProjectStore } from './pg-project.store';
import { ProjectStore } from './project.store';
import { ProjectsController } from './projects.controller';
import { ProjectsService } from './projects.service';

/** The projects, and the tasks they hold. */
@Module({
  imports: [EventsModule, TasksModule],
  controllers: [ProjectsController],
  providers: [
    ProjectsService,
    { provide: ProjectStore, useClass: PgProjectStore },
  ],
})
export class ProjectsModule {}
