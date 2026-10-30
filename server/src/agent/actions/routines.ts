import { routineDaysOf, RoutineDays } from '../../calendar/calendar.types';
import {
  MAX_CHECKLIST_ITEMS,
  MAX_CHECKLIST_TITLE,
} from '../../routines/routines.controller';
import {
  formatMinuteOfDay,
  MIN_WORK_DAY_MINUTES,
  parseMinuteOfDay,
} from '../../time/work-hours';
import { BoardRoutine, sameTitle } from '../board';
import { PlanChange } from '../plan';
import { Action, as, Draft, Refusal, Resolving } from './action';

/** The longest a routine may be, as Rotina allows: the whole working day. */
const MAX_ROUTINE_MINUTES = 15 * 60;

/** How the working day's line is titled on the card. */
const WORK_DAY_TITLE = 'Dia de trabalho';

/**
 * Rotina's own gestures and the menu's working day: a routine written down
 * or changed, through `RoutinesService`, and the hours the day opens and
 * closes, through `UsersService`. Each is what the person does on Rotina or
 * in the Menu.
 */
export const ROUTINES: Action[] = [
  {
    name: 'new_routine',
    domain: 'routine',
    does: 'A new routine in Rotina: a fixed block at the same hour on its days, with an optional checklist.',
    args: {
      title: 'new_routine: the routine’s name.',
      time: 'new_routine: every day’s hour, HH:mm.',
      minutes: 'new_routine: how long each day of it takes.',
      days: true,
      checklist: true,
      duplicate: true,
    },
    required: ['title', 'time', 'minutes', 'days'],
    resolve(r, item) {
      const title = text(item.title);
      const time = timeOf(item.time);
      const minutes = lengthOf(item.minutes);
      const days = routineDaysOf(item.days);
      if (
        title === '' ||
        time === undefined ||
        minutes === undefined ||
        days === undefined
      ) {
        throw new Refusal(
          'new_routine needs title, time (HH:mm), minutes and days (daily, weekdays or weekend). Ask the person what they did not say.',
        );
      }
      const same = r.board.routines.find((it) => sameTitle(it.title, title));
      if (same !== undefined && item.duplicate !== true) {
        throw new Refusal(
          `"${same.title}" is already a routine (${same.ref}). Change it with edit_routine, or confirm with the person that this is another one and send duplicate: true.`,
        );
      }
      const checklist = checklistOf(item.checklist) ?? [];
      clash(r, undefined, time, minutes, days);
      return {
        gesture: {
          do: 'new_routine',
          title: title.slice(0, 200),
          time,
          minutes,
          days,
          checklist,
        },
        facts: r.facts,
        assumed: r.assumed,
        duplicate: true,
        view: {
          kind: 'add_routine',
          title,
          minutes,
          routine: true,
          hours: hoursOf(time, minutes),
          days,
          ...(checklist.length === 0 ? {} : { checklist }),
        },
      };
    },
    async make(hands, user, gesture, _made, trace, now) {
      const g = as(gesture, 'new_routine');
      const had = new Set((await hands.routines.list(user)).map((it) => it.id));
      const after = await hands.routines.create(
        user,
        {
          title: g.title,
          time: g.time,
          durationMinutes: g.minutes,
          days: g.days,
          checklist: g.checklist,
        },
        trace,
        now,
      );
      return after.find((it) => !had.has(it.id))!.id;
    },
    line: (_drawing, draft) => lineOf(draft),
  },
  {
    name: 'edit_routine',
    domain: 'routine',
    does: 'A routine renamed, given another hour, length, days or checklist. Its days not begun yet change with it.',
    args: {
      ref: 'edit_routine: the routine (r1).',
      title: 'edit_routine: its new name.',
      time: 'edit_routine: its new hour, HH:mm.',
      minutes: 'edit_routine: its new length.',
      days: true,
      checklist:
        'edit_routine: the whole new list, in order; [] takes it away.',
    },
    required: ['ref'],
    resolve(r, item) {
      const it = routineOf(r, item.ref);
      const title = text(item.title);
      const time = item.time === undefined ? undefined : timeOf(item.time);
      if (item.time !== undefined && time === undefined) {
        throw new Refusal('edit_routine: time is HH:mm.');
      }
      const minutes = lengthOf(item.minutes);
      const days =
        item.days === undefined ? undefined : routineDaysOf(item.days);
      if (item.days !== undefined && days === undefined) {
        throw new Refusal('edit_routine: days is daily, weekdays or weekend.');
      }
      const checklist = checklistOf(item.checklist);
      const edit = {
        ...(title === '' || title === it.title ? {} : { title }),
        ...(time === undefined || time === it.time ? {} : { time }),
        ...(minutes === undefined || minutes === it.minutes ? {} : { minutes }),
        ...(days === undefined || days === it.days ? {} : { days }),
        ...(checklist === undefined ||
        checklist.join('\n') === it.checklist.join('\n')
          ? {}
          : { checklist }),
      };
      if (Object.keys(edit).length === 0) {
        throw new Refusal(
          'edit_routine needs what changes: title, time, minutes, days or checklist, different from what it is.',
        );
      }
      const next = {
        title: edit.title ?? it.title,
        time: edit.time ?? it.time,
        minutes: edit.minutes ?? it.minutes,
        days: edit.days ?? it.days,
        checklist: edit.checklist ?? it.checklist,
      };
      clash(r, it.id, next.time, next.minutes, next.days);
      const hours = hoursOf(next.time, next.minutes);
      const wasHours = hoursOf(it.time, it.minutes);
      return {
        gesture: { do: 'edit_routine', id: it.id, edit },
        facts: r.facts,
        assumed: r.assumed,
        duplicate: true,
        view: {
          kind: 'edit_routine',
          title: next.title,
          ...(edit.title === undefined ? {} : { was: it.title }),
          minutes: next.minutes,
          routine: true,
          hours,
          ...(hours === wasHours ? {} : { wasHours }),
          days: next.days,
          ...(edit.days === undefined ? {} : { wasDays: it.days }),
          ...(next.checklist.length === 0 ? {} : { checklist: next.checklist }),
        },
      };
    },
    async make(hands, user, gesture, _made, trace, now) {
      const g = as(gesture, 'edit_routine');
      await hands.routines.update(
        user,
        g.id,
        {
          ...(g.edit.title === undefined ? {} : { title: g.edit.title }),
          ...(g.edit.time === undefined ? {} : { time: g.edit.time }),
          ...(g.edit.minutes === undefined
            ? {}
            : { durationMinutes: g.edit.minutes }),
          ...(g.edit.days === undefined ? {} : { days: g.edit.days }),
          ...(g.edit.checklist === undefined
            ? {}
            : { checklist: g.edit.checklist }),
        },
        trace,
        now,
      );
      return g.id;
    },
    line: (_drawing, draft, id) => lineOf(draft, id),
  },
  {
    name: 'set_work_day',
    domain: 'routine',
    does: 'The working day given other hours, as the Menu sets it: the queue is laid out inside them, and nothing begins outside them.',
    args: { opens: true, closes: true },
    required: ['opens', 'closes'],
    resolve(r, item) {
      const start = parseMinuteOfDay(item.opens);
      const end = parseMinuteOfDay(item.closes);
      if (start === undefined || end === undefined) {
        throw new Refusal(
          'set_work_day needs opens and closes as HH:mm (closes may be 24:00).',
        );
      }
      if (end - start < MIN_WORK_DAY_MINUTES) {
        throw new Refusal(
          'The working day must close at least an hour after it opens, on the same day.',
        );
      }
      const was = r.board.day.workDay;
      if (was.start === start && was.end === end) {
        throw new Refusal('The working day already has these hours.');
      }
      return {
        gesture: { do: 'set_work_day', start, end },
        facts: r.facts,
        assumed: r.assumed,
        duplicate: true,
        view: {
          kind: 'set_work_day',
          title: WORK_DAY_TITLE,
          minutes: end - start,
          hours: `${formatMinuteOfDay(start)}–${formatMinuteOfDay(end)}`,
          wasHours: `${formatMinuteOfDay(was.start)}–${formatMinuteOfDay(was.end)}`,
        },
      };
    },
    async make(hands, user, gesture) {
      const g = as(gesture, 'set_work_day');
      const day = { start: g.start, end: g.end };
      await hands.users.setWorkDay(user.id, day);
      // The changes after it, and the day read after them, lay the queue
      // out inside the new hours: every reader takes them from the user.
      user.workDay = day;
      return user.id;
    },
    line: (_drawing, draft) => lineOf(draft),
  },
];

