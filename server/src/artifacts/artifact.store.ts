import { randomUUID } from 'crypto';
import { CalendarUser } from '../calendar/calendar.types';
import {
  Artifact,
  CatalogCategory,
  CatalogType,
  Goal,
  ArtifactRecord,
  NewCatalogType,
  NewGoal,
  StoredRow,
} from './artifact.types';

/**
 * Where the deliveries are kept, with the catalogue they come from and the
 * goals they count towards.
 *
 * Postgres in production ([PgArtifactStore]); memory in the end-to-end tests
 * ([MemoryArtifactStore]).
 */
export abstract class ArtifactStore {
  /** Where a delivery goes when no place is given: the end of the queue. */
  protected async _end(user: CalendarUser): Promise<number> {
    const open = (await this.list(user)).filter(
      (it) => it.doneAt === undefined,
    );
    return Math.max(-1, ...open.map((it) => it.position)) + 1;
  }

  /** Every delivery of [user], in queue order (the delivered ones too). */
  abstract list(user: CalendarUser): Promise<Artifact[]>;

  abstract get(user: CalendarUser, id: string): Promise<Artifact | undefined>;

  abstract insert(
    user: CalendarUser,
    artifact: ArtifactRecord,
  ): Promise<Artifact>;

  /** Writes [artifact] back whole: every field is the new truth. */
  abstract update(user: CalendarUser, artifact: Artifact): Promise<Artifact>;

  abstract remove(user: CalendarUser, id: string): Promise<void>;

  /** The catalogue's shelves, in their order. */
  abstract categories(user: CalendarUser): Promise<CatalogCategory[]>;

  abstract insertCategory(
    user: CalendarUser,
    category: { name: string; position: number },
  ): Promise<CatalogCategory>;

  /** Every kind of every shelf, each shelf's in their order. */
  abstract types(user: CalendarUser): Promise<CatalogType[]>;

  abstract insertType(
    user: CalendarUser,
    type: NewCatalogType & { position: number },
  ): Promise<CatalogType>;

  /** Every goal, the oldest first. */
  abstract goals(user: CalendarUser): Promise<Goal[]>;

  abstract insertGoal(user: CalendarUser, goal: NewGoal): Promise<Goal>;

  abstract removeGoal(user: CalendarUser, id: string): Promise<void>;

  /** Forgets a kind; what was of it keeps no kind. */
  abstract removeType(user: CalendarUser, id: string): Promise<void>;

  /** Forgets a shelf and the kinds on it. */
  abstract removeCategory(user: CalendarUser, id: string): Promise<void>;

  /**
   * Writes [it] back as it was, id and all: what undoing a removal does. A
   * row already there is left as it is.
   */
  abstract revive(user: CalendarUser, it: StoredRow): Promise<void>;
}

type Owned<T> = T & { userId: string };

/** The deliveries, in memory. Behaves like the Postgres store. */
export class MemoryArtifactStore extends ArtifactStore {
  private readonly _artifacts = new Map<string, Owned<Artifact>>();
  private readonly _categories = new Map<string, Owned<CatalogCategory>>();
  private readonly _types = new Map<string, Owned<CatalogType>>();
  private readonly _goals = new Map<string, Owned<Goal>>();

  list(user: CalendarUser): Promise<Artifact[]> {
    return Promise.resolve(
      mine(this._artifacts, user)
        .sort(
          (a, b) =>
            a.position - b.position || a.createdAt.localeCompare(b.createdAt),
        )
        .map(unowned),
    );
  }

  get(user: CalendarUser, id: string): Promise<Artifact | undefined> {
    const stored = this._artifacts.get(id);
    return Promise.resolve(
      stored === undefined || stored.userId !== user.id
        ? undefined
        : unowned(stored),
    );
  }

  async insert(
    user: CalendarUser,
    artifact: ArtifactRecord,
  ): Promise<Artifact> {
    const position = artifact.position ?? (await this._end(user));
    const stored: Owned<Artifact> = {
      id: randomUUID(),
      userId: user.id,
      notes: '',
      createdAt: new Date().toISOString(),
      ...artifact,
      position,
    };
    this._artifacts.set(stored.id, stored);

    return unowned(stored);
  }

