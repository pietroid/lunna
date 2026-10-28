import { randomUUID } from 'crypto';
import { GoalKind, StoredRow } from '../artifacts/artifact.types';
import { CalendarEvent } from '../calendar/calendar.types';
import { Task } from '../tasks/task.types';

/**
 * How a change reads on the plan card. What the agent may do is [Gesture]:
 * this is only what the card draws.
 */
export type ChangeKind =
  | 'add_task'
  | 'move_task'
  | 'add_event'
  | 'move_event'
  | 'to_backlog'
  | 'add_artifact'
  | 'edit_artifact'
  | 'deliver'
  | 'remove_artifact'
  | 'move_artifact'
  | 'add_kind'
  | 'add_goal'
  | 'remove_goal';

/** One line of a plan, as the app draws it. */
export interface PlanChange {
  kind: ChangeKind;
  /** The card or the delivery it changes. Absent for what it adds. */
  id?: string;
  title: string;
  minutes: number;
  /** ISO 8601, the hour it will have. Absent for the backlog. */
  at?: string;
  /** ISO 8601, the hour it had, for a move. Absent from the backlog. */
  before?: string;
  /** Whether it is a day of a routine. */
  routine: boolean;
  /**
   * The place in the queue it takes, by the titles of the cards around it,
   * when it takes one rather than an hour: [at] is then only where the queue
   * packs it now. Neither named is the end of the queue. For a delivery
   * moved, the deliveries around it.
   */
  place?: { after?: string; before?: string };
  /** The name it had, when the change renames it. */
  was?: string;
  /** The delivery a task belongs to, by name. */
  artifact?: string;
  /** A delivery's deadline as the change leaves it, `YYYY-MM-DD`. */
  deadline?: string;
  /** A delivery's deadline before the change. */
  wasDeadline?: string;
  /** What it is worth, in whole reais: a delivery's value, a kind's price, a money goal's target. */
  value?: number;
  /**
   * What goes with it: the tasks a new delivery starts with, the open ones
   * a delivered one leaves, the ones a removed one takes along.
   */
  takes?: string[];
  /** For a kind: the catalogue shelf it goes on. */
  shelf?: string;
  /** For a goal: what it counts, how much, and by which day (`YYYY-MM-DD`). */
  goal?: { kind: GoalKind; target: number; deadline: string };
}

/** Something new a gesture writes down. */
export interface NewThing {
  title: string;
  minutes: number;
  /** Whether it is a fixed block (an event) rather than a task. */
  fixed: boolean;
  /** The delivery it belongs to, by id. */
  artifactId?: string;
  /** The delivery it belongs to, made earlier in the same plan (`as`). */
  artifactAs?: string;
}

/**
 * One change, as the gesture a person could have made by hand, with every
 * reference already resolved to an id. It is what the dry run makes and what
 * Aplicar makes, through the same code, so the two cannot disagree. Each is
 * declared once, in `actions/`.
 *
 * - `place`: a place in the queue, by the cards around it, as a drop between
 *   them. Under a card that keeps an hour it is that card's end plus the
 *   pause, as a drop right under it is.
 * - `at_hour`: an hour of its own (an anchor for a task, the hour itself for
 *   a fixed block), as a drop in free room.
 * - `to_backlog`: into Para depois, at its end.
 * - `swap`: two tasks trade places, as a long drag onto another card.
 * - the deliveries', the catalogue's and the goals', as Entregas makes them.
 */
export type Gesture =
  | {
      do: 'place';
      id?: string;
      new?: NewThing;
      after?: string;
      before?: string;
    }
  | { do: 'at_hour'; id?: string; new?: NewThing; at: string }
  | { do: 'to_backlog'; id?: string; new?: NewThing }
  | { do: 'swap'; id: string; with: string }
  | {
      do: 'new_artifact';
      /** The name later changes of the plan call it by. */
      as?: string;
      title: string;
      typeId?: string;
      /** Its kind, made earlier in the same plan. */
      typeAs?: string;
      deadline?: string;
      minutes?: number;
      value?: number;
      at: 'top' | 'end';
    }
  | {
      do: 'edit_artifact';
      id: string;
      edit: {
        title?: string;
        deadline?: string | null;
        minutes?: number;
        value?: number;
      };
    }
  | { do: 'deliver'; id: string }
  | { do: 'remove_artifact'; id: string; keepTasks: boolean }
  | { do: 'move_artifact'; id: string; after?: string; before?: string }
  | {
      do: 'new_kind';
      as?: string;
      name: string;
      shelf: string;
      minutes: number;
      price?: number;
    }
  | {
      do: 'new_goal';
      target: number;
      /** `YYYY-MM-DD`, its last day. */
      deadline: string;
    }
  | { do: 'remove_goal'; id: string };

