import { Module } from '@nestjs/common';
import { PgTaskStore } from './pg-task.store';
import { TaskStore } from './task.store';

/**
 * Where the tasks are kept.
 *
 * No controller. The tasks are only ever read and changed as part of the
 * day, which is the events module's.
 */
@Module({
  providers: [{ provide: TaskStore, useClass: PgTaskStore }],
  exports: [TaskStore],
})
export class TasksModule {}
