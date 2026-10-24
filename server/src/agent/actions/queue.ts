import { intervalOf } from '../../events/event-sections';
import {
  Day,
  inList,
  intervalOfTask,
  isAnchored,
} from '../../events/timeline.service';
import { addMinutes, BLOCK_GAP_MINUTES } from '../../time/work-hours';
import { formatTimeIn, instantOf } from '../../time/zone';
import { BoardCard } from '../board';
import type { Made } from '../gestures';
import { Gesture, NewThing, PlanChange } from '../plan';
import { Action, as, Draft, Drawing, Refusal, Resolving } from './action';

/** How long something new takes when nobody said. */
const DEFAULT_MINUTES = 30;

/**
 * The day's own gestures: a place in the queue, an hour, the first free
 * room, the backlog, a swap. Each is a drag the person could have made.
 */
export const QUEUE: Action[] = [
  {
    name: 'place',
    domain: 'queue',
    does: 'A place in the queue, between cards, with no hour of its own.',
    args: { ref: true, new: true, after: true, before: true, duplicate: true },
    resolve(r, item) {
      const { card, thing, duplicate, target } = subject(r, item);
      if (card?.kind === 'event' || thing?.fixed === true) {
        throw new Refusal(
          'A fixed event takes an hour, not a place in the queue: use at_hour.',
        );
      }
      const after = r.card(item.after, 'after');
      const before = r.card(item.before, 'before');
      if ((after ?? before)?.id === card?.id && card !== undefined) {
        throw new Refusal('A card cannot be placed next to itself.');
      }
      if (after?.backlog === true || before?.backlog === true) {
        throw new Refusal(
          'Backlog cards have no place in the queue: name cards from the day.',
        );
      }
      if (after === undefined && before === undefined)
        r.assumed.push({ kind: 'end_of_queue' });

      return {
        gesture: {
          do: 'place',
          ...target,
          after: after?.id,
          before: before?.id,
        },
        facts: r.facts,
        assumed: r.assumed,
        card,
        place: { after: after?.title, before: before?.title },
        duplicate,
        ...artifactView(r, thing),
      };
    },
    async make(hands, user, gesture, made, trace, now) {
      const g = as(gesture, 'place');
      const day = await hands.timeline.day(user, 1, now);
      const where = placeOf(day, g.id, g.after, g.before);

      if (g.new !== undefined) {
        return hands.layout.createTask(
          user,
          {
            ...created(g.new, made),
            backlog: false,
            ...('at' in where
              ? { notBefore: where.at.toISOString() }
              : { index: where.index }),
          },
          trace,
          now,
        );
      }

      const id = g.id!;
      await hands.layout.moveTask(
        user,
        'at' in where
          ? {
              taskId: id,
              index: indexAt(day, where.at, id),
              after: where.at.toISOString(),
            }
          : { taskId: id, index: where.index },
        trace,
        now,
      );
      return id;
    },
    line: lineOf,
  },
  {
    name: 'at_hour',
    domain: 'queue',
    does: 'An hour of its own for a task or an event, on a day.',
    args: { ref: true, new: true, day: true, time: true, duplicate: true },
    required: ['day', 'time'],
    resolve(r, item) {
      const { board, now } = r;
      const { card, thing, duplicate, target } = subject(r, item);
      const day = r.day(item.day);
      const time =
        typeof item.time === 'string'
          ? /^(\d{1,2}):(\d{2})$/.exec(item.time.trim())
          : null;
      if (time === null || Number(time[1]) > 23 || Number(time[2]) > 59) {
        throw new Refusal(
          `at_hour needs time as HH:mm, got ${String(item.time)}.`,
        );
      }
      const [year, month, date] = day.split('-').map(Number);
      const at = instantOf(
        {
          year,
          month,
          day: date,
          hour: Number(time[1]),
          minute: Number(time[2]),
          second: 0,
        },
        board.zone,
      );
      if (at.getTime() < now.getTime() - 60_000) {
        throw new Refusal(
          `${board.when(at)} has already passed. Ask the person for another hour.`,
        );
      }

      const fixed = thing?.fixed === true || card?.kind === 'event';
      const window = board.window(day);
      const minutes = thing?.minutes ?? card!.minutes;
      if (
        !fixed &&
        (at < window.start || addMinutes(at, minutes) > window.end)
      ) {
        throw new Refusal(
          `${board.when(at)} is outside the working day (${formatTimeIn(window.start, board.zone)}–${formatTimeIn(window.end, board.zone)}): nothing is scheduled there. Ask the person.`,
        );
      }

      return {
        gesture: { do: 'at_hour', ...target, at: at.toISOString() },
        facts: r.facts,
        assumed: r.assumed,
        card,
        duplicate,
        ...artifactView(r, thing),
      };
    },
    async make(hands, user, gesture, made, trace, now) {
      const g = as(gesture, 'at_hour');
      const { layout, tasks, calendar } = hands;

      if (g.new?.fixed === true) {
        return layout.createEvent(
          user,
          {
            title: g.new.title,
            durationMinutes: g.new.minutes,
            startTime: g.at,
          },
          trace,
        );
      }

      if (g.new !== undefined) {
        return layout.createTask(
          user,
          { ...created(g.new, made), backlog: false, notBefore: g.at },
          trace,
          now,
        );
      }

      const id = g.id!;
      if ((await tasks.get(user, id)) === undefined) {
        if ((await calendar.find(user, id)) === undefined) {
          throw new Error(`No card "${id}"`);
        }
        await layout.editEvent(user, id, { startTime: g.at }, trace, now);
        return id;
      }

      const day = await hands.timeline.day(user, 1, now);
      await layout.moveTask(
        user,
        { taskId: id, index: indexAt(day, new Date(g.at), id), after: g.at },
        trace,
        now,
      );
      return id;
    },
    line: lineOf,
  },
  {
    name: 'first_free',
    domain: 'queue',
    does: 'The first free hour on a day that fits it.',
    args: { ref: true, new: true, day: true, duplicate: true },
    resolve(r, item) {
      const { board } = r;
      const { card, thing, duplicate, target } = subject(r, item);
      if (item.day === undefined || item.day === '')
        r.assumed.push({ kind: 'today' });
      const day = r.day(item.day ?? 'hoje');
      if (board.over(day)) {
        throw new Refusal(
          `The working day of ${board.dayLabel(day)} is over: nothing more fits. Ask the person whether amanhã will do.`,
        );
      }
      const minutes = thing?.minutes ?? card!.minutes;
      const room = board
        .free(day)
        .find(
          (it) => it.end.getTime() - it.start.getTime() >= minutes * 60_000,
        );
      if (room === undefined) {
        throw new Refusal(
          `There are no ${minutes} free minutes ${board.dayLabel(day)}. Ask the person.`,
        );
      }
      r.facts.push(
        `Livre ${board.dayLabel(day)}: ${formatTimeIn(room.start, board.zone)}–${formatTimeIn(room.end, board.zone)}`,
      );

      // Made as the drop in that free room it is.
      return {
        gesture: { do: 'at_hour', ...target, at: room.start.toISOString() },
        facts: r.facts,
        assumed: r.assumed,
        card,
        duplicate,
        ...artifactView(r, thing),
      };
    },
  },
  {
    name: 'to_backlog',
    domain: 'queue',
    does: 'Into Para depois, at its end.',
    args: { ref: true, new: true, duplicate: true },
    resolve(r, item) {
      const { card, thing, duplicate, target } = subject(r, item);
      if (card?.kind === 'event' || thing?.fixed === true) {
        throw new Refusal('Only tasks go to the backlog, never a fixed event.');
      }
      if (card?.backlog === true) {
        throw new Refusal(`${card.ref} is already in the backlog.`);
      }
      return {
        gesture: { do: 'to_backlog', ...target },
        facts: r.facts,
        assumed: r.assumed,
        card,
        duplicate,
        ...artifactView(r, thing),
      };
    },
    async make(hands, user, gesture, made, trace, now) {
      const g = as(gesture, 'to_backlog');
      if (g.new !== undefined) {
        return hands.layout.createTask(
          user,
          { ...created(g.new, made), backlog: true },
          trace,
          now,
        );
      }

      const id = g.id!;
      const day = await hands.timeline.day(user, 1, now);
      await hands.layout.moveTask(
        user,
        { taskId: id, backlog: true, index: day.backlog.length },
        trace,
        now,
      );
      return id;
    },
    line: lineOf,
  },
  {
    name: 'swap',
    domain: 'queue',
    does: 'Two tasks trade places.',
    args: { ref: true, with: true },
    required: ['ref', 'with'],
    resolve(r, item) {
      const card = r.card(item.ref, 'ref');
      if (card !== undefined) r.movable(card);
      if (item.new !== undefined && item.new !== null && card !== undefined) {
        throw new Refusal('Give either ref or new, not both.');
      }
      const other = r.card(item.with, 'with');
      if (card === undefined || other === undefined) {
        throw new Refusal('swap needs ref and with, two tasks on the day.');
      }
      r.movable(other);
      for (const it of [card, other]) {
        if (it.kind === 'event' || it.backlog) {
          throw new Refusal(
            `${it.ref} "${it.title}" cannot swap: only tasks on the day trade places.`,
          );
        }
      }
      return {
        gesture: { do: 'swap', id: card.id, with: other.id },
        facts: r.facts,
        assumed: r.assumed,
        card,
        duplicate: item.duplicate === true,
      };
    },
    async make(hands, user, gesture, _made, trace, now) {
      const g = as(gesture, 'swap');
      await hands.layout.swapTasks(user, g.id, g.with, trace, now);
      return g.id;
    },
    line: lineOf,
  },
];

