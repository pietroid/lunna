import {
  Body,
  Controller,
  Get,
  Inject,
  Patch,
  UseGuards,
} from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { DB } from '../db/db';
import type { Database } from '../db/db';
import { user as userTable } from '../db/schema';
import {
  EditMeDto,
  requireWorkDay,
  workDayDtoOf,
  WorkDayDto,
} from './work-day';

/** The signed-in person, with their working day as the wire writes it. */
export interface Me {
  id: string;
  email: string;
  name: string;
  image?: string;
  timeZone: string;
  workDay: Required<WorkDayDto>;
}

/**
 * The signed-in person.
 *
 * Better Auth owns the user table and creates the row on the first sign-in,
 * so there is no sign-up step here: this reads back who the session
 * belongs to, and changes the few things about them that are Lunna's.
 */
@Controller('users')
@UseGuards(SessionGuard)
export class UsersController {
  constructor(@Inject(DB) private readonly _db: Database) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser): Me {
    return meOf(user);
  }

  /**
   * Sets when their working day runs.
   *
   * Nothing else is written: the next read of the timeline lays the queue
   * out inside the new hours, because no task's hour is stored.
   */
  @Patch('me')
  async edit(
    @CurrentUser() user: AuthUser,
    @Body() body: EditMeDto,
  ): Promise<Me> {
    const day = requireWorkDay(body.workDay);

    await this._db
      .update(userTable)
      .set({ dayStart: day.start, dayEnd: day.end })
      .where(eq(userTable.id, user.id));

    return meOf({ ...user, dayStart: day.start, dayEnd: day.end });
  }
}

function meOf(user: AuthUser): Me {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    image: user.image,
    timeZone: user.timeZone,
    workDay: workDayDtoOf({ start: user.dayStart, end: user.dayEnd }),
  };
}
