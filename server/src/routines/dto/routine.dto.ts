/** A routine written down or changed from the menu. Anything left out stays. */
export class RoutineDto {
  title?: string;
  /** "HH:MM". */
  time?: string;
  durationMinutes?: number;
  /** `daily`, `weekdays` or `weekend`. */
  days?: string;
  /** Whether its hour is the point of it. Flexible when not said. */
  fixed?: boolean;
  /** What each day of it is made of, in order. */
  checklist?: string[];
}
