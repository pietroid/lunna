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
  /** Begun at once, in Em andamento. Needs a deadline. */
  started?: boolean;
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
  /** Begins it (needs a deadline), or puts it back among those not begun. */
  started?: boolean;
}

/** A delivery dragged to another place in the queue. */
export class MoveArtifactDto {
  index?: number;
  /** False: dragged into Não iniciadas, so it is no longer begun. */
  started?: boolean;
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

/** What the Novo objetivo sheet posts: an amount, by a day. */
export class CreateGoalDto {
  target?: number;
  /** `YYYY-MM-DD`, its last day. */
  deadline?: string;
}

/** What editing a goal posts. */
export class EditGoalDto {
  target?: number;
  deadline?: string;
}