/** The something new a gesture writes down, when it writes a card. */
export function newOf(gesture: Gesture): NewThing | undefined {
  return 'new' in gesture ? gesture.new : undefined;
}

/** What a plan took without being told, which its card names. */
export type Assumption =
  | { kind: 'minutes'; minutes: number }
  | { kind: 'today' }
  | { kind: 'end_of_queue' };

/**
 * A task the plan does not name that would start later because of it: the
 * queue flowing on after something put in its way, as it does when the same
 * change is made by hand.
 */
export interface Pushed {
  id: string;
  title: string;
  /** ISO 8601, the hour it has now. */
  before: string;
  /** ISO 8601, the hour it would have. */
  at: string;
}

/** One row a plan may touch, by where it is kept. */
export type Row =
  | { kind: 'task'; row: Task }
  | { kind: 'event'; row: CalendarEvent }
  | StoredRow;

/**
 * One step of taking a plan back: a row written back as it was (`put`,
 * whether it changed or was removed), or one the plan made taken out
 * (`drop`). Read off the stores before and after, so every row a gesture
 * touched comes back, not only the one it named.
 */
export type Undo = { op: 'put'; it: Row } | { op: 'drop'; it: Row };

/**
 * A proposal: changes the agent worked out, which nothing has made yet.
 *
 * Reads run the moment the model asks; writes are only ever proposed. A plan
 * is the proposal, kept here until the user taps Aplicar, and it is the
 * server that writes it, not the model.
 */
export interface Plan {
  id: string;
  userId: string;
  /** What it makes, in order. */
  gestures: Gesture[];
  /** How the card draws it. */
  changes: PlanChange[];
  /** What the plan pushes later, for the person to see before applying. */
  pushed: Pushed[];
  /** What it took without being told. */
  assumed: Assumption[];
  /**
   * The plan whose card this one was offered beside, when it is a quick
   * reply: applying it is what became of that answer.
   */
  group?: string;
  createdAt: number;
  /** Set once applied: how to take it back, and the ids it touched. */
  applied?: { undo: Undo[]; touched: string[] };
}

/** What a plan is filed with. */
export type NewPlan = Pick<
  Plan,
  'gestures' | 'changes' | 'pushed' | 'assumed'
> &
  Pick<Plan, 'group'>;

/** How long a plan can wait for its answer, and be undone. */
export const PLAN_TTL_MS = 2 * 60 * 60_000;

/**
 * The plans waiting for an answer, and the ones that can still be undone.
 *
 * Postgres in production ([PgPlanStore]), so an undo outlives a deploy:
 * a plan may delete a delivery, and its undo is the only way back. Memory in
 * the tests ([MemoryPlanStore]).
 */
export abstract class PlanStore {
  abstract put(userId: string, made: NewPlan): Promise<Plan>;

  /** [userId]'s plan [id], when it is theirs and still fresh. */
  abstract get(userId: string, id: string): Promise<Plan | undefined>;

  /** Writes down what became of [plan]: applied, with its undo, or not. */
  abstract save(plan: Plan): Promise<void>;

  /**
   * Whether another answer to the same question was already applied: a
   * quick reply beside [plan], or the plan a quick reply was offered beside.
   */
  abstract answered(plan: Plan): Promise<boolean>;
}

/** The plans, in memory. Behaves like the Postgres store. */
export class MemoryPlanStore extends PlanStore {
  private readonly _plans = new Map<string, Plan>();

  constructor(private readonly _now: () => number = Date.now) {
    super();
  }

  put(userId: string, made: NewPlan): Promise<Plan> {
    this._prune();

    const plan: Plan = {
      id: randomUUID(),
      userId,
      ...made,
      createdAt: this._now(),
    };
    if (plan.group === undefined) delete plan.group;
    this._plans.set(plan.id, plan);

    return Promise.resolve(plan);
  }

  get(userId: string, id: string): Promise<Plan | undefined> {
    const plan = this._plans.get(id);
    if (plan === undefined || plan.userId !== userId) {
      return Promise.resolve(undefined);
    }
    if (this._now() - plan.createdAt > PLAN_TTL_MS) {
      return Promise.resolve(undefined);
    }

    return Promise.resolve(plan);
  }

  save(plan: Plan): Promise<void> {
    this._plans.set(plan.id, plan);
    return Promise.resolve();
  }

  answered(plan: Plan): Promise<boolean> {
    const group = plan.group ?? plan.id;
    for (const other of this._plans.values()) {
      if (other.id === plan.id || other.applied === undefined) continue;
      if (other.id === group || other.group === group) {
        return Promise.resolve(true);
      }
    }

    return Promise.resolve(false);
  }

  private _prune(): void {
    const now = this._now();
    for (const [id, plan] of this._plans) {
      if (now - plan.createdAt > PLAN_TTL_MS) this._plans.delete(id);
    }
  }
}