/**
 * The card a change moves (`ref`) or the something new it writes (`new`),
 * read: a length nobody said is the agent's choice, and the card names it.
 */
function subject(
  r: Resolving,
  item: Record<string, unknown>,
): {
  card?: BoardCard;
  thing?: NewThing;
  duplicate: boolean;
  target: { id: string } | { new: NewThing };
} {
  const card = r.card(item.ref, 'ref');
  if (card !== undefined) r.movable(card);

  const rawNew = item.new as Record<string, unknown> | undefined;
  let thing: NewThing | undefined;
  if (rawNew !== undefined && rawNew !== null) {
    if (card !== undefined)
      throw new Refusal('Give either ref or new, not both.');
    const title = typeof rawNew.title === 'string' ? rawNew.title.trim() : '';
    if (title === '') throw new Refusal('new needs a title.');
    const given =
      typeof rawNew.minutes === 'number' && Number.isFinite(rawNew.minutes);
    const minutes = given
      ? Math.min(720, Math.max(5, Math.round(rawNew.minutes as number)))
      : DEFAULT_MINUTES;
    if (!given || !r.lengthSaid) r.assumed.push({ kind: 'minutes', minutes });
    thing = {
      title: title.slice(0, 200),
      minutes,
      fixed: rawNew.fixed === true,
      ...belongsTo(r, rawNew.artifact, rawNew.fixed === true),
    };
  }

  if (card === undefined && thing === undefined) {
    throw new Refusal(
      `${String(item.do)} needs a ref (an existing card) or new (something new).`,
    );
  }
  return {
    card,
    thing,
    duplicate: item.duplicate === true,
    target: card === undefined ? { new: thing! } : { id: card.id },
  };
}

