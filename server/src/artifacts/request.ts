import { BadRequestException } from '@nestjs/common';
import {
  CreateArtifactDto,
  CreateArtifactTaskDto,
  CreateCatalogTypeDto,
  CreateGoalDto,
  EditArtifactDto,
  MoveArtifactDto,
} from './dto/artifact.dto';
import {
  ArtifactEdit,
  GoalKind,
  GoalPeriod,
  GoalStart,
  NewArtifact,
  QueueEnd,
} from './artifact.types';

/**
 * Reading what the app sent, for every route about deliveries, the
 * catalogue and goals.
 *
 * As for the day: a request that cannot be trusted is a 400 with a reason,
 * never a guess.
 */

/** A new delivery, and where it enters the queue. */
export function requireArtifact(dto: CreateArtifactDto): {
  artifact: NewArtifact;
  at: QueueEnd;
} {
  const deadline = deadlineOf(dto.deadline);
  const minutes = amountOf(dto.minutes, 'minutes');
  const value = amountOf(dto.value, 'value', true);
  const blockMinutes = amountOf(dto.blockMinutes, 'blockMinutes');
  if (dto.typeId !== undefined && typeof dto.typeId !== 'string') {
    throw new BadRequestException('typeId must be a string');
  }
  if (dto.at !== undefined && dto.at !== 'top' && dto.at !== 'end') {
    throw new BadRequestException('at must be top or end');
  }
  const started = flagOf(dto.started, 'started');

  return {
    artifact: {
      title: requireText(dto.title, 'title'),
      ...(dto.typeId === undefined ? {} : { typeId: dto.typeId }),
      ...(minutes == null ? {} : { minutes }),
      ...(value == null ? {} : { value }),
      ...(blockMinutes === undefined ? {} : { blockMinutes }),
      ...(deadline == null ? {} : { deadline }),
      ...(started === true ? { started } : {}),
    },
    at: dto.at ?? 'end',
  };
}

/** A change to a delivery. */
export function requireArtifactEdit(dto: EditArtifactDto): ArtifactEdit {
  const edit: ArtifactEdit = {};
  if (dto.title !== undefined) edit.title = requireText(dto.title, 'title');
  if (dto.notes !== undefined) {
    if (typeof dto.notes !== 'string') {
      throw new BadRequestException('notes must be a string');
    }
    edit.notes = dto.notes;
  }
  const deadline = deadlineOf(dto.deadline);
  if (deadline !== undefined) edit.deadline = deadline;
  const minutes = amountOf(dto.minutes, 'minutes');
  if (minutes !== undefined) edit.minutes = minutes;
  const value = amountOf(dto.value, 'value', true);
  if (value !== undefined) edit.value = value;
  const blockMinutes = amountOf(dto.blockMinutes, 'blockMinutes');
  if (blockMinutes !== undefined) edit.blockMinutes = blockMinutes;
  const done = flagOf(dto.done, 'done');
  if (done !== undefined) edit.done = done;
  const started = flagOf(dto.started, 'started');
  if (started !== undefined) edit.started = started;

  return edit;
}

/**
 * The place a delivery is dragged to, and, dropped among those not begun,
 * `started: false`. Only that one: beginning one may need a deadline, so
 * it is the edit's (`PATCH { started: true }`).
 */
export function requireArtifactMove(dto: MoveArtifactDto): {
  index: number;
  stop: boolean;
} {
  const index = dto.index;
  if (typeof index !== 'number' || !Number.isInteger(index) || index < 0) {
    throw new BadRequestException('index must be a whole number, 0 or more');
  }
  const started = flagOf(dto.started, 'started');
  if (started === true) {
    throw new BadRequestException(
      'a move only stops a delivery (started: false)',
    );
  }
  return { index, stop: started === false };
}

