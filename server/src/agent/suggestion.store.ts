import { randomUUID } from 'crypto';
import type { AgentReply } from './agent.service';

/**
 * How a suggestion was written: the fixed `welcome` a new person finds, a
 * `turn` the agent asked itself, or the arithmetic `template` written when
 * that turn could not be had.
 */
export type SuggestionKind = 'welcome' | 'turn' | 'template';

/** What became of a suggestion: made, put away, talked about, or neither. */
export type SuggestionOutcome =
  'taken' | 'dismissed' | 'answered' | 'unanswered';

/** One suggestion, as its successor remembers it. */
export interface PastSuggestion {
  focus: string;
  kind: SuggestionKind;
  outcome: SuggestionOutcome;
  createdAt: Date;
}

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
  /** The hours to look again after an answer, 1–4. */
  followUp?: number;
  /** When the next one is made. Absent for a welcome nobody answered. */
  nextAt?: Date;
  takenAt?: Date;
  dismissedAt?: Date;
  answeredAt?: Date;
  /** The ones before it, newest first: at most [HISTORY_LIMIT]. */
  history?: PastSuggestion[];
  createdAt: Date;
}

/** At most this many past suggestions follow a new one. */
export const HISTORY_LIMIT = 10;

/** What a suggestion is filed with. */
export type NewSuggestion = Omit<
  StoredSuggestion,
  | 'id'
  | 'userId'
  | 'takenAt'
  | 'dismissedAt'
  | 'answeredAt'
  | 'history'
  | 'createdAt'
>;

/** What [it] became, for its successor's history. */
export function pastOf(it: StoredSuggestion): PastSuggestion {
  const outcome: SuggestionOutcome =
    it.takenAt !== undefined
      ? 'taken'
      : it.dismissedAt !== undefined
        ? 'dismissed'
        : it.answeredAt !== undefined
          ? 'answered'
          : 'unanswered';
  return { focus: it.focus, kind: it.kind, outcome, createdAt: it.createdAt };
}

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

  /** The current one first, then its history, newest first, at most [limit]. */
  abstract recent(userId: string, limit?: number): Promise<PastSuggestion[]>;

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

  recent(userId: string, limit = HISTORY_LIMIT): Promise<PastSuggestion[]> {
    const held = this._held.get(userId);
    if (held === undefined) return Promise.resolve([]);
    return Promise.resolve(
      [pastOf(held), ...(held.history ?? [])].slice(0, limit),
    );
  }

  put(
    userId: string,
    made: NewSuggestion,
    now: Date,
  ): Promise<StoredSuggestion> {
    const old = this._held.get(userId);
    const kept: StoredSuggestion = {
      id: randomUUID(),
      userId,
      ...made,
      createdAt: now,
      ...(old === undefined
        ? {}
        : {
            history: [pastOf(old), ...(old.history ?? [])].slice(
              0,
              HISTORY_LIMIT,
            ),
          }),
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
