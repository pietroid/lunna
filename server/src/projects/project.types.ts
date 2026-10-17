/**
 * A subject that outlives a day, as the rest of the server knows it.
 *
 * Its tasks are ordinary tasks that point at it (`Task.projectId`), in the
 * backlog or the queue like any other.
 */
export interface Project {
  id: string;
  title: string;
  /** Free text the user keeps on it. */
  notes: string;
  /** The day it is due by, `YYYY-MM-DD`. Absent when it has none. */
  deadline?: string;
  /** ISO 8601, when it was written down: where its time starts. */
  createdAt: string;
  /** ISO 8601, when it was marked done. Absent while it is open. */
  doneAt?: string;
}

/** What a project is written down with. */
export interface NewProject {
  title: string;
  deadline?: string;
}

/** Where a project's task is, as far as the day is concerned. */
export type TaskPlace = 'backlog' | 'queue' | 'scheduled' | 'done';

/** A project's task, as the app draws it. */
export interface ProjectTaskView {
  id: string;
  title: string;
  /** Free text kept on it, which its page opens on. */
  notes: string;
  minutes: number;
  place: TaskPlace;
  /**
   * ISO 8601, its hour on the day, as this read laid it out: where the queue
   * puts it, or where it began. Absent off the day.
   */
  at?: string;
  /** ISO 8601, when it was finished. */
  doneAt?: string;
}

/** A project, as the app draws it. */
export interface ProjectView {
  id: string;
  title: string;
  notes: string;
  deadline: string | null;
  createdAt: string;
  doneAt: string | null;
  /** Its tasks, in their order. */
  tasks: ProjectTaskView[];
}

/** Every route under `/projects` answers with every project. */
export interface ProjectsAnswer {
  projects: ProjectView[];
}

/** A change to a project. Only what is given changes. */
export interface ProjectEdit {
  title?: string;
  notes?: string;
  /** A day, or null to take the deadline away. */
  deadline?: string | null;
  done?: boolean;
}
