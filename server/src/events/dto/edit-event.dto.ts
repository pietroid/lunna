/** What the detail screen changed about a block. Anything left out stays. */
export class EditEventDto {
  title?: string;
  /** How long the work takes, pauses left out. */
  workMinutes?: number;
  /** ISO 8601. A new hour, for a fixed block. Tasks have none to name. */
  startTime?: string;
  /** Free text kept on the block. */
  notes?: string;
  /** A routine's day's list, with what is ticked off now. */
  checklist?: { title: string; done: boolean }[];
}
