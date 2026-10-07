/**
 * What there is to do, as the rest of the server knows it.
 *
 * A task has no hour. It has a place in the queue, and the hour it falls on
 * is worked out every time the day is read, by laying the queue out around
 * the events on the calendar. Once it is begun it gets an event of its own,
 * and that event is the hour it is really taking.
 */
export interface Task {
  id: string;
  title: string;
  /** Free text the user keeps on it. */
  notes: string;
  /** How long the work takes, pauses left out. */
  minutes: number;
  /** Its place in the queue, smallest first. Only the order means anything. */
  position: number;
  /** ISO 8601, the earliest the layout may start it, when there is one. */
  notBefore?: string;
  /**
   * Whether it waits in the backlog rather than in the queue. A task in the
   * backlog keeps its order and its length and has no hour at all.
   */
  backlog: boolean;
  /** ISO 8601, when it was finished. Absent while there is still work. */
  doneAt?: string;
}

/** What a task is written down with. */
export interface NewTask {
  title: string;
  minutes: number;
  position: number;
  notBefore?: string;
  /** Whether it goes into the backlog. The queue when not said. */
  backlog?: boolean;
}
