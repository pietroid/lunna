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
import { CalendarUser, routineDaysOf } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { RoutineDto } from './dto/routine.dto';
import { Routine, RoutineRequest } from './entities/routine.entity';
import { parseTime } from './routine-dates';
import { RoutinesService } from './routines.service';

type DecodedIdToken = adminAuth.DecodedIdToken;

/** The longest a routine may be: the whole working day. */
const MAX_ROUTINE_MINUTES = 15 * 60;

/**
 * The routines menu: what happens every day, and on which days.
 *
 * Every route answers with the whole list, because the menu draws the whole
 * day and a routine moved at noon can change what the afternoon looks like.
 */
@Controller('routines')
@UseGuards(FirebaseAuthGuard)
export class RoutinesController {
  constructor(private readonly routines: RoutinesService) {}

  @Get()
  async findAll(@CurrentUser() user: DecodedIdToken): Promise<Routine[]> {
    return this.routines.list(owner(user), Trace.start(user.uid));
  }

  @Post()
  async create(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: RoutineDto,
  ): Promise<Routine[]> {
    const request = readRoutine(dto);
    if (
      request.title === undefined ||
      request.time === undefined ||
      request.durationMinutes === undefined ||
      request.days === undefined
    ) {
      throw new BadRequestException(
        'title, time, durationMinutes and days are required',
      );
    }

    return this.routines.create(
      owner(user),
      {
        title: request.title,
        time: request.time,
        durationMinutes: request.durationMinutes,
        days: request.days,
      },
      Trace.start(user.uid),
    );
  }

  @Patch(':id')
  async update(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
    @Body() dto: RoutineDto,
  ): Promise<Routine[]> {
    return this.routines.update(
      owner(user),
      id,
      readRoutine(dto),
      Trace.start(user.uid, id),
    );
  }

  @Delete(':id')
  async remove(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') id: string,
  ): Promise<Routine[]> {
    return this.routines.remove(owner(user), id, Trace.start(user.uid, id));
  }
}

function owner(user: DecodedIdToken): CalendarUser {
  const name = typeof user.name === 'string' ? user.name : undefined;
  return { id: user.uid, email: user.email, name };
}

/** Reads what the menu sent, refusing anything unusable. */
function readRoutine(dto: RoutineDto): RoutineRequest {
  const request: RoutineRequest = {};

  if (dto.title !== undefined) {
    const title = typeof dto.title === 'string' ? dto.title.trim() : '';
    if (title === '') throw new BadRequestException('title cannot be empty');
    request.title = title;
  }

  if (dto.time !== undefined) {
    const time = typeof dto.time === 'string' ? parseTime(dto.time) : undefined;
    if (time === undefined) throw new BadRequestException('time must be HH:MM');
    request.time = `${pad(time.hour)}:${pad(time.minute)}`;
  }

  if (dto.durationMinutes !== undefined) {
    const minutes = dto.durationMinutes;
    if (
      !Number.isInteger(minutes) ||
      minutes < 5 ||
      minutes > MAX_ROUTINE_MINUTES
    ) {
      throw new BadRequestException('durationMinutes is out of range');
    }
    request.durationMinutes = minutes;
  }

  if (dto.days !== undefined) {
    const days = routineDaysOf(dto.days);
    if (days === undefined) {
      throw new BadRequestException('days must be daily, weekdays or weekend');
    }
    request.days = days;
  }

  return request;
}

function pad(value: number): string {
  return String(value).padStart(2, '0');
}
