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

  if (dto.pending !== undefined) {
    if (typeof dto.pending !== 'boolean') {
      throw new BadRequestException('pending must be a boolean');
    }
    if (dto.pending && !backlog) {
      throw new BadRequestException('only a drop off the day can be pending');
    }
    if (dto.pending) action.pending = true;
  }

  if (dto.after !== undefined) {
    if (typeof dto.after !== 'string' || Number.isNaN(Date.parse(dto.after))) {
      throw new BadRequestException('after must be an ISO 8601 date-time');
    }
    action.after = dto.after;
  }

  if (dto.split !== undefined) {
    if (typeof dto.split !== 'boolean') {
      throw new BadRequestException('split must be a boolean');
    }
    if (dto.split && (action.start || backlog || dto.minutes === undefined)) {
      throw new BadRequestException(
        'split takes minutes, and only on a drop on the day that starts nothing',
      );
    }
    if (dto.split) action.split = true;
  }

  if (dto.decision !== undefined) {
    // The guard answered before the move was posted (#89): play asks
    // whether to pause what runs before it asks how much.
    if (
      typeof dto.decision !== 'string' ||
      !TIMING_DECISIONS.includes(dto.decision as TimingDecision)
    ) {
      throw new BadRequestException(`Unknown decision "${dto.decision}"`);
    }
    if (!action.start) {
      throw new BadRequestException('only a drop that starts takes a decision');
    }
    action.decision = dto.decision as TimingDecision;
  }

  if (dto.minutes !== undefined) {
    // With start, a piece of the task to begin: the rest waits in Pendentes.
    // With split, a piece to put in that place: the rest stays where it was.
    if (action.start || action.split) {
      action.minutes = requirePlayPiece(dto.minutes);
    } else {
      if (!Number.isInteger(dto.minutes) || dto.minutes < 5) {
        throw new BadRequestException(
          'minutes must be an integer of at least 5',
        );
      }
      action.minutes = dto.minutes;
    }
  }

  return action;
}

/** A piece of a task begun by play: 5 minutes to 8 hours, said in Portuguese. */
function requirePlayPiece(minutes: unknown): number {
  if (
    typeof minutes !== 'number' ||
    !Number.isInteger(minutes) ||
    minutes < 5 ||
    minutes > 480
  ) {
    throw new BadRequestException(
      'Um pedaço de tarefa vai de 5 minutos a 8 horas.',
    );
  }
  return minutes;
}

/** Reads a guard's answer off the wire, refusing anything it cannot trust. */
export function requireTiming(action: {
  taskId?: string;
  index?: number;
  decision?: string;
  minutes?: unknown;
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
    ...(action.minutes === undefined || action.minutes === null
      ? {}
      : { minutes: requirePlayPiece(action.minutes) }),
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

  if (dto.checklist !== undefined) {
    const items: unknown = dto.checklist;
    if (
      !Array.isArray(items) ||
      items.length > 30 ||
      items.some(
        (it) =>
          typeof it !== 'object' ||
          it === null ||
          typeof (it as { title?: unknown }).title !== 'string' ||
          (it as { title: string }).title.trim() === '' ||
          (it as { title: string }).title.length > 200 ||
          typeof (it as { done?: unknown }).done !== 'boolean',
      )
    ) {
      throw new BadRequestException(
        'checklist must be at most 30 items of { title, done }',
      );
    }
    edit.checklist = (items as { title: string; done: boolean }[]).map(
      (it) => ({ title: it.title.trim(), done: it.done }),
    );
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

/** The step of every "not yet" and "more time": the reminders' +10. */
export const STEP_MINUTES = 10;

/** How long a snooze or a delay is: between one minute and four hours. */
/** A piece of a task to begin, 5 minutes to 8 hours; none when not said. */
export function requirePiece(minutes: unknown): number | undefined {
  if (minutes === undefined || minutes === null) return undefined;
  if (
    typeof minutes !== 'number' ||
    !Number.isInteger(minutes) ||
    minutes < 5 ||
    minutes > 480
  ) {
    throw new BadRequestException('minutes must be an integer from 5 to 480');
  }

  return minutes;
}

export function requireSnooze(minutes: number | undefined): number {
  const value = minutes ?? STEP_MINUTES;
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
