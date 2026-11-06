import { Inject, Injectable } from '@nestjs/common';
import { and, eq, gt } from 'drizzle-orm';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { agentSuggestion, AgentSuggestionRow } from '../db/schema';
import {
  HISTORY_LIMIT,
  NewSuggestion,
  Opening,
  PastSuggestion,
  pastOf,
  StoredSuggestion,
  SuggestionAnswer,
  SuggestionKind,
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

  async recent(
    userId: string,
    limit = HISTORY_LIMIT,
  ): Promise<PastSuggestion[]> {
    const current = await this.current(userId);
    if (current === undefined) return [];
    return [pastOf(current), ...(current.history ?? [])].slice(0, limit);
  }

  async put(
    userId: string,
    made: NewSuggestion,
    now: Date,
  ): Promise<StoredSuggestion> {
    const previous = await this.current(userId);
    const history =
      previous === undefined
        ? null
        : [pastOf(previous), ...(previous.history ?? [])].slice(
            0,
            HISTORY_LIMIT,
          );
    const values = {
      kind: made.kind,
      focus: made.focus,
      text: made.text,
      actionLabel: made.action?.label ?? null,
      planId: made.action?.planId ?? null,
      opening: made.opening,
      basis: made.basis,
      workQuality: made.workQuality ?? null,
      followUp: made.followUp ?? null,
      nextAt: made.nextAt ?? null,
      takenAt: null,
      dismissedAt: null,
      answeredAt: null,
      history,
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

  async answer(
    userId: string,
    id: string,
    answer: SuggestionAnswer,
  ): Promise<void> {
    await this._db
      .update(agentSuggestion)
      .set(answer)
      .where(
        and(eq(agentSuggestion.userId, userId), eq(agentSuggestion.id, id)),
      );
  }

  async pending(now: Date): Promise<{ userId: string; nextAt: Date }[]> {
    const rows = await this._db
      .select({
        userId: agentSuggestion.userId,
        nextAt: agentSuggestion.nextAt,
      })
      .from(agentSuggestion)
      .where(gt(agentSuggestion.nextAt, now));

    return rows.map((it) => ({ userId: it.userId, nextAt: it.nextAt! }));
  }
}

function suggestionOf(row: AgentSuggestionRow): StoredSuggestion {
  const when = (it: Date | null) => it ?? undefined;
  const kept: StoredSuggestion = {
    id: row.id,
    userId: row.userId,
    kind: row.kind as SuggestionKind,
    focus: row.focus,
    text: row.text,
    ...(row.planId === null
      ? {}
      : { action: { label: row.actionLabel ?? '', planId: row.planId } }),
    opening: row.opening as Opening,
    basis: row.basis,
    workQuality: row.workQuality ?? undefined,
    followUp: row.followUp ?? undefined,
    nextAt: when(row.nextAt),
    takenAt: when(row.takenAt),
    dismissedAt: when(row.dismissedAt),
    answeredAt: when(row.answeredAt),
    ...(row.history == null ? {} : { history: historyOf(row.history) }),
    createdAt: row.createdAt,
  };
  // Absent rather than undefined, as the memory store keeps them.
  for (const key of Object.keys(kept) as (keyof StoredSuggestion)[]) {
    if (kept[key] === undefined) delete kept[key];
  }
  return kept;
}

function historyOf(history: unknown): PastSuggestion[] {
  return (history as PastSuggestion[]).map((it) => ({
    focus: it.focus,
    kind: it.kind,
    outcome: it.outcome,
    createdAt: new Date(it.createdAt),
  }));
}
