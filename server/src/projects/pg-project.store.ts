import { Inject, Injectable } from '@nestjs/common';
import { and, asc, eq } from 'drizzle-orm';
import { CalendarUser } from '../calendar/calendar.types';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { project, ProjectRow } from '../db/schema';
import { ProjectStore } from './project.store';
import { NewProject, Project } from './project.types';

/** The projects, in Postgres. */
@Injectable()
export class PgProjectStore extends ProjectStore {
  constructor(@Inject(DB) private readonly _db: Database) {
    super();
  }

  async list(user: CalendarUser): Promise<Project[]> {
    const rows = await this._db
      .select()
      .from(project)
      .where(eq(project.userId, user.id))
      .orderBy(asc(project.createdAt));

    return rows.map(toProject);
  }

  async get(user: CalendarUser, id: string): Promise<Project | undefined> {
    if (!isUuid(id)) return undefined;

    const [row] = await this._db
      .select()
      .from(project)
      .where(and(eq(project.id, id), eq(project.userId, user.id)));

    return row === undefined ? undefined : toProject(row);
  }

  async insert(user: CalendarUser, input: NewProject): Promise<Project> {
    const [row] = await this._db
      .insert(project)
      .values({
        userId: user.id,
        title: input.title,
        deadline: input.deadline ?? null,
      })
      .returning();

    return toProject(row);
  }

  async update(user: CalendarUser, next: Project): Promise<Project> {
    const [row] = await this._db
      .update(project)
      .set({
        title: next.title,
        notes: next.notes,
        deadline: next.deadline ?? null,
        doneAt: next.doneAt === undefined ? null : new Date(next.doneAt),
      })
      .where(and(eq(project.id, next.id), eq(project.userId, user.id)))
      .returning();

    if (row === undefined) throw new Error(`No project "${next.id}"`);

    return toProject(row);
  }

  async remove(user: CalendarUser, id: string): Promise<void> {
    if (!isUuid(id)) return;

    await this._db
      .delete(project)
      .where(and(eq(project.id, id), eq(project.userId, user.id)));
  }
}

function toProject(row: ProjectRow): Project {
  return {
    id: row.id,
    title: row.title,
    notes: row.notes,
    createdAt: row.createdAt.toISOString(),
    ...(row.deadline === null ? {} : { deadline: row.deadline }),
    ...(row.doneAt === null ? {} : { doneAt: row.doneAt.toISOString() }),
  };
}

/** Whether [value] can be an id at all, so a stray one is a 404, not a 500. */
function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    value,
  );
}