  update(user: CalendarUser, artifact: Artifact): Promise<Artifact> {
    if (this._artifacts.get(artifact.id)?.userId !== user.id) {
      return Promise.reject(new Error(`No artifact "${artifact.id}"`));
    }
    const next = { ...artifact, userId: user.id };
    this._artifacts.set(artifact.id, next);

    return Promise.resolve(unowned(next));
  }

  remove(user: CalendarUser, id: string): Promise<void> {
    if (this._artifacts.get(id)?.userId === user.id) this._artifacts.delete(id);
    return Promise.resolve();
  }

  categories(user: CalendarUser): Promise<CatalogCategory[]> {
    return Promise.resolve(
      mine(this._categories, user)
        .sort((a, b) => a.position - b.position)
        .map(unowned),
    );
  }

  insertCategory(
    user: CalendarUser,
    category: { name: string; position: number },
  ): Promise<CatalogCategory> {
    const stored = { id: randomUUID(), userId: user.id, ...category };
    this._categories.set(stored.id, stored);
    return Promise.resolve(unowned(stored));
  }

  types(user: CalendarUser): Promise<CatalogType[]> {
    return Promise.resolve(
      mine(this._types, user)
        .sort((a, b) => a.position - b.position)
        .map(unowned),
    );
  }

  insertType(
    user: CalendarUser,
    type: NewCatalogType & { position: number },
  ): Promise<CatalogType> {
    const stored = { id: randomUUID(), userId: user.id, ...type };
    this._types.set(stored.id, stored);
    return Promise.resolve(unowned(stored));
  }

  goals(user: CalendarUser): Promise<Goal[]> {
    return Promise.resolve(
      mine(this._goals, user)
        .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
        .map(unowned),
    );
  }

  insertGoal(user: CalendarUser, goal: NewGoal): Promise<Goal> {
    const stored = {
      id: randomUUID(),
      userId: user.id,
      createdAt: new Date().toISOString(),
      ...goal,
    };
    this._goals.set(stored.id, stored);
    return Promise.resolve(unowned(stored));
  }

  removeGoal(user: CalendarUser, id: string): Promise<void> {
    if (this._goals.get(id)?.userId === user.id) this._goals.delete(id);
    return Promise.resolve();
  }

  removeType(user: CalendarUser, id: string): Promise<void> {
    if (this._types.get(id)?.userId !== user.id) return Promise.resolve();
    this._types.delete(id);
    for (const it of this._artifacts.values()) {
      if (it.typeId === id) delete it.typeId;
    }
    for (const [goalId, it] of this._goals) {
      if (it.typeId === id) this._goals.delete(goalId);
    }
    return Promise.resolve();
  }

  async removeCategory(user: CalendarUser, id: string): Promise<void> {
    if (this._categories.get(id)?.userId !== user.id) return;
    for (const type of await this.types(user)) {
      if (type.categoryId === id) await this.removeType(user, type.id);
    }
    this._categories.delete(id);
  }

  revive(user: CalendarUser, it: StoredRow): Promise<void> {
    const table: Map<string, Owned<object>> = {
      artifact: this._artifacts,
      category: this._categories,
      type: this._types,
      goal: this._goals,
    }[it.kind];
    if (!table.has(it.row.id)) {
      table.set(it.row.id, { ...it.row, userId: user.id });
    }
    return Promise.resolve();
  }
}

function mine<T>(rows: Map<string, Owned<T>>, user: CalendarUser): Owned<T>[] {
  return [...rows.values()].filter((it) => it.userId === user.id);
}

/** A copy without the owner, and without the fields left undefined. */
function unowned<T extends object>(stored: Owned<T>): T {
  const copy: Record<string, unknown> = { ...stored };
  delete copy.userId;
  for (const key of Object.keys(copy)) {
    if (copy[key] === undefined) delete copy[key];
  }
  return copy as T;
}
