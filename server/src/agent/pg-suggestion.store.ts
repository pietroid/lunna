import { Inject, Injectable } from '@nestjs/common';
import { and, eq, isNull } from 'drizzle-orm';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { agentSuggestion, AgentSuggestionRow } from '../db/schema';
import {
  NewSuggestion,
  Opening,
  StoredSuggestion,
  SuggestionFocus,
  SuggestionStore,
} from './suggestion.store';

/** The suggestions, in Postgres: one row per person. */
@Injectable()
export class PgSuggestionStore extends SuggestionStore {
  constructor(@Inject(DB) private readonly _db: Database) {
    super();
  }

  async current(userId: string): Promise<StoredSuggestion | undefined> {
    const [row] = await this._db
      .select()
      .from(agentSuggestion)
      .where(eq(agentSuggestion.userId, userId));

    return row === undefined ? undefined : suggestionOf(row);
  }

  async put(
    userId: string,
    made: NewSuggestion,
    now: Date,
  ): Promise<StoredSuggestion> {
    const values = {
      focus: made.focus,
      text: made.text,
      actionLabel: made.action?.label ?? null,
      planId: made.action?.planId ?? null,
      opening: made.opening,
      basis: made.basis,
      validUntil: made.validUntil,
      takenAt: null,
      createdAt: now,
    };
    // A new suggestion is a new id, so a conversation opened from the last
    // one does not take this one's opening for its own.
    await this._db
      .delete(agentSuggestion)
      .where(eq(agentSuggestion.userId, userId));
    const [row] = await this._db
      .insert(agentSuggestion)
      .values({ userId, ...values })
      .returning();

    return suggestionOf(row);
  }

  async takeByPlan(userId: string, planId: string, now: Date): Promise<void> {
    await this._db
      .update(agentSuggestion)
      .set({ takenAt: now })
      .where(
        and(
          eq(agentSuggestion.userId, userId),
          eq(agentSuggestion.planId, planId),
          isNull(agentSuggestion.takenAt),
        ),
      );
  }
}

function suggestionOf(row: AgentSuggestionRow): StoredSuggestion {
  return {
    id: row.id,
    userId: row.userId,
    focus: row.focus as SuggestionFocus,
    text: row.text,
    ...(row.planId === null
      ? {}
      : { action: { label: row.actionLabel ?? '', planId: row.planId } }),
    opening: row.opening as Opening,
    basis: row.basis,
    validUntil: row.validUntil,
    ...(row.takenAt === null ? {} : { takenAt: row.takenAt }),
    createdAt: row.createdAt,
  };
}
