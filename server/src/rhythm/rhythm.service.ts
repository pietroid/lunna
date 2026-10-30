import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CalendarUser } from '../calendar/calendar.types';
import {
  Cycle,
  DayKind,
  DayOff,
  nextPeriodOf,
  RestRules,
  Rhythm,
} from '../time/day-kinds';
import { isoDayIn, systemZone } from '../time/zone';
import {
  EditRestDto,
  PutDayDto,
  requireCycleLength,
  requireDay,
  requireDayOff,
  requireDayOffId,
  requireKind,
  requireLightMinutes,
  requirePeriodLength,
  requireStart,
  SaveCycleDto,
} from './request';
import { RhythmStore } from './rhythm.store';

/** The cycle as the app draws it: the prediction worked out. */
export interface CycleView extends Cycle {
  nextStart?: string;
  /** The next period's first day: corrected, or predicted. */
  predictedStart: string;
}

/** What every route under `/api/rhythm` answers. */
export interface RhythmView {
  cycle: CycleView | null;
  rest: RestRules;
  /** The dates from today on, earliest first. */
  daysOff: DayOff[];
}

/**
 * Ciclo and Folgas: the cycle, the weekend's rule and the dates written
 * down. Its own service so the routes and the agent change it the same
 * way.
 *
 * Nothing about the day is written here: the next read of the timeline
 * lays the queue out over the new kinds of day, since no task's hour is
 * stored.
 */
@Injectable()
export class RhythmService {
  constructor(private readonly _store: RhythmStore) {}

  async view(user: CalendarUser, now = new Date()): Promise<RhythmView> {
    const today = todayOf(user, now);
    const rhythm = await this._store.read(user);
    const cycle = rhythm.cycle;

    return {
      cycle:
        cycle === undefined
          ? null
          : { ...cycle, predictedStart: nextPeriodOf(cycle, today) },
      rest: rhythm.rest,
      daysOff: rhythm.daysOff.filter((it) => it.day >= today),
    };
  }

  read(user: CalendarUser): Promise<Rhythm> {
    return this._store.read(user);
  }

  /** Writes [rhythm] back whole: undoing an agent's plan. */
  restore(user: CalendarUser, rhythm: Rhythm): Promise<void> {
    return this._store.replace(user, rhythm);
  }

  /** A period began on [raw]: the cycles count again from it. */
  async periodStarted(
    user: CalendarUser,
    raw: unknown,
    now = new Date(),
  ): Promise<void> {
    const day = requireStart(raw, todayOf(user, now));
    const rhythm = await this._store.read(user);
    await this._store.addStart(user, day);
    // Whatever the correction was about, a start written down replaces it.
    await this._store.setCycle(user, {
      ...settingsOf(rhythm),
      nextStart: null,
    });
  }

  /** Writes the cycle down whole, as Ciclo's rows do. */
  async saveCycle(
    user: CalendarUser,
    dto: SaveCycleDto,
    now = new Date(),
  ): Promise<void> {
    const today = todayOf(user, now);
    const lastStart = requireStart(dto.lastStart, today);
    const length = requireCycleLength(dto.length);
    const periodLength = requirePeriodLength(dto.periodLength);
    if (periodLength >= length) {
      throw new BadRequestException(
        'A menstruação precisa ser mais curta que o ciclo.',
      );
    }
    const periodKind = requireKind(dto.periodKind ?? 'light', 'periodKind');
    const nextStart =
      dto.nextStart === undefined || dto.nextStart === null
        ? null
        : requireDay(dto.nextStart, 'nextStart');
    if (nextStart !== null && nextStart <= today) {
      throw new BadRequestException(
        'A próxima menstruação é um dia adiante; se já começou, marque o dia em que começou.',
      );
    }

    const rhythm = await this._store.read(user);
    if (rhythm.cycle?.lastStart !== lastStart) {
      await this._store.addStart(user, lastStart);
    }
    await this._store.setCycle(user, {
      length,
      periodLength,
      periodKind,
      nextStart,
    });
  }

  /** Corrects the prediction: the next period begins on [raw], or null. */
  async predictStart(
    user: CalendarUser,
    raw: string | null,
    now = new Date(),
  ): Promise<void> {
    const rhythm = await this._store.read(user);
    const cycle = rhythm.cycle;
    if (cycle === undefined) {
      throw new BadRequestException(
        'Marque primeiro o dia em que a última menstruação começou.',
      );
    }
    await this.saveCycle(user, { ...cycle, nextStart: raw }, now);
  }

  /** Sets the weekend's rule and the light day's budget. */
  async editRest(user: CalendarUser, dto: EditRestDto): Promise<void> {
    const { rest } = await this._store.read(user);
    await this._store.setRest(user, {
      saturday:
        dto.saturday === undefined
          ? rest.saturday
          : requireKind(dto.saturday, 'saturday'),
      sunday:
        dto.sunday === undefined
          ? rest.sunday
          : requireKind(dto.sunday, 'sunday'),
      lightMinutes:
        dto.lightMinutes === undefined
          ? rest.lightMinutes
          : requireLightMinutes(dto.lightMinutes),
    });
  }

  /** Writes a date down: off, or a weekend day back to work. */
  putDay(
    user: CalendarUser,
    dto: PutDayDto,
    now = new Date(),
  ): Promise<DayOff> {
    return this._store.putDay(user, requireDayOff(dto, todayOf(user, now)));
  }

  /** Takes a date away: the day is what the weekend and the cycle make it. */
  async removeDay(user: CalendarUser, raw: unknown): Promise<void> {
    if (!(await this._store.removeDay(user, requireDayOffId(raw)))) {
      throw new NotFoundException('Esse dia não está mais anotado.');
    }
  }
}

function todayOf(user: CalendarUser, now: Date): string {
  return isoDayIn(now, user.timeZone ?? systemZone());
}

function settingsOf(rhythm: Rhythm): {
  length: number;
  periodLength: number;
  periodKind: DayKind;
} {
  return {
    length: rhythm.cycle?.length ?? 28,
    periodLength: rhythm.cycle?.periodLength ?? 5,
    periodKind: rhythm.cycle?.periodKind ?? 'light',
  };
}
