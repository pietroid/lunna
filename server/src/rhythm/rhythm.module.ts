import { Module } from '@nestjs/common';
import { RhythmController } from './rhythm.controller';
import { RhythmService } from './rhythm.service';
import { RhythmStoreModule } from './rhythm-store.module';

/** Ciclo and Folgas: the routes under `/api/rhythm`, and their rules. */
@Module({
  imports: [RhythmStoreModule],
  controllers: [RhythmController],
  providers: [RhythmService],
  exports: [RhythmService],
})
export class RhythmModule {}
