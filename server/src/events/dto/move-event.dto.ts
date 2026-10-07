/** Where a drop left a task, counted from the top of the list of tasks. */
export class MoveEventDto {
  /** Counted in the queue, or in the backlog when [backlog] says so. */
  index?: number;
  /** Whether it was dropped into the backlog rather than into the queue. */
  backlog?: boolean;
  /** Whether it was dropped at the very top of the day: do it now. */
  start?: boolean;
  /** ISO 8601, the start of the gap it was dropped into, when it was. */
  after?: string;
  /** The length it was cut to so it fits that gap. */
  minutes?: number;
}
