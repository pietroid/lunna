/** Play on a task with tasks of its own. */
export class PlayArtifactDto {
  /**
   * A piece of this many minutes, when it has no task left: the task
   * written is that long instead of all it owes.
   */
  minutes?: number;
}
