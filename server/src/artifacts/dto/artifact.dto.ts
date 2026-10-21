/** What the Nova entrega sheet posts. */
export class CreateArtifactDto {
  title?: string;
  /** The kind in the catalogue, when it is one. */
  typeId?: string;
  minutes?: number;
  /** Whole reais. */
  value?: number;
  blockMinutes?: number | null;
  /** `YYYY-MM-DD`, the day it is due by. Absent for none. */
  deadline?: string | null;
  /** Where it enters the queue: `top` or `end` (the default). */
  at?: string;
}

/** A change to a delivery: only what is given changes. */
export class EditArtifactDto {
  title?: string;
  notes?: string;
  /** `YYYY-MM-DD`, or null to take the deadline away. */
  deadline?: string | null;
  minutes?: number | null;
  value?: number | null;
  blockMinutes?: number | null;
  /** Marks it delivered, or open again. */
  done?: boolean;
}

/** A delivery dragged to another place in the queue. */
export class MoveArtifactDto {
  index?: number;
}

/** A task written down in a delivery. */
export class CreateArtifactTaskDto {
  title?: string;
  minutes?: number;
}

/** A kind written down in the catalogue. */
export class CreateCatalogTypeDto {
  name?: string;
  minutes?: number;
  price?: number | null;
  blockMinutes?: number | null;
  /** A shelf she has. */
  categoryId?: string;
  /** Or the name of one, made when she has none of that name. */
  category?: string;
}

/** What the Nova meta sheet posts. */
export class CreateGoalDto {
  kind?: string;
  target?: number;
  period?: string;
  typeId?: string;
  /** `now` or `next`. */
  start?: string;
}