/**
 * The delivery something new belongs to: the one named, one made earlier in
 * the plan, or, on a delivery's page, that one.
 */
function belongsTo(
  r: Resolving,
  value: unknown,
  fixed: boolean,
): Pick<NewThing, 'artifactId' | 'artifactAs'> {
  const said = typeof value === 'string' ? value.trim() : '';
  if (said !== '' && fixed) {
    throw new Refusal('A fixed event belongs to no delivery: only tasks do.');
  }
  if (said !== '') {
    const declared = r.declared.get(said);
    if (declared?.kind === 'artifact') return { artifactAs: said };
    const artifact = r.artifact(said, 'new.artifact')!;
    if (artifact.artifact.doneAt !== undefined) {
      throw new Refusal(
        `${artifact.ref} "${artifact.artifact.title}" was already delivered. Ask the person.`,
      );
    }
    return { artifactId: artifact.artifact.id };
  }
  if (fixed || r.about === undefined || !('artifactId' in r.about)) return {};
  const page = r.board.artifactById(r.about.artifactId);
  return page === undefined || page.artifact.doneAt !== undefined
    ? {}
    : { artifactId: page.artifact.id };
}

/** The line names the delivery something new is written into. */
function artifactView(
  r: Resolving,
  thing: NewThing | undefined,
): Pick<Draft, 'view'> | object {
  if (thing === undefined) return {};
  const title =
    thing.artifactAs !== undefined
      ? r.declared.get(thing.artifactAs)?.title
      : thing.artifactId === undefined
        ? undefined
        : r.board.artifactById(thing.artifactId)?.artifact.title;
  return title === undefined
    ? {}
    : {
        view: {
          kind: 'add_task',
          title: thing.title,
          minutes: thing.minutes,
          artifact: title,
        },
      };
}

