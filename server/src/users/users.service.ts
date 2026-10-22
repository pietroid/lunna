import { Inject, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { user as userTable } from '../db/schema';
import { WorkDay } from '../time/work-hours';

/**
 * What is Lunna's about a person, beside what Better Auth keeps.
 *
 * Its own service so the route and the agent change it the same way.
 */
@Injectable()
export class UsersService {
  constructor(@Inject(DB) private readonly _db: Database) {}

  /**
   * Sets when [userId]'s working day runs.
   *
   * Nothing else is written: the next read of the timeline lays the queue
   * out inside the new hours, because no task's hour is stored.
   */
  async setWorkDay(userId: string, day: WorkDay): Promise<void> {
    await this._db
      .update(userTable)
      .set({ dayStart: day.start, dayEnd: day.end })
      .where(eq(userTable.id, userId));
  }
}
