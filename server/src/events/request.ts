import { BadRequestException } from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CalendarUser } from '../calendar/calendar.types';
import { CreateEventDto } from './dto/create-event.dto';
import { CreateTaskDto } from './dto/create-task.dto';
import { EditEventDto } from './dto/edit-event.dto';
import { MoveEventDto } from './dto/move-event.dto';
import {
  EventEdit,
  EventRequest,
  TaskEdit,
  TaskRequest,
} from './entities/event.entity';
import { DEFAULT_DAYS, MAX_DAYS } from './timeline.service';
import { TimingAction, TimingDecision, TIMING_DECISIONS } from './timing';

/**
 * Reading what the app sent, for every route about the day.
 *
 * Everything here refuses rather than guesses: a request that cannot be
 * trusted is a 400 with a reason, never a change to the day.
 */

/** The person this request is for, and the zone their day is in. */
export function owner(user: AuthUser): CalendarUser {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    timeZone: user.timeZone,
  };
}

/** How many days the calendar should draw, defaulted and capped. */
export function daysOf(raw: string | undefined): number {
  const days = raw === undefined ? NaN : Number(raw);
  if (!Number.isInteger(days) || days < 1) return DEFAULT_DAYS;

  return Math.min(days, MAX_DAYS);
}

/** A non-negative place in the list. */
export function requireIndex(index: number | undefined): number {
  if (typeof index !== 'number' || !Number.isInteger(index) || index < 0) {
    throw new BadRequestException('index must be a non-negative integer');
  }

  return index;
}

/** A drop, refusing anything unusable. */
export function requireMove(taskId: string, dto: MoveEventDto): TimingAction {
  const action: TimingAction = {
    taskId,
    index: requireIndex(dto.index),
    start: dto.start === true,
  };

  if (dto.after !== undefined) {
    if (typeof dto.after !== 'string' || Number.isNaN(Date.parse(dto.after))) {
      throw new BadRequestException('after must be an ISO 8601 date-time');
    }
    action.after = dto.after;
  }

  if (dto.minutes !== undefined) {
    if (!Number.isInteger(dto.minutes) || dto.minutes < 5) {
      throw new BadRequestException('minutes must be an integer of at least 5');
    }
    action.minutes = dto.minutes;
  }

  return action;
}

/** Reads a guard's answer off the wire, refusing anything it cannot trust. */
export function requireTiming(action: {
  taskId?: string;
  index?: number;
  decision?: string;
}): TimingAction {
  const taskId = action.taskId?.trim() ?? '';
  if (taskId === '') throw new BadRequestException('taskId is required');

  const decision = action.decision;
  if (
    decision !== undefined &&
    !TIMING_DECISIONS.includes(decision as TimingDecision)
  ) {
    throw new BadRequestException(`Unknown decision "${decision}"`);
  }

  // A guard is only ever raised by a drop at the top, so its answer is one.
  return {
    taskId,
    index: requireIndex(action.index ?? 0),
    start: true,
    decision: decision as TimingDecision | undefined,
  };
}

/** Reads a fixed block the creation sheet wrote down. */
export function requireEvent(dto: CreateEventDto): EventRequest {
  const title = requireTitle(dto.title);
  const durationMinutes = requireMinutes(
    dto.durationMinutes,
    'durationMinutes',
  );

  const startTime = dto.startTime;
  if (typeof startTime !== 'string' || Number.isNaN(Date.parse(startTime))) {
    throw new BadRequestException('startTime must be an ISO 8601 date-time');
  }

  return { title, durationMinutes, startTime };
}

/** Reads a task the creation sheet wrote down. */
export function requireTask(dto: CreateTaskDto): TaskRequest {
  const title = requireTitle(dto.title);
  const minutes = requireMinutes(dto.minutes, 'minutes');

  const notBefore = dto.notBefore;
  if (notBefore !== undefined && Number.isNaN(Date.parse(notBefore))) {
    throw new BadRequestException('notBefore must be an ISO 8601 date-time');
  }

  return { title, minutes, notBefore };
}

/** Reads what the detail screen changed about a fixed block. */
export function requireEventEdit(dto: EditEventDto): EventEdit {
  const edit: EventEdit = requireTaskEdit(dto);

  if (dto.startTime !== undefined) {
    if (
      typeof dto.startTime !== 'string' ||
      Number.isNaN(Date.parse(dto.startTime))
    ) {
      throw new BadRequestException('startTime must be an ISO 8601 date-time');
    }
    edit.startTime = dto.startTime;
  }

  return edit;
}

/** Reads what the detail screen changed about a task. */
export function requireTaskEdit(dto: EditEventDto): TaskEdit {
  const edit: TaskEdit = {};

  if (dto.title !== undefined) {
    const title = typeof dto.title === 'string' ? dto.title.trim() : '';
    if (title === '') throw new BadRequestException('title cannot be empty');
    edit.title = title;
  }

  if (dto.workMinutes !== undefined) {
    const minutes = dto.workMinutes;
    if (
      typeof minutes !== 'number' ||
      !Number.isInteger(minutes) ||
      minutes <= 0
    ) {
      throw new BadRequestException('workMinutes must be a positive integer');
    }
    edit.workMinutes = minutes;
  }

  if (dto.notes !== undefined) {
    if (typeof dto.notes !== 'string' || dto.notes.length > 20_000) {
      throw new BadRequestException('notes must be a string of at most 20000');
    }
    edit.notes = dto.notes;
  }

  return edit;
}

/** How much more or less time something gets: a non-zero whole number. */
export function requireDelta(minutes: number | undefined): number {
  if (
    typeof minutes !== 'number' ||
    !Number.isInteger(minutes) ||
    minutes === 0
  ) {
    throw new BadRequestException('minutes must be a non-zero integer');
  }

  return minutes;
}

/** How long a snooze is: between one minute and four hours. */
export function requireSnooze(minutes: number | undefined): number {
  const value = minutes ?? 15;
  if (!Number.isInteger(value) || value <= 0 || value > 240) {
    throw new BadRequestException('minutes must be between 1 and 240');
  }

  return value;
}

function requireTitle(raw: string | undefined): string {
  const title = typeof raw === 'string' ? raw.trim() : '';
  if (title === '') throw new BadRequestException('title is required');

  return title;
}

function requireMinutes(raw: number | undefined, name: string): number {
  if (typeof raw !== 'number' || !Number.isFinite(raw) || raw <= 0) {
    throw new BadRequestException(`${name} must be positive`);
  }

  return Math.round(raw);
}
