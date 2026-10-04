import { Message } from './message.entity';

/**
 * A thread: a conversation, and nothing else.
 *
 * It has a name, a day it started, the messages in it and whether the user
 * considers it closed. It does not have an hour. When something happens is on
 * the calendar, and a thread that carried a copy of that would be a second
 * answer to a question that already has one — which is exactly what used to
 * let a card claim an hour Google had never heard of.
 *
 * A block of time and the conversation about it meet on the event, which
 * names the thread. Never the other way round.
 */
export class Thread {
  /** The file name on disk, and the id the API addresses it by. */
  slug: string;
  title: string;
  messages: Message[];
  /** Whether the user considers this thread closed. */
  solved: boolean;
  /** When the conversation started, which is also the folder it is in. */
  createdAt: Date;
  /** When the last message landed. */
  updatedAt: Date;
}

/**
 * A thread as a row in a list.
 *
 * What Coisas draws, and the concluded screen with it. The only claim it
 * makes about time is when it was last spoken to, which is the one thing a
 * conversation genuinely knows.
 */
export class ThreadItem {
  slug: string;
  title: string;
  /** The last message's text, trimmed to a single line. */
  preview: string;
  messageCount: number;
  solved: boolean;
  createdAt: Date;
  updatedAt: Date;
}
