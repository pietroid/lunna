/** What the new project sheet posts. */
export class CreateProjectDto {
  title?: string;
  /** `YYYY-MM-DD`, the day it is due by. Absent for none. */
  deadline?: string | null;
}

/** A change to a project: only what is given changes. */
export class EditProjectDto {
  title?: string;
  notes?: string;
  /** `YYYY-MM-DD`, or null to take the deadline away. */
  deadline?: string | null;
  /** Marks it done, or open again. */
  done?: boolean;
}

/** A task written down in a project. */
export class CreateProjectTaskDto {
  title?: string;
  minutes?: number;
}