/** The card's line for a change of Rotina: what resolving wrote down. */
function lineOf(draft: Draft, id?: string): PlanChange {
  return {
    ...draft.view!,
    ...(id === undefined ? {} : { id }),
    routine: draft.view!.routine ?? false,
  };
}

/** The routine under the ref [said], refused when the board has none. */
function routineOf(r: Resolving, said: unknown): BoardRoutine {
  const it = r.board.routine(text(said));
  if (it === undefined) {
    throw new Refusal(
      `No routine ${JSON.stringify(said)}. Use a routine ref from the board (r1).`,
    );
  }
  return it;
}

/**
 * Refuses a routine at [time] for [minutes] on [days] that would sit on
 * another one on a day both fall on: two fixed blocks at once.
 */
function clash(
  r: Resolving,
  self: string | undefined,
  time: string,
  minutes: number,
  days: RoutineDays,
): void {
  const start = parseMinuteOfDay(time)!;
  const end = start + minutes;
  const other = r.board.routines.find((it) => {
    if (it.id === self) return false;
    const shared = it.days === 'daily' || days === 'daily' || it.days === days;
    const from = parseMinuteOfDay(it.time)!;
    return shared && from < end && from + it.minutes > start;
  });
  if (other === undefined) return;
  throw new Refusal(
    `${time} for ${minutes} min would sit on ${other.ref} "${other.title}" (${hoursOf(other.time, other.minutes)}, ${other.days}), a routine: two fixed blocks at once. Ask the person for another hour, or change ${other.ref} in the same plan.`,
  );
}

