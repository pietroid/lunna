import { Module } from '@nestjs/common';
import { PgArtifactStore } from './pg-artifact.store';
import { ArtifactStore } from './artifact.store';

/**
 * Where the artifacts are kept.
 *
 * Its own module, as the tasks' is, because the day needs it too: a task
 * written down on the day may say which artifact it belongs to.
 */
@Module({
  providers: [{ provide: ArtifactStore, useClass: PgArtifactStore }],
  exports: [ArtifactStore],
})
export class ArtifactStoreModule {}