/** What [thing] is written down with: its delivery, when it has one. */
function created(thing: NewThing, made: Made) {
  const artifactId =
    thing.artifactId ??
    (thing.artifactAs === undefined ? undefined : made.get(thing.artifactAs));
  return {
    title: thing.title,
    minutes: thing.minutes,
    ...(artifactId === undefined ? {} : { artifactId }),
  };
}

/** How the card draws [draft], made as card [id] on the day the dry run left. */
function lineOf({ after }: Drawing, draft: Draft, id: string): PlanChange {
  const g: Gesture = draft.gesture;
  const thing = 'new' in g ? g.new : undefined;
  const card = draft.card;
  const common = {
    ...(card === undefined ? {} : { id: card.id }),
    title: thing?.title ?? card!.title,
    minutes: thing?.minutes ?? card!.minutes,
    ...(card?.start === undefined ? {} : { before: card.start.toISOString() }),
    routine: card?.routine ?? false,
    ...(draft.view?.artifact === undefined
      ? {}
      : { artifact: draft.view.artifact }),
  };

  if (g.do === 'to_backlog') return { kind: 'to_backlog', ...common };

  const event = after.events.find((it) => it.id === id);
  if (event !== undefined && event.taskId === undefined) {
    return {
      kind: thing === undefined ? 'move_event' : 'add_event',
      ...common,
      at: event.startTime,
    };
  }

  const interval = intervalOfTask(after, id);
  if (interval === undefined) {
    throw new Error(`The dry run lost "${common.title}"`);
  }

  return {
    kind: thing === undefined ? 'move_task' : 'add_task',
    ...common,
    at: interval.start.toISOString(),
    ...(draft.place === undefined ? {} : { place: draft.place }),
  };
}

/**
 * Where a drop between [after] and [before] lands, as the app works it
 * out: a place in the list of tasks, counting the tasks above it; right
 * under a card that keeps an hour (an event, or an anchored task), that
 * card's end plus the pause, since a place in the queue says nothing about
 * where such a card is. Neither named is the end of the queue.
 */
export function placeOf(
  day: Day,
  self: string | undefined,
  after: string | undefined,
  before: string | undefined,
): { index: number } | { at: Date } {
  const list = inList(day).filter((task) => task.id !== self);
  const indexOf = (id: string) => list.findIndex((task) => task.id === id);
  const queued = (id: string) => {
    const task = list.find((it) => it.id === id);
    return task !== undefined && !isAnchored(day, task);
  };

  if (after !== undefined && queued(after))
    return { index: indexOf(after) + 1 };
  if (before !== undefined && indexOf(before) >= 0) {
    return { index: indexOf(before) };
  }

  const above = after === undefined ? undefined : hourOf(day, after);
  if (above !== undefined) {
    return { at: addMinutes(above.end, BLOCK_GAP_MINUTES) };
  }

  const below = before === undefined ? undefined : hourOf(day, before);
  if (below !== undefined) {
    return { index: indexAt(day, below.start, self) };
  }

  return { index: list.length };
}

/** How many tasks of the list start before [at]: a drop's place there. */
function indexAt(day: Day, at: Date, self: string | undefined): number {
  return inList(day).filter(
    (task) =>
      task.id !== self &&
      (intervalOfTask(day, task.id)?.start.getTime() ?? Infinity) <
        at.getTime(),
  ).length;
}

/** The hour card [id] takes on [day], a task or an event. */
function hourOf(day: Day, id: string) {
  const task = intervalOfTask(day, id);
  if (task !== undefined) return task;

  const event = day.events.find((it) => it.id === id);
  return event === undefined ? undefined : intervalOf(event);
}
