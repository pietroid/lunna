import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { UsersService } from './users.service';
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
  constructor(private readonly _users: UsersService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser): Me {
    return meOf(user);
  }

  /** Sets when their working day runs. */
  @Patch('me')
  async edit(
    @CurrentUser() user: AuthUser,
    @Body() body: EditMeDto,
  ): Promise<Me> {
    const day = requireWorkDay(body.workDay);
    await this._users.setWorkDay(user.id, day);

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
