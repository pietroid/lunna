/** A routine written down or changed from the menu. Anything left out stays. */
export class RoutineDto {
  title?: string;
  /** "HH:MM". */
  time?: string;
  durationMinutes?: number;
  /** `daily`, `weekdays` or `weekend`. */
  days?: string;
}
