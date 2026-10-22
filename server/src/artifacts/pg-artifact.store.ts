import { Inject, Injectable } from '@nestjs/common';
import { and, asc, eq } from 'drizzle-orm';
import { CalendarUser } from '../calendar/calendar.types';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import {
  artifact,
  ArtifactRow,
  catalogCategory,
  CatalogCategoryRow,
  catalogType,
  CatalogTypeRow,
  goal,
  GoalRow,
} from '../db/schema';
import { ArtifactStore } from './artifact.store';
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

/** The deliveries, their catalogue and their goals, in Postgres. */
@Injectable()
export class PgArtifactStore extends ArtifactStore {
  constructor(@Inject(DB) private readonly _db: Database) {
    super();
  }

  async list(user: CalendarUser): Promise<Artifact[]> {
    const rows = await this._db
      .select()
      .from(artifact)
      .where(eq(artifact.userId, user.id))
      .orderBy(asc(artifact.position), asc(artifact.createdAt));

    return rows.map(toArtifact);
  }

  async get(user: CalendarUser, id: string): Promise<Artifact | undefined> {
    if (!isUuid(id)) return undefined;

    const [row] = await this._db
      .select()
      .from(artifact)
      .where(and(eq(artifact.id, id), eq(artifact.userId, user.id)));

    return row === undefined ? undefined : toArtifact(row);
  }

  async insert(user: CalendarUser, input: ArtifactRecord): Promise<Artifact> {
    const position = input.position ?? (await this._end(user));
    const [row] = await this._db
      .insert(artifact)
      .values({
        userId: user.id,
        title: input.title,
        typeId: input.typeId ?? null,
        minutes: input.minutes ?? null,
        value: input.value ?? null,
        blockMinutes: input.blockMinutes ?? null,
        deadline: input.deadline ?? null,
        position,
      })
      .returning();

    return toArtifact(row);
  }

  async update(user: CalendarUser, next: Artifact): Promise<Artifact> {
    const [row] = await this._db
      .update(artifact)
      .set({
        title: next.title,
        notes: next.notes,
        typeId: next.typeId ?? null,
        minutes: next.minutes ?? null,
        value: next.value ?? null,
        blockMinutes: next.blockMinutes ?? null,
        deadline: next.deadline ?? null,
        position: next.position,
        doneAt: next.doneAt === undefined ? null : new Date(next.doneAt),
      })
      .where(and(eq(artifact.id, next.id), eq(artifact.userId, user.id)))
      .returning();

    if (row === undefined) throw new Error(`No artifact "${next.id}"`);

    return toArtifact(row);
  }

  async remove(user: CalendarUser, id: string): Promise<void> {
    if (!isUuid(id)) return;

    await this._db
      .delete(artifact)
      .where(and(eq(artifact.id, id), eq(artifact.userId, user.id)));
  }

  async categories(user: CalendarUser): Promise<CatalogCategory[]> {
    const rows = await this._db
      .select()
      .from(catalogCategory)
      .where(eq(catalogCategory.userId, user.id))
      .orderBy(asc(catalogCategory.position));

    return rows.map(toCategory);
  }

  async insertCategory(
    user: CalendarUser,
    input: { name: string; position: number },
  ): Promise<CatalogCategory> {
    const [row] = await this._db
      .insert(catalogCategory)
      .values({ userId: user.id, ...input })
      .returning();

    return toCategory(row);
  }

  async types(user: CalendarUser): Promise<CatalogType[]> {
    const rows = await this._db
      .select()
      .from(catalogType)
      .where(eq(catalogType.userId, user.id))
      .orderBy(asc(catalogType.position));

    return rows.map(toType);
  }

  async insertType(
    user: CalendarUser,
    input: NewCatalogType & { position: number },
  ): Promise<CatalogType> {
    const [row] = await this._db
      .insert(catalogType)
      .values({
        userId: user.id,
        categoryId: input.categoryId,
        name: input.name,
        minutes: input.minutes,
        price: input.price ?? null,
        blockMinutes: input.blockMinutes ?? null,
        position: input.position,
      })
      .returning();

    return toType(row);
  }

  async goals(user: CalendarUser): Promise<Goal[]> {
    const rows = await this._db
      .select()
      .from(goal)
      .where(eq(goal.userId, user.id))
      .orderBy(asc(goal.createdAt));

    return rows.map(toGoal);
  }

