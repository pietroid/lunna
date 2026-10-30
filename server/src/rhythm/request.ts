import { BadRequestException } from '@nestjs/common';
import { DAY_KINDS, DayKind } from '../time/day-kinds';

/**
 * Reading what Ciclo and Folgas send: refuse, never guess, as
 * `events/request.ts` does. What a person could get wrong is refused in
 * Portuguese; what only a broken client sends, in English.
 */

/** The cycle as Ciclo writes it down (`PUT /rhythm/cycle`). */
export class SaveCycleDto {
  lastStart?: string;
  length?: number;
  periodLength?: number;
  periodKind?: string;
  nextStart?: string | null;
}

/** `POST /rhythm/cycle/start`. */
export class PeriodStartedDto {
  day?: string;
}

/** `PATCH /rhythm/rest`. */
export class EditRestDto {
  saturday?: string;
  sunday?: string;
  lightMinutes?: number;
}

/** `POST /rhythm/days-off`. */
export class PutDayDto {
  day?: string;
  kind?: string;
  title?: string;
}

export const MIN_CYCLE = 21;
export const MAX_CYCLE = 45;
export const MAX_PERIOD = 10;
/** The most a light day may take: a whole working day is a working day. */
export const MAX_LIGHT_MINUTES = 8 * 60;
const MAX_TITLE = 80;

/** A `YYYY-MM-DD` that names a real date. */
export function requireDay(raw: unknown, name = 'day'): string {
  if (typeof raw !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    throw new BadRequestException(`${name} must be a YYYY-MM-DD day`);
  }
  const [year, month, day] = raw.split('-').map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (parsed.getUTCMonth() !== month - 1 || parsed.getUTCDate() !== day) {
    throw new BadRequestException(`${name} must be a YYYY-MM-DD day`);
  }
  return raw;
}

export function requireKind(raw: unknown, name = 'kind'): DayKind {
  if (!DAY_KINDS.includes(raw as DayKind)) {
    throw new BadRequestException(`${name} must be work, light or off`);
  }
  return raw as DayKind;
}

/** A start that already happened: today or before. */
export function requireStart(raw: unknown, today: string): string {
  const day = requireDay(raw);
  if (day > today) {
    throw new BadRequestException(
      'A menstruação só pode ter começado hoje ou antes.',
    );
  }
  return day;
}

export function requireCycleLength(raw: unknown): number {
  if (
    !Number.isInteger(raw) ||
    (raw as number) < MIN_CYCLE ||
    (raw as number) > MAX_CYCLE
  ) {
    throw new BadRequestException(
      `O ciclo dura de ${MIN_CYCLE} a ${MAX_CYCLE} dias.`,
    );
  }
  return raw as number;
}

export function requirePeriodLength(raw: unknown): number {
  if (
    !Number.isInteger(raw) ||
    (raw as number) < 1 ||
    (raw as number) > MAX_PERIOD
  ) {
    throw new BadRequestException(
      `A menstruação dura de 1 a ${MAX_PERIOD} dias.`,
    );
  }
  return raw as number;
}

export function requireLightMinutes(raw: unknown): number {
  if (
    !Number.isInteger(raw) ||
    (raw as number) < 0 ||
    (raw as number) > MAX_LIGHT_MINUTES ||
    (raw as number) % 5 !== 0
  ) {
    throw new BadRequestException(
      'Um dia leve leva de 0 a 8 horas, de cinco em cinco minutos.',
    );
  }
  return raw as number;
}

/** A date written down: today or ahead, off or back to work. */
export function requireDayOff(
  dto: PutDayDto,
  today: string,
): { day: string; kind: 'off' | 'work'; title: string } {
  const day = requireDay(dto.day);
  if (day < today) {
    throw new BadRequestException('Escolha hoje ou um dia adiante.');
  }
  const kind = dto.kind ?? 'off';
  if (kind !== 'off' && kind !== 'work') {
    throw new BadRequestException('kind must be off or work');
  }
  const title = dto.title ?? '';
  if (typeof title !== 'string' || title.length > MAX_TITLE) {
    throw new BadRequestException(`O nome tem até ${MAX_TITLE} letras.`);
  }
  return { day, kind, title: title.trim() };
}

export function requireDayOffId(raw: unknown): string {
  if (
    typeof raw !== 'string' ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(raw)
  ) {
    throw new BadRequestException('id must be a uuid');
  }
  return raw;
}
