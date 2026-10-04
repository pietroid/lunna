import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { EventsModule } from '../events/events.module';
import { ThingsController } from './things.controller';
import { ThingsService } from './things.service';
import { ThingsStore } from './things.store';

/**
 * Coisas: what has no hour yet.
 *
 * Depends on events for the one move that gives a thing an hour, and on
 * nothing else. The events module knows nothing about it.
 */
@Module({
  imports: [AuthModule, EventsModule],
  controllers: [ThingsController],
  providers: [ThingsService, ThingsStore],
})
export class ThingsModule {}