  async insertGoal(user: CalendarUser, input: NewGoal): Promise<Goal> {
    const [row] = await this._db
      .insert(goal)
      .values({
        userId: user.id,
        kind: input.kind,
        typeId: input.typeId ?? null,
        target: input.target,
        period: input.period,
        starts: input.starts,
      })
      .returning();

    return toGoal(row);
  }

  async removeGoal(user: CalendarUser, id: string): Promise<void> {
    if (!isUuid(id)) return;

    await this._db
      .delete(goal)
      .where(and(eq(goal.id, id), eq(goal.userId, user.id)));
  }

  async removeType(user: CalendarUser, id: string): Promise<void> {
    if (!isUuid(id)) return;

    await this._db
      .delete(catalogType)
      .where(and(eq(catalogType.id, id), eq(catalogType.userId, user.id)));
  }

  async removeCategory(user: CalendarUser, id: string): Promise<void> {
    if (!isUuid(id)) return;

    await this._db
      .delete(catalogCategory)
      .where(
        and(eq(catalogCategory.id, id), eq(catalogCategory.userId, user.id)),
      );
  }

  async revive(user: CalendarUser, it: StoredRow): Promise<void> {
    const userId = user.id;
    switch (it.kind) {
      case 'artifact': {
        const row = it.row;
        await this._db
          .insert(artifact)
          .values({
            id: row.id,
            userId,
            title: row.title,
            notes: row.notes,
            typeId: row.typeId ?? null,
            minutes: row.minutes ?? null,
            value: row.value ?? null,
            blockMinutes: row.blockMinutes ?? null,
            deadline: row.deadline ?? null,
            position: row.position,
            doneAt: row.doneAt === undefined ? null : new Date(row.doneAt),
            createdAt: new Date(row.createdAt),
          })
          .onConflictDoNothing();
        return;
      }
      case 'category':
        await this._db
          .insert(catalogCategory)
          .values({ userId, ...it.row })
          .onConflictDoNothing();
        return;
      case 'type': {
        const row = it.row;
        await this._db
          .insert(catalogType)
          .values({
            id: row.id,
            userId,
            categoryId: row.categoryId,
            name: row.name,
            minutes: row.minutes,
            price: row.price ?? null,
            blockMinutes: row.blockMinutes ?? null,
            position: row.position,
          })
          .onConflictDoNothing();
        return;
      }
      case 'goal': {
        const row = it.row;
        await this._db
          .insert(goal)
          .values({
            id: row.id,
            userId,
            kind: row.kind,
            typeId: row.typeId ?? null,
            target: row.target,
            period: row.period,
            starts: row.starts,
            createdAt: new Date(row.createdAt),
          })
          .onConflictDoNothing();
        return;
      }
    }
  }
}

function toArtifact(row: ArtifactRow): Artifact {
  return {
    id: row.id,
    title: row.title,
    notes: row.notes,
    position: row.position,
    createdAt: row.createdAt.toISOString(),
    ...(row.typeId === null ? {} : { typeId: row.typeId }),
    ...(row.minutes === null ? {} : { minutes: row.minutes }),
    ...(row.value === null ? {} : { value: row.value }),
    ...(row.blockMinutes === null ? {} : { blockMinutes: row.blockMinutes }),
    ...(row.deadline === null ? {} : { deadline: row.deadline }),
    ...(row.doneAt === null ? {} : { doneAt: row.doneAt.toISOString() }),
  };
}

function toCategory(row: CatalogCategoryRow): CatalogCategory {
  return { id: row.id, name: row.name, position: row.position };
}

function toType(row: CatalogTypeRow): CatalogType {
  return {
    id: row.id,
    categoryId: row.categoryId,
    name: row.name,
    minutes: row.minutes,
    position: row.position,
    ...(row.price === null ? {} : { price: row.price }),
    ...(row.blockMinutes === null ? {} : { blockMinutes: row.blockMinutes }),
  };
}

function toGoal(row: GoalRow): Goal {
  return {
    id: row.id,
    kind: row.kind,
    target: row.target,
    period: row.period,
    starts: row.starts,
    createdAt: row.createdAt.toISOString(),
    ...(row.typeId === null ? {} : { typeId: row.typeId }),
  };
}

/** Whether [value] can be an id at all, so a stray one is a 404, not a 500. */
function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    value,
  );
}
