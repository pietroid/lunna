import { CalendarUser } from '../../calendar/calendar.types';
import { Trace } from '../../common/trace';
import { Day } from '../../events/timeline.service';
import { Board, BoardArtifact, BoardCard } from '../board';
import type { Hands, Made } from '../gestures';
import { Assumption, Gesture, PlanChange } from '../plan';

/**
 * A plan the server will not file, with why, in the model's terms. It goes
 * back to the model as the tool's answer, and the model fixes the plan or
 * asks the person.
 */
export class Refusal extends Error {}

/** What a conversation opened from a page is about. */
export type Subject = { taskId: string } | { artifactId: string };

/** One change of the model's, read: the gesture and what the card says. */
export interface Draft {
  gesture: Gesture;
  /** What the server found resolving it, for the person to read. */
  facts: string[];
  assumed: Assumption[];
  /** The card it moves, when it moves one. */
  card?: BoardCard;
  /** For a place: the titles of the cards around it. */
  place?: { after?: string; before?: string };
  /** Whether it may be a card already there under another name. */
  duplicate: boolean;
  /** The card's line, for what the dry run of the day does not show. */
  view?: Omit<PlanChange, 'routine'> & { routine?: boolean };
}

/** What resolving one change has to hand. */
export interface Resolving {
  board: Board;
  now: Date;
  /** The page the conversation was opened on. */
  about?: Subject;
  /** Whether the person said how long, for a length the model gave. */
  lengthSaid: boolean;
  /**
   * What earlier changes of the same plan made and named (`as`): a delivery
   * or a kind, by that name, with its title.
   */
  declared: Map<string, { kind: 'artifact' | 'kind'; title: string }>;
  facts: string[];
  assumed: Assumption[];
  /** The card [value] names, refused when it names none. */
  card(value: unknown, what: string): BoardCard | undefined;
  /** [card], refused when it may not be moved. */
  movable(card: BoardCard): BoardCard;
  /** The delivery [value] names (`p2`), refused when it names none. */
  artifact(value: unknown, what: string): BoardArtifact | undefined;
  /** The day [value] names, noting what a word like "amanhã" came to. */
  day(value: unknown): string;
}

/** What drawing a change's line has to hand, once the dry run is made. */
export interface Drawing {
  board: Board;
  /** The day the dry run left. */
  after: Day;
  /** Every change of the plan, read. */
  drafts: Draft[];
}

/**
 * One thing the agent can do, declared once: its name (the `do` of a
 * change), its arguments, how a change is read, how it is made and how the
 * plan card draws it. A new control is one of these.
 *
 * `make` calls the **same service method the button calls**, on the person's
 * day or on a sandbox copy of it; nothing else writes.
 */
export interface Action {
  /** The `do` of a change. */
  name: string;
  domain: 'queue' | 'artifact';
  /** What it does, in a line, for the model. */
  does: string;
  /**
   * The arguments it takes, by name ([ARGS]): `true` with their shared
   * description, or a description of its own.
   */
  args: Partial<Record<ArgName, true | string>>;
  required?: ArgName[];
  /** Reads one change into a gesture, refusing what cannot be. */
  resolve(r: Resolving, item: Record<string, unknown>): Draft;
  /** Makes the gesture with [hands]. Absent when another action makes it. */
  make?(
    hands: Hands,
    user: CalendarUser,
    gesture: Gesture,
    made: Made,
    trace: Trace,
    now: Date,
  ): Promise<string>;
  /** The card's line for it, once made as [id] in the dry run. */
  line?(drawing: Drawing, draft: Draft, id: string): PlanChange;
}

/** [gesture] as the kind [name], for an action that makes only that. */
export function as<K extends Gesture['do']>(
  gesture: Gesture,
  name: K,
): Extract<Gesture, { do: K }> {
  if (gesture.do !== name) throw new Error(`Not a ${name}: ${gesture.do}`);
  return gesture as Extract<Gesture, { do: K }>;
}

/** A ref to a card, as the board shows it. */
const REF = {
  type: 'string',
  description: 'A card ref from the board, e.g. "t2", "e1", "b3".',
};

/**
 * Every argument a change may carry, with its schema, in the order the flat
 * schema lists them. An action names the ones it takes.
 */
export const ARGS = {
  ref: { ...REF, description: 'The existing card it moves.' },
  new: {
    type: 'object',
    description: 'Something new, instead of a ref.',
    properties: {
      title: { type: 'string' },
      minutes: {
        type: 'integer',
        minimum: 5,
        maximum: 720,
        description: 'Only when the person said how long.',
      },
      fixed: {
        type: 'boolean',
        description:
          'A fixed event (meeting, appointment) rather than a task. Needs at_hour.',
      },
      artifact: {
        type: 'string',
        description:
          'The delivery it belongs to: its ref (p1), or the "as" of a new_artifact in this plan.',
      },
    },
    required: ['title'],
    additionalProperties: false,
  },
  after: { ...REF, description: 'place: the card right above.' },
  before: {
    ...REF,
    description: 'place: the card right under.',
  },
  day: {
    type: 'string',
    description:
      'at_hour, first_free: "hoje", "amanhã", a weekday, or YYYY-MM-DD.',
  },
  time: { type: 'string', description: 'at_hour: HH:mm.' },
  with: { ...REF, description: 'swap: the other task.' },
  duplicate: {
    type: 'boolean',
    description:
      'Only after the person confirmed a new card with the same name as an existing one is really another one.',
  },
  as: {
    type: 'string',
    description:
      'A name for what this change makes ("n1"), so later changes of the same plan can name it.',
  },
  title: { type: 'string', description: 'The delivery’s name.' },
  kind: {
    type: 'string',
    description:
      'A kind from the catalogue: its ref (k1), its name as the person said it, or the "as" of a new_kind in this plan.',
  },
  deadline: {
    type: 'string',
    description:
      'The day it is due: "hoje", "amanhã", a weekday, or YYYY-MM-DD; "none" takes it away.',
  },
  minutes: {
    type: 'integer',
    minimum: 5,
    description: 'How long it takes in all, only when the person said.',
  },
  value: {
    type: 'integer',
    minimum: 0,
    description: 'What it is worth in whole reais, only when the person said.',
  },
  at: {
    type: 'string',
    enum: ['top', 'end'],
    description: 'Where it enters the queue of deliveries. Defaults to end.',
  },
  name: { type: 'string', description: 'The kind’s name.' },
  shelf: {
    type: 'string',
    description: 'The catalogue shelf it goes on (e.g. "Atendimentos").',
  },
  price: {
    type: 'integer',
    minimum: 0,
    description: 'What one is worth in whole reais, only when the person said.',
  },
  measure: {
    type: 'string',
    enum: ['money', 'count'],
    description: 'money: reais delivered; count: deliveries of one kind.',
  },
  target: {
    type: 'integer',
    minimum: 1,
    description: 'The number to reach: reais, or deliveries.',
  },
  period: { type: 'string', enum: ['week', 'month'] },
  start: {
    type: 'string',
    enum: ['now', 'next'],
    description:
      'Whether it counts from this week or month, or the next. Defaults to now.',
  },
} as const;

export type ArgName = keyof typeof ARGS;
