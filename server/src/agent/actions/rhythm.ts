import { DayKind } from '../../time/day-kinds';
import { PlanChange } from '../plan';
import { Action, as, Draft, Resolving, Refusal } from './action';

/** What a kind of day reads as on the card. */
const KIND_WORDS: Record<DayKind, string> = {
  work: 'normal',
  light: 'leve',
  off: 'folga',
};

/**
 * Ciclo and Folgas' own gestures, through `RhythmService`: a period that
 * began, the next one corrected, the weekend's rule, a date off or a
 * weekend day put back to work. Each is what the person does on those
 * pages, and is refused as they are.
 *
 * The board shows the phase and the kind of each day, never the dates of
 * past periods.
 */
export const RHYTHM: Action[] = [
  {
    name: 'period_started',
    domain: 'rhythm',
    does: 'Ciclo’s "Menstruação começou": a period began on a day, today or before. The cycles count again from it.',
    args: {
      day: 'period_started: the day it began (hoje, ontem, YYYY-MM-DD).',
    },
    required: ['day'],
    resolve(r, item) {
      const day = r.day(item.day);
      if (day > r.board.today) {
        throw new Refusal(
          'period_started is for a day already come; for one ahead use predict_period.',
        );
      }
      return draft(
        r,
        { do: 'period_started', day },
        `Menstruação começou em ${ddmm(day)}`,
      );
    },
    async make(hands, user, gesture, _made, _trace, now) {
      const g = as(gesture, 'period_started');
      await hands.rhythm.periodStarted(user, g.day, now);
      return user.id;
    },
    line: (_drawing, d) => lineOf(d),
  },
  {
    name: 'predict_period',
    domain: 'rhythm',
    does: 'A day of Ciclo’s grid ahead: the next period will begin on that day, correcting the prediction; "none" goes back to the prediction.',
    args: {
      day: 'predict_period: the day the next period begins, after today, or "none".',
    },
    required: ['day'],
    resolve(r, item) {
      if (r.board.cycle === undefined) {
        throw new Refusal(
          'There is no cycle yet: ask when the last period began (period_started).',
        );
      }
      const day = item.day === 'none' ? null : r.day(item.day);
      if (day !== null && day <= r.board.today) {
        throw new Refusal(
          'predict_period is for a day ahead; a period that began is period_started.',
        );
      }
      return draft(
        r,
        { do: 'predict_period', day },
        day === null
          ? 'Próxima menstruação: voltar à previsão'
          : `Próxima menstruação em ${ddmm(day)}`,
      );
    },
    async make(hands, user, gesture, _made, _trace, now) {
      const g = as(gesture, 'predict_period');
      await hands.rhythm.predictStart(user, g.day, now);
      return user.id;
    },
    line: (_drawing, d) => lineOf(d),
  },
  {
    name: 'set_weekend',
    domain: 'rhythm',
    does: 'Folgas’ weekend: what every Saturday and Sunday is (work, light, off). Off by default.',
    args: { saturday: true, sunday: true },
    resolve(r, item) {
      const saturday = kindOf(item.saturday);
      const sunday = kindOf(item.sunday);
      if (saturday === undefined && sunday === undefined) {
        throw new Refusal('set_weekend needs saturday, sunday or both.');
      }
      const words = [
        ...(saturday === undefined ? [] : [`sábado ${KIND_WORDS[saturday]}`]),
        ...(sunday === undefined ? [] : [`domingo ${KIND_WORDS[sunday]}`]),
      ];
      return draft(
        r,
        {
          do: 'set_weekend',
          ...(saturday === undefined ? {} : { saturday }),
          ...(sunday === undefined ? {} : { sunday }),
        },
        `Fim de semana: ${words.join(', ')}`,
      );
    },
    async make(hands, user, gesture) {
      const g = as(gesture, 'set_weekend');
      await hands.rhythm.editRest(user, {
        ...(g.saturday === undefined ? {} : { saturday: g.saturday }),
        ...(g.sunday === undefined ? {} : { sunday: g.sunday }),
      });
      return user.id;
    },
    line: (_drawing, d) => lineOf(d),
  },
  {
    name: 'day_off',
    domain: 'rhythm',
    does: 'Folgas’ list: one date written down as a day off (a holiday, a trip), or a weekend day put back to work. It wins over the weekend; the period still applies.',
    args: {
      day: 'day_off: the date, today or ahead.',
      day_kind: true,
      title: 'day_off: what it is, as the person named it (Feriado). Optional.',
    },
    required: ['day'],
    resolve(r, item) {
      const day = r.day(item.day);
      if (day < r.board.today) {
        throw new Refusal('day_off is for today or a day ahead.');
      }
      const kind = item.day_kind === 'work' ? 'work' : 'off';
      const title = typeof item.title === 'string' ? item.title.trim() : '';
      return draft(
        r,
        { do: 'day_off', day, kind, title },
        kind === 'work'
          ? `Trabalhar em ${ddmm(day)}`
          : `Folga em ${ddmm(day)}${title === '' ? '' : ` · ${title}`}`,
      );
    },
    async make(hands, user, gesture, _made, _trace, now) {
      const g = as(gesture, 'day_off');
      await hands.rhythm.putDay(
        user,
        { day: g.day, kind: g.kind, title: g.title },
        now,
      );
      return user.id;
    },
    line: (_drawing, d) => lineOf(d),
  },
];

function draft(r: Resolving, gesture: Draft['gesture'], title: string): Draft {
  return {
    gesture,
    facts: r.facts,
    assumed: r.assumed,
    duplicate: true,
    view: { kind: 'set_rhythm', title, minutes: 0 },
  };
}

function lineOf(draft: Draft): PlanChange {
  return { ...draft.view!, routine: false };
}

function kindOf(raw: unknown): DayKind | undefined {
  return raw === 'work' || raw === 'light' || raw === 'off' ? raw : undefined;
}

/** `2026-11-20` as a person reads it: 20/11. */
function ddmm(day: string): string {
  return `${day.slice(8, 10)}/${day.slice(5, 7)}`;
}
