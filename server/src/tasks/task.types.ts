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
  /**
   * ISO 8601, the hour it is anchored at, when it has one.
   *
   * An anchored task keeps its hour, and the queue flows around it. It still
   * slides: what is really happening before it pushes it later, and once its
   * hour comes it waits for the user. Without one, a task takes its turn.
   */
  notBefore?: string;
  /**
   * Whether it waits in the backlog rather than in the queue. A task in the
   * backlog keeps its order and its length and has no hour at all.
   */
  backlog: boolean;
  /** ISO 8601, when it was finished. Absent while there is still work. */
  doneAt?: string;
  /** The project it belongs to, when it belongs to one. */
  projectId?: string;
  /**
   * Whether it waits in its project, out of the day's sight: in neither the
   * queue nor the backlog. Absent means false.
   */
  parked?: boolean;
  /** The flexible routine this is a day of, when it is one. */
  routineId?: string;
  /** ISO 8601, which day of the routine: the hour the rule put it at. */
  occurrence?: string;
  /** A day of a routine that was taken off, or that its day ended without. */
  cancelled?: boolean;
}

/** One day of a flexible routine, to be written down as a task. */
export interface RoutineTask {
  routineId: string;
  title: string;
  minutes: number;
  /** ISO 8601, the routine's hour that day, which is also its anchor. */
  occurrence: string;
}

/** What a task is written down with. */
export interface NewTask {
  title: string;
  minutes: number;
  position: number;
  notBefore?: string;
  /** Whether it goes into the backlog. The queue when not said. */
  backlog?: boolean;
  /** The project it belongs to. */
  projectId?: string;
  /** Whether it waits in its project, out of the day's sight. */
  parked?: boolean;
}
