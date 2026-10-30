import { randomUUID } from 'crypto';
import { CalendarUser } from '../calendar/calendar.types';
import {
  Cycle,
  DayKind,
  DayOff,
  DEFAULT_CYCLE_LENGTH,
  DEFAULT_PERIOD_LENGTH,
  DEFAULT_REST,
  RestRules,
  Rhythm,
} from '../time/day-kinds';

/** The cycle's settings, without the starts it counts from. */
export interface CycleSettings {
  length: number;
  periodLength: number;
  periodKind: DayKind;
  /** The corrected next start; null goes back to the prediction. */
  nextStart: string | null;
}

/**
 * Where the rhythm is kept: the weekend's rule, the cycle and the dates
 * written down.
 *
 * Postgres in production ([PgRhythmStore]); memory in the end-to-end
 * tests and on the agent's sandbox copy of the day ([MemoryRhythmStore]).
 */
export abstract class RhythmStore {
  /** All of it; the weekend off and no cycle for someone who set nothing. */
  abstract read(user: CalendarUser): Promise<Rhythm>;

  abstract setRest(user: CalendarUser, rest: RestRules): Promise<void>;

  abstract setCycle(user: CalendarUser, settings: CycleSettings): Promise<void>;

  /** A period began on [day]; every start after it is forgotten. */
  abstract addStart(user: CalendarUser, day: string): Promise<void>;

  /** Writes [day] down, replacing whatever was written on its date. */
  abstract putDay(user: CalendarUser, day: Omit<DayOff, 'id'>): Promise<DayOff>;

  /** Takes a date away. Answers whether there was one. */
  abstract removeDay(user: CalendarUser, id: string): Promise<boolean>;

  /**
   * Writes [rhythm] back whole, as it was read: what undoing an agent's
   * plan does. The cycle's earlier starts are kept up to its last.
   */
  abstract replace(user: CalendarUser, rhythm: Rhythm): Promise<void>;
}

interface Kept {
  rest: RestRules;
  settings: CycleSettings;
  starts: string[];
  days: DayOff[];
}

const DEFAULT_SETTINGS: CycleSettings = {
  length: DEFAULT_CYCLE_LENGTH,
  periodLength: DEFAULT_PERIOD_LENGTH,
  periodKind: 'light',
  nextStart: null,
};

/** The rhythm, in memory. Behaves like the Postgres store. */
export class MemoryRhythmStore extends RhythmStore {
  private readonly _kept = new Map<string, Kept>();

  /** Starts this store with [rhythm] for [user]: the sandbox's copy. */
  seed(user: CalendarUser, rhythm: Rhythm): void {
    const cycle = rhythm.cycle;
    this._kept.set(user.id, {
      rest: { ...rhythm.rest },
      settings:
        cycle === undefined
          ? { ...DEFAULT_SETTINGS }
          : {
              length: cycle.length,
              periodLength: cycle.periodLength,
              periodKind: cycle.periodKind,
              nextStart: cycle.nextStart ?? null,
            },
      starts: cycle === undefined ? [] : [cycle.lastStart],
      days: rhythm.daysOff.map((it) => ({ ...it })),
    });
  }

  private _of(user: CalendarUser): Kept {
    let kept = this._kept.get(user.id);
    if (kept === undefined) {
      kept = {
        rest: { ...DEFAULT_REST },
        settings: { ...DEFAULT_SETTINGS },
        starts: [],
        days: [],
      };
      this._kept.set(user.id, kept);
    }
    return kept;
  }

  read(user: CalendarUser): Promise<Rhythm> {
    const kept = this._of(user);
    return Promise.resolve(
      rhythmOf(kept.rest, kept.settings, kept.starts, kept.days),
    );
  }

  setRest(user: CalendarUser, rest: RestRules): Promise<void> {
    this._of(user).rest = { ...rest };
    return Promise.resolve();
  }

  setCycle(user: CalendarUser, settings: CycleSettings): Promise<void> {
    this._of(user).settings = { ...settings };
    return Promise.resolve();
  }

  addStart(user: CalendarUser, day: string): Promise<void> {
    const kept = this._of(user);
    kept.starts = [...kept.starts.filter((it) => it < day), day];
    return Promise.resolve();
  }

  putDay(user: CalendarUser, day: Omit<DayOff, 'id'>): Promise<DayOff> {
    const kept = this._of(user);
    const written = { id: randomUUID(), ...day };
    kept.days = [...kept.days.filter((it) => it.day !== day.day), written];
    return Promise.resolve(written);
  }

  replace(user: CalendarUser, rhythm: Rhythm): Promise<void> {
    const starts = this._of(user).starts.filter(
      (it) => rhythm.cycle !== undefined && it < rhythm.cycle.lastStart,
    );
    this.seed(user, rhythm);
    this._of(user).starts.unshift(...starts);
    return Promise.resolve();
  }

  removeDay(user: CalendarUser, id: string): Promise<boolean> {
    const kept = this._of(user);
    const before = kept.days.length;
    kept.days = kept.days.filter((it) => it.id !== id);
    return Promise.resolve(kept.days.length < before);
  }
}

/** The rhythm the stores answer, from what they keep. */
export function rhythmOf(
  rest: RestRules,
  settings: CycleSettings,
  starts: string[],
  days: DayOff[],
): Rhythm {
  const lastStart = [...starts].sort().at(-1);
  const cycle: Cycle | undefined =
    lastStart === undefined
      ? undefined
      : {
          lastStart,
          length: settings.length,
          periodLength: settings.periodLength,
          periodKind: settings.periodKind,
          ...(settings.nextStart === null
            ? {}
            : { nextStart: settings.nextStart }),
        };

  return {
    rest: { ...rest },
    ...(cycle === undefined ? {} : { cycle }),
    daysOff: [...days].sort((a, b) => a.day.localeCompare(b.day)),
  };
}
