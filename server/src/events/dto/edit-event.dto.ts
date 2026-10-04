/** What the detail screen changed about a block. Anything left out stays. */
export class EditEventDto {
  title?: string;
  /** How long the work takes, pauses left out. */
  workMinutes?: number;
  /** ISO 8601. Naming an hour pins the block to it. */
  startTime?: string;
}