/** "07:00–07:45". */
function hoursOf(time: string, minutes: number): string {
  return `${time}–${formatMinuteOfDay(parseMinuteOfDay(time)! + minutes)}`;
}

/** [value] as `HH:mm` before midnight, or undefined. */
function timeOf(value: unknown): string | undefined {
  const minute = parseMinuteOfDay(value);
  return minute === undefined || minute >= 24 * 60
    ? undefined
    : formatMinuteOfDay(minute);
}

/** A routine's length, 5 minutes to the whole working day, when given. */
function lengthOf(value: unknown): number | undefined {
  if (typeof value !== 'number' || !Number.isFinite(value)) return undefined;
  return Math.min(MAX_ROUTINE_MINUTES, Math.max(5, Math.round(value)));
}

/** A checklist, its items trimmed, refused when Rotina would refuse it. */
function checklistOf(value: unknown): string[] | undefined {
  if (value === undefined) return undefined;
  if (!Array.isArray(value)) {
    throw new Refusal('checklist is a list of item titles.');
  }
  const items = value
    .filter((it): it is string => typeof it === 'string')
    .map((it) => it.trim())
    .filter((it) => it !== '');
  if (
    items.length > MAX_CHECKLIST_ITEMS ||
    items.some((it) => it.length > MAX_CHECKLIST_TITLE)
  ) {
    throw new Refusal(
      `A checklist has at most ${MAX_CHECKLIST_ITEMS} items of at most ${MAX_CHECKLIST_TITLE} characters.`,
    );
  }
  return items;
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}
