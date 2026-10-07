/** What the creation sheet posts when the user writes down a task. */
export class CreateTaskDto {
  title?: string;
  /** How long the work takes. */
  minutes?: number;
  /**
   * Whether it goes into the backlog. True when not said: everything written
   * down waits there until it is dragged into the queue.
   */
  backlog?: boolean;
  /**
   * ISO 8601. The earliest it may start, when it goes straight into the
   * queue (`backlog: false`).
   */
  notBefore?: string;
}
