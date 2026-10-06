/** What the creation sheet posts when the user writes down a task. */
export class CreateTaskDto {
  title?: string;
  /** How long the work takes. */
  minutes?: number;
  /**
   * ISO 8601. The earliest it may start, when it was written down from a tap
   * on empty room further down the day.
   */
  notBefore?: string;
}
