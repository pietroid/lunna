import { Module } from '@nestjs/common';
import { PgProjectStore } from './pg-project.store';
import { ProjectStore } from './project.store';

/**
 * Where the projects are kept.
 *
 * Its own module, as the tasks' is, because the day needs it too: a task
 * written down on the day may say which project it belongs to.
 */
@Module({
  providers: [{ provide: ProjectStore, useClass: PgProjectStore }],
  exports: [ProjectStore],
})
export class ProjectStoreModule {}
