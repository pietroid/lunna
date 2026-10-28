/**
 * One delivery ("entrega"), as the rest of the server knows it: something
 * the person owes someone, or the market, by a day.
 *
 * Its tasks are ordinary tasks that point at it (`Task.artifactId`), in the
 * backlog or the queue like any other. The open ones are a queue of their
 * own, in [position] order.
 */
export interface Artifact {
  id: string;
  title: string;
  /** Free text the user keeps on it. */
  notes: string;
  /** Its kind in the catalogue. Absent for a one-off delivery. */
  typeId?: string;
  /** How long it takes in all, when somebody said. */
  minutes?: number;
  /** What it is worth, in whole reais. */
  value?: number;
  /** The longest piece of it the day takes at once. Absent: whole. */
  blockMinutes?: number;
  /** The day it is due by, `YYYY-MM-DD`. Absent when it has none. */
  deadline?: string;
  /** Its place in the queue of deliveries, smallest first. */
  position: number;
  /** ISO 8601, when it was written down. */
  createdAt: string;
  /**
   * ISO 8601, when it was begun: dragged into Em andamento, or a task of
   * it begun on the day. Absent while it waits in Não iniciadas.
   */
  startedAt?: string;
  /** ISO 8601, when it was delivered. Absent while it is open. */
  doneAt?: string;
}

/** What a delivery is written down with. */
export interface NewArtifact {
  title: string;
  typeId?: string;
  minutes?: number;
  value?: number;
  /** Null says whole, even for a kind that comes in blocks. */
  blockMinutes?: number | null;
  deadline?: string;
  /** Begun at once, in Em andamento: it needs a deadline. */
  started?: boolean;
}

/** Where a new delivery enters the queue. */
export type QueueEnd = 'top' | 'end';

/** A shelf of the catalogue: Atendimentos, Conteúdo, Produtos. */
export interface CatalogCategory {
  id: string;
  name: string;
  /** Its place among the shelves, smallest first. */
  position: number;
}

/** One kind of thing the person delivers, on a shelf. */
export interface CatalogType {
  id: string;
  categoryId: string;
  name: string;
  /** How long one takes, start to finish. */
  minutes: number;
  /** What one is worth, in whole reais. */
  price?: number;
  /** The longest piece of it the day takes at once. Absent: whole. */
  blockMinutes?: number;
  /** Its place on its shelf, smallest first. */
  position: number;
}

/** What a kind is written down with. */
export interface NewCatalogType {
  categoryId: string;
  name: string;
  minutes: number;
  price?: number;
  blockMinutes?: number;
}

/** What a goal counts: money delivered, or deliveries of one kind. */
export type GoalKind = 'money' | 'count';

/**
 * An amount to reach by a day. Goals follow each other: each counts from
 * its [starts] to its [deadline], both included.
 */
export interface Goal {
  id: string;
  kind: GoalKind;
  /** The kind counted, for a count goal. */
  typeId?: string;
  /** Whole reais, or deliveries. */
  target: number;
  /** `YYYY-MM-DD`, the first day it counts. */
  starts: string;
  /** `YYYY-MM-DD`, the last day it counts: the day it is to be reached by. */
  deadline: string;
  createdAt: string;
}

/** What a goal is written down with. */
export interface NewGoal {
  kind: GoalKind;
  typeId?: string;
  target: number;
  starts: string;
  deadline: string;
}

/** A change to a goal. Only what is given changes. */
export interface GoalEdit {
  target?: number;
  deadline?: string;
}

/** Where a delivery's task is, as far as the day is concerned. */
export type TaskPlace = 'backlog' | 'queue' | 'scheduled' | 'done';

/** A delivery's task, as the app draws it. */
export interface ArtifactTaskView {
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

/** A delivery, as the app draws it. */
export interface ArtifactView {
  id: string;
  title: string;
  notes: string;
  typeId: string | null;
  /**
   * How long it takes in all: as written down, or else the sum of its
   * tasks.
   */
  minutes: number;
  /** How much of that its finished tasks took. */
  doneMinutes: number;
  value: number | null;
  blockMinutes: number | null;
  deadline: string | null;
  createdAt: string;
  /** When it was begun; null while it waits in Não iniciadas. */
  startedAt: string | null;
  doneAt: string | null;
  /** Its tasks, in their order. */
  tasks: ArtifactTaskView[];
}

/** A kind, as the catalogue shows it. */
export interface CatalogTypeView {
  id: string;
  name: string;
  minutes: number;
  price: number | null;
  blockMinutes: number | null;
}

/** A shelf with its kinds, in their order. */
export interface CatalogCategoryView {
  id: string;
  name: string;
  types: CatalogTypeView[];
}

/** A goal, measured from its first day to its last. */
export interface GoalView {
  id: string;
  kind: GoalKind;
  typeId: string | null;
  target: number;
  /** `YYYY-MM-DD`, its first day. */
  start: string;
  /** `YYYY-MM-DD`, the day after its last (its deadline). */
  end: string;
  /** What was delivered from its start to its end: reais, or deliveries. */
  done: number;
  /**
   * What the open deliveries due by its last day would add, delivered in
   * time: none tied to it, the goal finds them by their deadlines.
   */
  queued: number;
  /** How many open deliveries [queued] adds up. */
  queuedCount: number;
}

/**
 * The schedule against the queue: the time the deliveries due by [until]
 * still need, and the free working time the agenda has left until then.
 */
export interface ScheduleView {
  needMinutes: number;
  freeMinutes: number;
  /** `YYYY-MM-DD`, the last day counted: the end of this month. */
  until: string;
}

/** Every route under `/artifacts`, `/catalog` and `/goals` answers this. */
export interface ArtifactsAnswer {
  /** The open deliveries in their order, then the delivered, newest first. */
  artifacts: ArtifactView[];
  catalog: CatalogCategoryView[];
  /** Those being measured, then those to come, each by its start. */
  goals: GoalView[];
  schedule: ScheduleView;
  /** The kinds used most, all time, at most three, most used first. */
  topTypes: string[];
}

/** A change to a delivery. Only what is given changes. */
export interface ArtifactEdit {
  title?: string;
  notes?: string;
  /** A day, or null to take the deadline away. */
  deadline?: string | null;
  minutes?: number | null;
  value?: number | null;
  blockMinutes?: number | null;
  done?: boolean;
  /**
   * Begins it (Em andamento), which needs a deadline, or puts it back
   * among the ones not begun.
   */
  started?: boolean;
}

/** A new delivery as the store writes it: whole is no blocks at all. */
export type ArtifactRecord = Omit<NewArtifact, 'blockMinutes' | 'started'> & {
  blockMinutes?: number;
  startedAt?: string;
  /** Absent: the end of the queue. */
  position?: number;
};

/**
 * One row the artifact store keeps, by table: what undo writes back as it
 * was, id and all.
 */
export type StoredRow =
  | { kind: 'artifact'; row: Artifact }
  | { kind: 'category'; row: CatalogCategory }
  | { kind: 'type'; row: CatalogType }
  | { kind: 'goal'; row: Goal };
