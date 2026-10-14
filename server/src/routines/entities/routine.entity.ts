import { RoutineDays } from '../../calendar/calendar.types';

/**
 * One routine, as the menu draws it.
 *
 * A wall-clock hour and a length rather than two instants: a routine happens
 * at noon every day, and which day counts as the first one is the
 * calendar's business.
 */
export interface Routine {
  /** The recurring event's id. */
  id: string;
  title: string;
  /** "12:30", in the calendar's zone. */
  time: string;
  durationMinutes: number;
  days: RoutineDays;
  /**
   * Whether its hour is the point of it. A fixed routine's days never move;
   * a flexible one's slide when something runs into them, and wait for the
   * user to begin them.
   */
  fixed: boolean;
}

/** What the menu sends to write a routine down or change one. */
export interface RoutineRequest {
  title?: string;
  time?: string;
  durationMinutes?: number;
  days?: RoutineDays;
  fixed?: boolean;
}