/** A task written down in a delivery. */
export function requireArtifactTask(dto: CreateArtifactTaskDto): {
  title: string;
  minutes: number;
} {
  const minutes = amountOf(dto.minutes, 'minutes');
  if (minutes == null)
    throw new BadRequestException('minutes must be positive');

  return { title: requireText(dto.title, 'title'), minutes };
}

/** A kind written down in the catalogue. */
export function requireCatalogType(dto: CreateCatalogTypeDto): {
  name: string;
  minutes: number;
  price?: number;
  blockMinutes?: number;
  categoryId?: string;
  category?: string;
} {
  const minutes = amountOf(dto.minutes, 'minutes');
  if (minutes == null)
    throw new BadRequestException('minutes must be positive');
  const price = amountOf(dto.price, 'price', true);
  const blockMinutes = amountOf(dto.blockMinutes, 'blockMinutes');
  if ((dto.categoryId === undefined) === (dto.category === undefined)) {
    throw new BadRequestException('give categoryId or category, not both');
  }
  if (dto.categoryId !== undefined && typeof dto.categoryId !== 'string') {
    throw new BadRequestException('categoryId must be a string');
  }

  return {
    name: requireText(dto.name, 'name'),
    minutes,
    ...(price == null ? {} : { price }),
    ...(blockMinutes == null ? {} : { blockMinutes }),
    ...(dto.categoryId === undefined
      ? { category: requireText(dto.category, 'category') }
      : { categoryId: dto.categoryId }),
  };
}

/** A new goal. */
export function requireGoal(dto: CreateGoalDto): {
  kind: GoalKind;
  target: number;
  period: GoalPeriod;
  typeId?: string;
  start: GoalStart;
} {
  if (dto.kind !== 'money' && dto.kind !== 'count') {
    throw new BadRequestException('kind must be money or count');
  }
  if (dto.period !== 'week' && dto.period !== 'month') {
    throw new BadRequestException('period must be week or month');
  }
  const start = dto.start ?? 'now';
  if (start !== 'now' && start !== 'next') {
    throw new BadRequestException('start must be now or next');
  }
  const target = amountOf(dto.target, 'target');
  if (target == null) throw new BadRequestException('target must be positive');
  if (dto.kind === 'count' && typeof dto.typeId !== 'string') {
    throw new BadRequestException('Uma meta de quantidade conta um tipo.');
  }

  return {
    kind: dto.kind,
    target,
    period: dto.period,
    start,
    ...(dto.kind === 'count' ? { typeId: dto.typeId } : {}),
  };
}

function flagOf(raw: unknown, name: string): boolean | undefined {
  if (raw === undefined) return undefined;
  if (typeof raw !== 'boolean') {
    throw new BadRequestException(`${name} must be a boolean`);
  }
  return raw;
}

function requireText(raw: unknown, name: string): string {
  const text = typeof raw === 'string' ? raw.trim() : '';
  if (text === '') throw new BadRequestException(`${name} is required`);

  return text;
}

/**
 * A whole positive number (or zero, with [zero]), null, or undefined when
 * not given.
 */
function amountOf(
  raw: unknown,
  name: string,
  zero = false,
): number | null | undefined {
  if (raw === undefined || raw === null) return raw;
  if (
    typeof raw !== 'number' ||
    !Number.isFinite(raw) ||
    raw < 0 ||
    (raw === 0 && !zero)
  ) {
    throw new BadRequestException(`${name} must be positive`);
  }
  return Math.round(raw);
}

/** A `YYYY-MM-DD` that is a real day, null, or undefined when not given. */
function deadlineOf(raw: unknown): string | null | undefined {
  if (raw === undefined || raw === null) return raw;
  if (typeof raw !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    throw new BadRequestException('deadline must be a YYYY-MM-DD day');
  }
  const [year, month, day] = raw.split('-').map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (parsed.getUTCMonth() !== month - 1 || parsed.getUTCDate() !== day) {
    throw new BadRequestException('deadline must be a YYYY-MM-DD day');
  }

  return raw;
}
