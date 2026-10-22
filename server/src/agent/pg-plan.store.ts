import { Inject, Injectable } from '@nestjs/common';
import { and, eq, isNotNull, lt, ne, or } from 'drizzle-orm';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { agentPlan, AgentPlanRow } from '../db/schema';
import { NewPlan, Plan, PLAN_TTL_MS, PlanStore } from './plan';

/** What a plan's `body` holds. */
type Body = Pick<Plan, 'gestures' | 'changes' | 'pushed' | 'assumed'>;

/** The plans, in Postgres: an undo outlives a restart. */
@Injectable()
export class PgPlanStore extends PlanStore {
  constructor(@Inject(DB) private readonly _db: Database) {
    super();
  }

  async put(userId: string, made: NewPlan): Promise<Plan> {
    const now = new Date();
    await this._db
      .delete(agentPlan)
      .where(
        and(
          eq(agentPlan.userId, userId),
          lt(agentPlan.createdAt, new Date(now.getTime() - PLAN_TTL_MS)),
        ),
      );

    const { group, ...body } = made;
    const [row] = await this._db
      .insert(agentPlan)
      .values({
        userId,
        groupId: group ?? null,
        body: body satisfies Body,
        createdAt: now,
      })
      .returning();

    return planOf(row);
  }

  async get(userId: string, id: string): Promise<Plan | undefined> {
    if (!isUuid(id)) return undefined;

    const [row] = await this._db
      .select()
      .from(agentPlan)
      .where(and(eq(agentPlan.id, id), eq(agentPlan.userId, userId)));
    if (row === undefined) return undefined;
    if (Date.now() - row.createdAt.getTime() > PLAN_TTL_MS) return undefined;

    return planOf(row);
  }

  async save(plan: Plan): Promise<void> {
    await this._db
      .update(agentPlan)
      .set({ applied: plan.applied ?? null })
      .where(and(eq(agentPlan.id, plan.id), eq(agentPlan.userId, plan.userId)));
  }

  async answered(plan: Plan): Promise<boolean> {
    const group = plan.group ?? plan.id;
    const found = await this._db
      .select({ id: agentPlan.id })
      .from(agentPlan)
      .where(
        and(
          eq(agentPlan.userId, plan.userId),
          ne(agentPlan.id, plan.id),
          isNotNull(agentPlan.applied),
          or(eq(agentPlan.id, group), eq(agentPlan.groupId, group)),
        ),
      )
      .limit(1);

    return found.length > 0;
  }
}

function planOf(row: AgentPlanRow): Plan {
  const body = row.body as Body;
  return {
    id: row.id,
    userId: row.userId,
    ...body,
    ...(row.groupId === null ? {} : { group: row.groupId }),
    createdAt: row.createdAt.getTime(),
    ...(row.applied === null
      ? {}
      : { applied: row.applied as NonNullable<Plan['applied']> }),
  };
}

/** Whether [value] can be an id at all, so a stray one is a 404, not a 500. */
function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    value,
  );
}
