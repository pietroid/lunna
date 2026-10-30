import { randomUUID } from 'crypto';
import type { AgentReply } from './agent.service';

/**
 * How a suggestion was written: the fixed `welcome` a new person finds, a
 * `turn` the agent asked itself, or the arithmetic `template` written when
 * that turn could not be had.
 */
export type SuggestionKind = 'welcome' | 'turn' | 'template';

/** The agent's first message in a conversation opened from a suggestion. */
export type Opening = Omit<AgentReply, 'conversationId'>;

/** A suggestion, as it is kept. */
export interface StoredSuggestion {
  id: string;
  userId: string;
  kind: SuggestionKind;
  /** Its Work Quality topic, or a template's focus. */
  focus: string;
  text: string;
  /** The plan Aplicar makes, when it has one. */
  action?: { label: string; planId: string };
  opening: Opening;
  /** What it is about, hashed: a change to it hides it. */
  basis: string;
  /** The Work Quality score it was made at, 0–7. */
  workQuality?: number;
  /** The hours to look again after an answer, 3–24. */
  followUp?: number;
  /** When the next one is made. Absent for a welcome nobody answered. */
  nextAt?: Date;
  takenAt?: Date;
  dismissedAt?: Date;
  answeredAt?: Date;
  createdAt: Date;
}

/** What a suggestion is filed with. */
export type NewSuggestion = Omit<
  StoredSuggestion,
  'id' | 'userId' | 'takenAt' | 'dismissedAt' | 'answeredAt' | 'createdAt'
>;

/** An answer to a suggestion: what was said, and when the next one comes. */
export type SuggestionAnswer = Partial<
  Pick<StoredSuggestion, 'takenAt' | 'dismissedAt' | 'answeredAt'>
> & { nextAt: Date };

/**
 * The suggestion each person was last offered: one each, a new one
 * replacing it. Postgres in production ([PgSuggestionStore]), memory in
 * the tests ([MemorySuggestionStore]).
 */
export abstract class SuggestionStore {
  /** [userId]'s suggestion, answered or not, whenever it was made. */
  abstract current(userId: string): Promise<StoredSuggestion | undefined>;

  /** Files [made] as [userId]'s suggestion, in place of the last one. */
  abstract put(
    userId: string,
    made: NewSuggestion,
    now: Date,
  ): Promise<StoredSuggestion>;

  /** Writes [answer] down on [userId]'s suggestion [id], if it is still theirs. */
  abstract answer(
    userId: string,
    id: string,
    answer: SuggestionAnswer,
  ): Promise<void>;

  /** Every suggestion whose next one is due after [now]: what the timers wait for. */
  abstract pending(now: Date): Promise<{ userId: string; nextAt: Date }[]>;
}

/** The suggestions, in memory. Behaves like the Postgres store. */
export class MemorySuggestionStore extends SuggestionStore {
  private readonly _held = new Map<string, StoredSuggestion>();

  current(userId: string): Promise<StoredSuggestion | undefined> {
    const held = this._held.get(userId);
    return Promise.resolve(held === undefined ? undefined : { ...held });
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

    return Promise.resolve({ ...kept });
  }

  answer(userId: string, id: string, answer: SuggestionAnswer): Promise<void> {
    const held = this._held.get(userId);
    if (held?.id === id) Object.assign(held, answer);

    return Promise.resolve();
  }

  pending(now: Date): Promise<{ userId: string; nextAt: Date }[]> {
    return Promise.resolve(
      [...this._held.values()]
        .filter((it) => it.nextAt !== undefined && it.nextAt > now)
        .map((it) => ({ userId: it.userId, nextAt: it.nextAt! })),
    );
  }
}
