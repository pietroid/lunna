import { EventCard } from '../../events/entities/event.entity';

/**
 * One thing to do that has no hour yet.
 *
 * The list is an order and nothing else: no day, no time, no heading. What
 * is at the top is what the user means to get to first, and the one way it
 * gets an hour is being moved onto the timeline, at which point it stops
 * being a thing and becomes a block.
 */
export interface Thing {
  id: string;
  title: string;
  /** How long it will take once it is on the day. */
  durationMinutes: number;
  /** ISO 8601, when it was written down. */
  createdAt: string;
}

/** What moving a thing onto the timeline produced: both lists, as they are. */
export interface ScheduledThing {
  things: Thing[];
  cards: EventCard[];
}
