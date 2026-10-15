import { randomUUID } from 'crypto';
import { CalendarEvent } from '../calendar/calendar.types';
import { Task } from '../tasks/task.types';

/**
 * What the agent may do to the day, and nothing else.
 *
 * Four kinds of change, each one a thing the user can already do by hand:
 * write a task down at an hour, give a task an hour, write a fixed block
 * down, give a fixed block another hour. The agent never removes anything,
 * and never touches what has begun.
 */
export type ChangeKind = 'add_task' | 'move_task' | 'add_event' | 'move_event';

export const CHANGE_KINDS: readonly ChangeKind[] = [
  'add_task',
  'move_task',
  'add_event',
  'move_event',
];

/** One line of a plan, as the app draws it. */
export interface PlanChange {
  kind: ChangeKind;
  /** The card it moves. Absent for what it adds. */
  id?: string;
  title: string;
  minutes: number;
  /** ISO 8601, the hour it will have. */
  at: string;
  /** ISO 8601, the hour it had, for a move. Absent from the backlog. */
  before?: string;
  /** Whether it is a day of a routine. */
  routine: boolean;
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
  /** Short lines the user sees ticked off: what the agent found. */
  findings: string[];
  changes: PlanChange[];
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

  put(userId: string, findings: string[], changes: PlanChange[]): Plan {
    this._prune();

    const plan: Plan = {
      id: randomUUID(),
      userId,
      findings,
      changes,
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

  private _prune(): void {
    const now = this._now();
    for (const [id, plan] of this._plans) {
      if (now - plan.createdAt > PLAN_TTL_MS) this._plans.delete(id);
    }
  }
}
