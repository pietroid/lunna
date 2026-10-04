/**
 * The calendar, as the rest of the server knows it.
 *
 * **This is the only record of when anything happens.** It lives in Postgres
 * and belongs to Lunna; there is no outside calendar to mirror, so an event
 * is the truth about a block of time and nothing else remembers an hour.
 */

/** Who a calendar call is for. */
export interface CalendarUser {
  /** Their Better Auth user id. */
  id: string;
  email?: string;
  name?: string;
  /**
   * The IANA zone their day is measured in.
   *
   * Every piece of arithmetic about when a working day starts, which day a
   * block is on and what a card reads is done in this zone. Absent only in
   * tests and background work, where the server's default stands in.
   */
  timeZone?: string;
}

/** One event on this person's calendar. */
export interface CalendarEvent {
  id: string;
  title: string;
  /** ISO 8601. */
  startTime: string;
  /** ISO 8601. */
  endTime: string;
  /**
   * Whether Lunna booked it.
   *
   * Always true while the calendar is in-house. An event that arrives from
   * an outside calendar is somebody else's arrangement: it is drawn, because
   * the hour is not free, and nothing here ever moves it, renames it or
   * takes it off the day.
   */
  managed: boolean;
  /** Whether the hour is the point of it, so a layout leaves it where it is. */
  fixed: boolean;
  /**
   * ISO 8601, when the block was paused. Absent while it runs.
   *
   * A paused block still owes its work, so its end is dragged along with the
   * clock: every minute it stays paused is a minute later that it finishes,
   * and everything after it moves with it.
   */
  pausedAt?: string;
  /** Seconds of work still owed at the moment it was paused. */
  remainingSeconds?: number;
  /** Seconds spent paused before the current pause, so progress skips them. */
  pausedSeconds?: number;
  /**
   * Whether the user said they began it.
   *
   * A flexible block does not start because its hour came round: it waits
   * for the user to say so, and until they do it slides down the day a
   * minute at a time. Fixed blocks and meetings never wait.
   */
  started?: boolean;
  /**
   * ISO 8601, the earliest a layout may start it.
   *
   * Set when the user asked for later, either by snoozing it or by dropping
   * it into a gap further down the day. Without it the next repack would pull
   * the block straight back to now.
   */
  notBefore?: string;
  /** Free text the user keeps on the block. */
  notes: string;
  /** The routine this is a day of, when it is one. */
  routineId?: string;
  /** Which days it repeats on, when it is a day of a routine. */
  routine?: RoutineDays;
}

/** Which days a routine repeats on. */
export type RoutineDays = 'daily' | 'weekdays' | 'weekend';

export const ROUTINE_DAYS: readonly RoutineDays[] = [
  'daily',
  'weekdays',
  'weekend',
];

/** [value] as routine days, or undefined when it is not one. */
export function routineDaysOf(value: unknown): RoutineDays | undefined {
  return ROUTINE_DAYS.includes(value as RoutineDays)
    ? (value as RoutineDays)
    : undefined;
}

/** One routine, as stored. */
export interface CalendarRoutine {
  id: string;
  title: string;
  /** ISO 8601, the first occurrence. Its wall-clock hour is every day's. */
  startTime: string;
  endTime: string;
  days: RoutineDays;
}
