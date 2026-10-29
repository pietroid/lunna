/**
 * What a reminder is for.
 *
 * `askStart`, `askEnd` and `headsUp` follow a block; a tap opens the app on
 * a sheet that asks the same thing: Confirmar, +10 min, or talk it over.
 * `askStart` is a block's hour arriving (a task waits for the answer; a
 * fixed block starts anyway), `askEnd` its end, and each comes back once,
 * ten minutes later, until it is answered.
 * `headsUp` comes a quarter of an hour before a fixed block that something
 * runs right up to. `morning` and `evening` follow the clock alone: one at
 * the start of the day and one near its end, every day, whatever is booked.
 */
export type NotificationKind =
  'askStart' | 'askEnd' | 'headsUp' | 'morning' | 'evening';

/** Which end of the block an ask is about, so the buttons know what to write. */
export type NotificationEdge = 'start' | 'end';

/** Whether the card an ask is about is a task or a fixed block. */
export type NotificationCard = 'task' | 'event';

/** One reminder the phone should have queued. */
export class NotificationItem {
  /**
   * Stable and deterministic. The same reminder always has the same id, and
   * anything that changes what it says or when it fires changes the id, which
   * is what lets the phone reconcile by comparing two sets.
   */
  id: string;
  kind: NotificationKind;
  /** ISO 8601 with the offset of [NotificationPlan.timeZone] at that instant. */
  fireAt: string;
  /** Final text. The app shows it as is and never concatenates. */
  title: string;
  body: string;
  /** Whether it should break through a Focus mode. */
  timeSensitive: boolean;
  /**
   * The card it is about, which a tap opens and the buttons answer for:
   * the task's id for a task, begun or not, and the event's for an event.
   * Named for the event it once always was.
   */
  eventId?: string;
  /** Whether [eventId] is a task or a fixed block; set on every ask. */
  card?: NotificationCard;
  /**
   * Which end of the block an ask is about; set on every ask. With [card]
   * it names the route each of the sheet's answers posts to: Confirmar is start or done,
   * +10 min is snooze, delay or extend.
   */
  edge?: NotificationEdge;
}

/** Every reminder ahead, soonest first. */
export class NotificationPlan {
  /** ISO 8601, when the server worked this out. */
  generatedAt: string;
  /** The IANA zone every [NotificationItem.fireAt] was written in. */
  timeZone: string;
  items: NotificationItem[];
}
