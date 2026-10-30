import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { owner } from '../events/request';
import {
  EditRestDto,
  PeriodStartedDto,
  PutDayDto,
  SaveCycleDto,
} from './request';
import { RhythmService, RhythmView } from './rhythm.service';

/**
 * Ciclo and Folgas: what decides the kind of each day.
 *
 * Every route answers the whole rhythm ([RhythmView]). None reads the day,
 * so none catches it up; the app asks for the timeline again after a
 * write, and its next read lays the queue out over the new kinds.
 */
@Controller('rhythm')
@UseGuards(SessionGuard)
export class RhythmController {
  constructor(private readonly rhythm: RhythmService) {}

  @Get()
  read(@CurrentUser() user: AuthUser): Promise<RhythmView> {
    return this.rhythm.view(owner(user));
  }

  @Put('cycle')
  async saveCycle(
    @CurrentUser() user: AuthUser,
    @Body() body: SaveCycleDto,
  ): Promise<RhythmView> {
    await this.rhythm.saveCycle(owner(user), body);
    return this.rhythm.view(owner(user));
  }

  @Post('cycle/start')
  async periodStarted(
    @CurrentUser() user: AuthUser,
    @Body() body: PeriodStartedDto,
  ): Promise<RhythmView> {
    await this.rhythm.periodStarted(owner(user), body.day);
    return this.rhythm.view(owner(user));
  }

  @Patch('rest')
  async editRest(
    @CurrentUser() user: AuthUser,
    @Body() body: EditRestDto,
  ): Promise<RhythmView> {
    await this.rhythm.editRest(owner(user), body);
    return this.rhythm.view(owner(user));
  }

  @Post('days-off')
  async putDay(
    @CurrentUser() user: AuthUser,
    @Body() body: PutDayDto,
  ): Promise<RhythmView> {
    await this.rhythm.putDay(owner(user), body);
    return this.rhythm.view(owner(user));
  }

  @Delete('days-off/:id')
  async removeDay(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<RhythmView> {
    await this.rhythm.removeDay(owner(user), id);
    return this.rhythm.view(owner(user));
  }
}
