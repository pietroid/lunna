import { Module } from '@nestjs/common';
import { PgRhythmStore } from './pg-rhythm.store';
import { RhythmStore } from './rhythm.store';

/**
 * Where the rhythm is kept.
 *
 * Its own module, as the tasks' is, because the day needs it too: the
 * queue reads the kind of every date it lays a task on.
 */
@Module({
  providers: [{ provide: RhythmStore, useClass: PgRhythmStore }],
  exports: [RhythmStore],
})
export class RhythmStoreModule {}
