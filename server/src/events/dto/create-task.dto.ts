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
   * ISO 8601. The hour it is anchored at, when it goes straight onto the day
   * (`backlog: false`).
   */
  notBefore?: string;
  /**
   * Where in the list of tasks it goes, when it goes straight into the queue
   * at a place rather than at its end.
   */
  index?: number;
  /** The project it belongs to, when it is written down in one. */
  projectId?: string;
}
