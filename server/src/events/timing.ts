/**
 * A drop, and the one question the timeline still asks about it.
 *
 * Everything else a drag might ask about — how long is this, may I book it,
 * that hour is taken — is the screen asking the user to do arithmetic it can
 * do itself. What is left is the only drag that destroys something: putting a
 * task at the top of the day while something else is already running. That
 * one has a real answer only the user has, so it is the only one asked.
 */

/** A task dropped somewhere in the queue, possibly with a guard's answer. */
export interface TimingAction {
  /** The task being moved. */
  taskId: string;
  /**
   * Whether it was dropped into the backlog. Then [index] counts the
   * backlog, and nothing about the queue is asked.
   */
  backlog?: boolean;
  /**
   * Where in the list of tasks the drop left it, counting from the top with
   * itself taken out. What is running counts: it is at the top of the list.
   */
  index: number;
  /**
   * Whether it was dropped at the very top of the day, which is the user
   * saying they are doing it now.
   */
  start?: boolean;
  /** What the user decided. Absent means they have not been asked yet. */
  decision?: TimingDecision;
  /** ISO 8601, the start of the gap it was dropped into, when it was. */
  after?: string;
  /** The length it was cut to, to fit that gap. */
  minutes?: number;
}

/**
 * What the guard's two answers say about the block that was already running.
 *
 * - `solve_current` finishes it and gives its hour away.
 * - `postpone_current` keeps it, further down the day.
 */
export type TimingDecision = 'solve_current' | 'postpone_current';

/** Every decision, for validating one off the wire. */
export const TIMING_DECISIONS: TimingDecision[] = [
  'solve_current',
  'postpone_current',
];

/**
 * The question, as data. The app draws it and words it.
 *
 * Both answers start the dragged task now. They differ in what becomes of
 * what it displaced: finished, or further down the day.
 */
export interface StartNowGuard {
  kind: 'start_now';
  /** The task that was dropped at the top. */
  taskId: string;
  index: number;
  /** What is running now, which the answer decides the fate of. */
  current: {
    id: string;
    title: string;
    startTime: string;
    endTime: string;
  };
}
