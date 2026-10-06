/** What the creation sheet posts when the user writes down a fixed block. */
export class CreateEventDto {
  title?: string;
  durationMinutes?: number;
  /** ISO 8601, the hour that is the point of it. */
  startTime?: string;
}
