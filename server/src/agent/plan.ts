import { randomUUID } from 'crypto';
import { CalendarEvent } from '../calendar/calendar.types';
import { Task } from '../tasks/task.types';

/**
 * How a change reads on the plan card. What the agent may do is [Gesture]:
 * this is only what the card draws.
 */
export type ChangeKind =
  'add_task' | 'move_task' | 'add_event' | 'move_event' | 'to_backlog';

/** One line of a plan, as the app draws it. */
export interface PlanChange {
  kind: ChangeKind;
  /** The card it moves. Absent for what it adds. */
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
   * packs it now. Neither named is the end of the queue.
   */
  place?: { after?: string; before?: string };
}

/** Something new a gesture writes down. */
export interface NewThing {
  title: string;
  minutes: number;
  /** Whether it is a fixed block (an event) rather than a task. */
  fixed: boolean;
}

/**
 * One change, as the gesture a person could have made by hand, with every
 * reference already resolved to an id. It is what the dry run makes and what
 * Aplicar makes, through the same code, so the two cannot disagree.
 *
 * - `place`: a place in the queue, by the cards around it, as a drop between
 *   them. Under a card that keeps an hour it is that card's end plus the
 *   pause, as a drop right under it is.
 * - `at_hour`: an hour of its own (an anchor for a task, the hour itself for
 *   a fixed block), as a drop in free room.
 * - `to_backlog`: into Depois eu priorizo, at its end.
 * - `swap`: two tasks trade places, as a long drag onto another card.
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
  | { do: 'swap'; id: string; with: string };

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

/** What applying one change did, so undoing it is exact. */
export type Undo =
  | { kind: 'remove_task'; id: string }
  | { kind: 'remove_event'; id: string }
  | { kind: 'restore_task'; task: Task }
  | { kind: 'restore_event'; event: CalendarEvent };

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

/** How long a plan can wait for its answer. */
const PLAN_TTL_MS = 2 * 60 * 60_000;

/**
 * The plans waiting for an answer, and the ones that can still be undone.
 *
 * In memory, like the calendar cache: one server process owns them, which is
 * the deployment. A plan lost to a restart is a plan the user asks for again.
 */
export class PlanStore {
  private readonly _plans = new Map<string, Plan>();

  constructor(private readonly _now: () => number = Date.now) {}

  put(
    userId: string,
    made: Pick<Plan, 'gestures' | 'changes' | 'pushed' | 'assumed'>,
  ): Plan {
    this._prune();

    const plan: Plan = {
      id: randomUUID(),
      userId,
      ...made,
      createdAt: this._now(),
    };
    this._plans.set(plan.id, plan);

    return plan;
  }

  /** [userId]'s plan [id], when it is theirs and still fresh. */
  get(userId: string, id: string): Plan | undefined {
    const plan = this._plans.get(id);
    if (plan === undefined || plan.userId !== userId) return undefined;
    if (this._now() - plan.createdAt > PLAN_TTL_MS) return undefined;

    return plan;
  }

  /**
   * Whether another answer to the same question was already applied: a
   * quick reply beside [plan], or the plan a quick reply was offered beside.
   */
  answered(plan: Plan): boolean {
    const group = plan.group ?? plan.id;
    for (const other of this._plans.values()) {
      if (other.id === plan.id || other.applied === undefined) continue;
      if (other.id === group || other.group === group) return true;
    }

    return false;
  }

  private _prune(): void {
    const now = this._now();
    for (const [id, plan] of this._plans) {
      if (now - plan.createdAt > PLAN_TTL_MS) this._plans.delete(id);
    }
  }
}
