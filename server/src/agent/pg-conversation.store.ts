import { Inject, Injectable } from '@nestjs/common';
import {
  and,
  asc,
  desc,
  eq,
  gte,
  ilike,
  inArray,
  lt,
  ne,
  sql,
} from 'drizzle-orm';
import { CalendarUser } from '../calendar/calendar.types';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { agentMessage, AgentMessageRow } from '../db/schema';
import {
  Conversation,
  ConversationQuery,
  ConversationStore,
  FoundMessage,
  NewMessage,
  PlanStatus,
  StoredMessage,
  StoredPlan,
} from './conversation.store';

/** The conversations, in Postgres. */
@Injectable()
export class PgConversationStore extends ConversationStore {
  constructor(@Inject(DB) private readonly _db: Database) {
    super();
  }

  async append(
    user: CalendarUser,
    conversationId: string,
    messages: NewMessage[],
  ): Promise<void> {
    if (messages.length === 0) return;

    await this._db.insert(agentMessage).values(
      messages.map((message) => ({
        userId: user.id,
        conversationId,
        role: message.role,
        text: message.text,
        steps: message.steps ?? [],
        plan: message.plan ?? null,
        planId: message.plan?.id ?? null,
        planStatus: message.plan === undefined ? null : 'proposed',
        voiceSeconds: message.voiceSeconds ?? null,
        createdAt: message.at,
      })),
    );
  }

  async markPlan(
    user: CalendarUser,
    planId: string,
    status: PlanStatus,
  ): Promise<void> {
    await this._db
      .update(agentMessage)
      .set({ planStatus: status })
      .where(
        and(eq(agentMessage.userId, user.id), eq(agentMessage.planId, planId)),
      );
  }

  async recent(
    user: CalendarUser,
    before: Date | undefined,
    limit: number,
  ): Promise<Conversation[]> {
    const started = sql<Date>`min(${agentMessage.createdAt})`;
    const heads = await this._db
      .select({ id: agentMessage.conversationId, started })
      .from(agentMessage)
      .where(eq(agentMessage.userId, user.id))
      .groupBy(agentMessage.conversationId)
      .having(
        before === undefined
          ? undefined
          : sql`${started} < ${before.toISOString()}::timestamptz`,
      )
      .orderBy(desc(started))
      .limit(limit);
    if (heads.length === 0) return [];

    const rows = await this._db
      .select()
      .from(agentMessage)
      .where(
        and(
          eq(agentMessage.userId, user.id),
          inArray(
            agentMessage.conversationId,
            heads.map((it) => it.id),
          ),
        ),
      )
      .orderBy(asc(agentMessage.createdAt));

    return heads.map((head) => {
      const messages = rows
        .filter((row) => row.conversationId === head.id)
        .map(toMessage);

      return { id: head.id, startedAt: messages[0].at, messages };
    });
  }

  async search(
    user: CalendarUser,
    query: ConversationQuery,
  ): Promise<FoundMessage[]> {
    const text = query.text?.replace(/[\\%_]/g, (it) => `\\${it}`);
    const rows = await this._db
      .select()
      .from(agentMessage)
      .where(
        and(
          eq(agentMessage.userId, user.id),
          query.exclude === undefined
            ? undefined
            : ne(agentMessage.conversationId, query.exclude),
          text === undefined
            ? undefined
            : ilike(agentMessage.text, `%${text}%`),
          query.from === undefined
            ? undefined
            : gte(agentMessage.createdAt, query.from),
          query.until === undefined
            ? undefined
            : lt(agentMessage.createdAt, query.until),
        ),
      )
      .orderBy(desc(agentMessage.createdAt))
      .limit(query.limit);

    return rows.map((row) => ({
      ...toMessage(row),
      conversationId: row.conversationId,
    }));
  }
}

function toMessage(row: AgentMessageRow): StoredMessage {
  return {
    role: row.role === 'assistant' ? 'assistant' : 'user',
    text: row.text,
    steps: row.steps,
    plan: (row.plan ?? undefined) as StoredPlan | undefined,
    planStatus: (row.planStatus ?? undefined) as PlanStatus | undefined,
    voiceSeconds: row.voiceSeconds ?? undefined,
    at: row.createdAt.toISOString(),
  };
}
