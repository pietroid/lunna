import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import * as adminAuth from 'firebase-admin/auth';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { MoveThingDto, ThingDto } from './dto/thing.dto';
import { ScheduledThing, Thing } from './entities/thing.entity';
import { ThingsService } from './things.service';

type DecodedIdToken = adminAuth.DecodedIdToken;

/**
 * Coisas: the list of what has no hour yet.
 *
 * Every route answers with the whole list, so the app never has to work out
 * what a change did to the order.
 */
@Controller('things')
@UseGuards(FirebaseAuthGuard)
export class ThingsController {
  constructor(private readonly things: ThingsService) {}

  @Get()
  findAll(@CurrentUser() user: DecodedIdToken): Promise<Thing[]> {
    return this.things.list(owner(user));
  }

  @Post()
  create(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: ThingDto,
  ): Promise<Thing[]> {
    const changes = readThing(dto);
    if (changes.title === undefined) {
      throw new BadRequestException('title is required');
    }

    return this.things.add(owner(user), {
      title: changes.title,
      durationMinutes: changes.durationMinutes ?? 30,
    });
  }

  @Patch(':id')
  edit(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
    @Body() dto: ThingDto,
  ): Promise<Thing[]> {
    return this.things.edit(owner(user), id, readThing(dto));
  }

  @Post(':id/move')
  move(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
    @Body() dto: MoveThingDto,
  ): Promise<Thing[]> {
    const index = dto.index;
    if (typeof index !== 'number' || !Number.isInteger(index) || index < 0) {
      throw new BadRequestException('index must be a non-negative integer');
    }

    return this.things.move(owner(user), id, index);
  }

  /** Done. Same as a delete today; kept apart because it means something else. */
  @Post(':id/done')
  done(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<Thing[]> {
    return this.things.remove(owner(user), id);
  }

  @Delete(':id')
  remove(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<Thing[]> {
    return this.things.remove(owner(user), id);
  }

  /** Moves a thing onto the timeline, in the first gap that fits it. */
  @Post(':id/schedule')
  schedule(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<ScheduledThing> {
    return this.things.schedule(owner(user), id, Trace.start(user.uid, id));
  }
}

function owner(user: DecodedIdToken): CalendarUser {
  const name = typeof user.name === 'string' ? user.name : undefined;
  return { id: user.uid, email: user.email, name };
}

/** Reads a thing off the wire, refusing anything unusable. */
function readThing(dto: ThingDto): {
  title?: string;
  durationMinutes?: number;
} {
  const changes: { title?: string; durationMinutes?: number } = {};

  if (dto.title !== undefined) {
    const title = typeof dto.title === 'string' ? dto.title.trim() : '';
    if (title === '') throw new BadRequestException('title cannot be empty');
    changes.title = title;
  }

  if (dto.durationMinutes !== undefined) {
    const minutes = dto.durationMinutes;
    if (!Number.isInteger(minutes) || minutes <= 0) {
      throw new BadRequestException(
        'durationMinutes must be a positive integer',
      );
    }
    changes.durationMinutes = minutes;
  }

  return changes;
}
