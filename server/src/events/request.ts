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
import { DonePage } from '../tasks/task.types';
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
    workDay: { start: user.dayStart, end: user.dayEnd },
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
  const backlog = dto.backlog === true;
  const action: TimingAction = {
    taskId,
    index: requireIndex(dto.index),
    start: dto.start === true,
    backlog,
  };

  if (backlog && (action.start || dto.after !== undefined)) {
    throw new BadRequestException('the backlog has no hours to drop into');
  }

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

  if (dto.backlog !== undefined && typeof dto.backlog !== 'boolean') {
    throw new BadRequestException('backlog must be a boolean');
  }
  const backlog = dto.backlog ?? true;

  const notBefore = dto.notBefore;
  if (notBefore !== undefined && Number.isNaN(Date.parse(notBefore))) {
    throw new BadRequestException('notBefore must be an ISO 8601 date-time');
  }

  if (backlog && dto.index !== undefined) {
    throw new BadRequestException('the backlog takes a task at its end');
  }

  if (dto.artifactId !== undefined && typeof dto.artifactId !== 'string') {
    throw new BadRequestException('artifactId must be a string');
  }

  return {
    title,
    minutes,
    backlog,
    notBefore: backlog ? undefined : notBefore,
    index: dto.index === undefined ? undefined : requireIndex(dto.index),
    ...(dto.artifactId === undefined ? {} : { artifactId: dto.artifactId }),
  };
}

/** Reads what the detail screen changed about a fixed block. */
export function requireEventEdit(dto: EditEventDto): EventEdit {
  return requireTaskEdit(dto);
}

/**
 * Reads what the detail screen, or a drop on the calendar, changed about a
 * task or a block: its words, its length, or its hour.
 */
export function requireTaskEdit(dto: EditEventDto): TaskEdit {
  const edit: TaskEdit = {};

  if (dto.startTime !== undefined) {
    if (
      typeof dto.startTime !== 'string' ||
      Number.isNaN(Date.parse(dto.startTime))
    ) {
      throw new BadRequestException('startTime must be an ISO 8601 date-time');
    }
    edit.startTime = dto.startTime;
  }

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

/** A new length for a block: a whole number of minutes, at least five. */
export function requireLength(minutes: number | undefined): number {
  if (
    typeof minutes !== 'number' ||
    !Number.isInteger(minutes) ||
    minutes < 5 ||
    minutes > 24 * 60
  ) {
    throw new BadRequestException('minutes must be between 5 and 1440');
  }

  return minutes;
}

/** The task a swap trades places with. */
export function requireSwap(other: string | undefined): string {
  const id = typeof other === 'string' ? other.trim() : '';
  if (id === '') throw new BadRequestException('with is required');

  return id;
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

/** How many finished tasks a page of the archive holds, unless asked. */
export const DONE_PAGE = 30;

/** The most a page of the archive holds. */
export const MAX_DONE_PAGE = 100;

/**
 * A page of the archive: `?before=<iso>&beforeId=<id>&q=<words>&limit=<n>`.
 *
 * [before] and [beforeId] are the last task of the page before; [q] is
 * looked for in titles and notes, and blank is no search at all.
 */
export function requireDonePage(raw: {
  before?: string;
  beforeId?: string;
  q?: string;
  limit?: string;
}): DonePage {
  const page: DonePage = { limit: DONE_PAGE };

  if (raw.limit !== undefined) {
    const limit = Number(raw.limit);
    if (!Number.isInteger(limit) || limit < 1 || limit > MAX_DONE_PAGE) {
      throw new BadRequestException(
        `Peça entre 1 e ${MAX_DONE_PAGE} tarefas por vez.`,
      );
    }
    page.limit = limit;
  }

  if (raw.before !== undefined || raw.beforeId !== undefined) {
    if (
      typeof raw.before !== 'string' ||
      Number.isNaN(Date.parse(raw.before)) ||
      typeof raw.beforeId !== 'string' ||
      raw.beforeId === ''
    ) {
      throw new BadRequestException(
        'Não sei de onde continuar: mande a data e o id da última tarefa.',
      );
    }
    page.before = { at: raw.before, id: raw.beforeId };
  }

  if (raw.q !== undefined) {
    if (typeof raw.q !== 'string' || raw.q.length > 200) {
      throw new BadRequestException('Essa busca é longa demais.');
    }
    const words = raw.q.trim();
    if (words !== '') page.query = words;
  }

  return page;
}
