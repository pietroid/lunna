import { CalendarUser } from '../calendar/calendar.types';
import { PlanChange, Pushed } from './plan';

/** Where a plan an answer proposed ended up. */
export type PlanStatus = 'proposed' | 'applied' | 'undone';

/** A plan as it was proposed, kept with the answer that proposed it. */
export interface StoredPlan {
  id: string;
  changes: PlanChange[];
  pushed: Pushed[];
}

/** One message to write down. */
export interface NewMessage {
  role: 'user' | 'assistant';
  text: string;
  steps?: string[];
  plan?: StoredPlan;
  voiceSeconds?: number;
  at: Date;
}

/** One message, read back. */
export interface StoredMessage {
  role: 'user' | 'assistant';
  text: string;
  steps: string[];
  plan?: StoredPlan;
  planStatus?: PlanStatus;
  voiceSeconds?: number;
  /** ISO 8601. */
  at: string;
}

/** A conversation, its messages in the order they were said. */
export interface Conversation {
  id: string;
  /** ISO 8601, when its first message was said. */
  startedAt: string;
  messages: StoredMessage[];
}

/** What the agent can look the past up by. */
export interface ConversationQuery {
  /** Words the message must contain, any case. */
  text?: string;
  from?: Date;
  until?: Date;
  /** The conversation being had, which the agent already has. */
  exclude?: string;
  limit: number;
}

/** A message the search found, and the conversation it is in. */
export interface FoundMessage extends StoredMessage {
  conversationId: string;
}

/**
 * The conversations with the agent, kept for the person to read back.
 *
 * Postgres in production ([PgConversationStore]); memory in the tests.
 * Nothing here is ever handed to the model as context: a turn knows only the
 * conversation it is in, and the past only through the tool that searches it.
 */
export abstract class ConversationStore {
  abstract append(
    user: CalendarUser,
    conversationId: string,
    messages: NewMessage[],
  ): Promise<void>;

  /** Records what became of the plan [planId]. */
  abstract markPlan(
    user: CalendarUser,
    planId: string,
    status: PlanStatus,
  ): Promise<void>;

  /**
   * Up to [limit] conversations that started before [before] (or at all),
   * the most recent first.
   */
  abstract recent(
    user: CalendarUser,
    before: Date | undefined,
    limit: number,
  ): Promise<Conversation[]>;

  /** Messages matching [query], the most recent first. */
  abstract search(
    user: CalendarUser,
    query: ConversationQuery,
  ): Promise<FoundMessage[]>;
}

/** The conversations, in memory. Behaves like the Postgres store. */
export class MemoryConversationStore extends ConversationStore {
  private readonly _rows: (StoredMessage & {
    userId: string;
    conversationId: string;
  })[] = [];

  append(
    user: CalendarUser,
    conversationId: string,
    messages: NewMessage[],
  ): Promise<void> {
    for (const message of messages) {
      this._rows.push({
        userId: user.id,
        conversationId,
        role: message.role,
        text: message.text,
        steps: message.steps ?? [],
        plan: message.plan,
        planStatus: message.plan === undefined ? undefined : 'proposed',
        voiceSeconds: message.voiceSeconds,
        at: message.at.toISOString(),
      });
    }

    return Promise.resolve();
  }

  markPlan(
    user: CalendarUser,
    planId: string,
    status: PlanStatus,
  ): Promise<void> {
    for (const row of this._rows) {
      if (row.userId === user.id && row.plan?.id === planId) {
        row.planStatus = status;
      }
    }

    return Promise.resolve();
  }

  recent(
    user: CalendarUser,
    before: Date | undefined,
    limit: number,
  ): Promise<Conversation[]> {
    const mine = this._rows
      .filter((row) => row.userId === user.id)
      .sort((a, b) => Date.parse(a.at) - Date.parse(b.at));
    const byId = new Map<string, Conversation>();
    for (const row of mine) {
      const conversation = byId.get(row.conversationId) ?? {
        id: row.conversationId,
        startedAt: row.at,
        messages: [],
      };
      conversation.messages.push(toMessage(row));
      byId.set(row.conversationId, conversation);
    }

    return Promise.resolve(
      [...byId.values()]
        .filter(
          (it) =>
            before === undefined || Date.parse(it.startedAt) < before.getTime(),
        )
        .sort((a, b) => Date.parse(b.startedAt) - Date.parse(a.startedAt))
        .slice(0, limit),
    );
  }

  search(
    user: CalendarUser,
    query: ConversationQuery,
  ): Promise<FoundMessage[]> {
    const words = query.text?.toLowerCase();

    return Promise.resolve(
      this._rows
        .filter(
          (row) =>
            row.userId === user.id &&
            row.conversationId !== query.exclude &&
            (words === undefined || row.text.toLowerCase().includes(words)) &&
            (query.from === undefined ||
              Date.parse(row.at) >= query.from.getTime()) &&
            (query.until === undefined ||
              Date.parse(row.at) < query.until.getTime()),
        )
        .sort((a, b) => Date.parse(b.at) - Date.parse(a.at))
        .slice(0, query.limit)
        .map((row) => ({
          ...toMessage(row),
          conversationId: row.conversationId,
        })),
    );
  }
}

function toMessage(row: StoredMessage): StoredMessage {
  return {
    role: row.role,
    text: row.text,
    steps: row.steps,
    plan: row.plan,
    planStatus: row.planStatus,
    voiceSeconds: row.voiceSeconds,
    at: row.at,
  };
}
