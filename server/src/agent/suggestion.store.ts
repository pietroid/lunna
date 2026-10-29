import { randomUUID } from 'crypto';
import type { AgentReply } from './agent.service';

/** What a suggestion is about, in the order the agent looks. */
export type SuggestionFocus = 'goal' | 'delivery' | 'routine';

/** The agent's first message in a conversation opened from a suggestion. */
export type Opening = Omit<AgentReply, 'conversationId'>;

/** A suggestion, as it is kept. */
export interface StoredSuggestion {
  id: string;
  userId: string;
  focus: SuggestionFocus;
  text: string;
  /** The button and its plan, when it can be taken from the card. */
  action?: { label: string; planId: string };
  opening: Opening;
  /** What it was made from, hashed: a change to it makes another. */
  basis: string;
  validUntil: Date;
  takenAt?: Date;
  createdAt: Date;
}

/** What a suggestion is filed with. */
export type NewSuggestion = Omit<
  StoredSuggestion,
  'id' | 'userId' | 'takenAt' | 'createdAt'
>;

/**
 * The suggestion each person was last offered: one each, a new one
 * replacing it. Postgres in production ([PgSuggestionStore]), memory in
 * the tests ([MemorySuggestionStore]).
 */
export abstract class SuggestionStore {
  /** [userId]'s suggestion, taken or not, whenever it was made. */
  abstract current(userId: string): Promise<StoredSuggestion | undefined>;

  /** Files [made] as [userId]'s suggestion, in place of the last one. */
  abstract put(
    userId: string,
    made: NewSuggestion,
    now: Date,
  ): Promise<StoredSuggestion>;

  /** Marks taken the suggestion whose action is [planId], if one is. */
  abstract takeByPlan(userId: string, planId: string, now: Date): Promise<void>;
}

/** The suggestions, in memory. Behaves like the Postgres store. */
export class MemorySuggestionStore extends SuggestionStore {
  private readonly _held = new Map<string, StoredSuggestion>();

  current(userId: string): Promise<StoredSuggestion | undefined> {
    return Promise.resolve(this._held.get(userId));
  }

  put(
    userId: string,
    made: NewSuggestion,
    now: Date,
  ): Promise<StoredSuggestion> {
    const kept: StoredSuggestion = {
      id: randomUUID(),
      userId,
      ...made,
      createdAt: now,
    };
    this._held.set(userId, kept);

    return Promise.resolve(kept);
  }

  takeByPlan(userId: string, planId: string, now: Date): Promise<void> {
    const held = this._held.get(userId);
    if (held?.action?.planId === planId && held.takenAt === undefined) {
      held.takenAt = now;
    }

    return Promise.resolve();
  }
}
