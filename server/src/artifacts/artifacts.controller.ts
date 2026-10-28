import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { Trace } from '../common/trace';
import { CatchUpInterceptor } from '../events/catch-up.interceptor';
import { owner } from '../events/request';
import {
  CreateArtifactDto,
  CreateArtifactTaskDto,
  CreateCatalogTypeDto,
  CreateGoalDto,
  EditArtifactDto,
  MoveArtifactDto,
} from './dto/artifact.dto';
import { ArtifactsAnswer } from './artifact.types';
import { ArtifactsService } from './artifacts.service';
import {
  requireArtifact,
  requireArtifactEdit,
  requireArtifactMove,
  requireArtifactTask,
  requireCatalogType,
  requireGoal,
} from './request';

/**
 * Entregas: the deliveries, the catalogue they come from and the goals
 * they count towards.
 *
 * Every route answers with all of it ([ArtifactsAnswer]), so the screen
 * never works out what a change did. A delivery's tasks are moved, begun
 * and finished on the day, through the day's own routes.
 */
@Controller()
@UseGuards(SessionGuard)
@UseInterceptors(CatchUpInterceptor)
export class ArtifactsController {
  constructor(private readonly artifacts: ArtifactsService) {}

  @Get('artifacts')
  list(@CurrentUser() user: AuthUser): Promise<ArtifactsAnswer> {
    return this._answer(user);
  }

  @Post('artifacts')
  async create(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateArtifactDto,
  ): Promise<ArtifactsAnswer> {
    const { artifact, at } = requireArtifact(dto);
    await this.artifacts.create(owner(user), artifact, at);
    return this._answer(user);
  }

  /**
   * Renames it, edits its notes, time or value, moves its deadline, begins
   * it or stops it, or delivers it.
   */
  @Patch('artifacts/:id')
  async edit(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: EditArtifactDto,
  ): Promise<ArtifactsAnswer> {
    await this.artifacts.edit(owner(user), id, requireArtifactEdit(dto));
    return this._answer(user);
  }

  @Delete('artifacts/:id')
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<ArtifactsAnswer> {
    await this.artifacts.remove(owner(user), id);
    return this._answer(user);
  }

  /**
   * Drags it to another place in the queue of deliveries; dropped among
   * those not begun (`started: false`), it is no longer begun.
   */
  @Post('artifacts/:id/move')
  async move(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: MoveArtifactDto,
  ): Promise<ArtifactsAnswer> {
    const { index, stop } = requireArtifactMove(dto);
    await this.artifacts.move(owner(user), id, index, { stop });
    return this._answer(user);
  }

  /** Writes a task down in the delivery, at the end of the backlog. */
  @Post('artifacts/:id/tasks')
  async addTask(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateArtifactTaskDto,
  ): Promise<ArtifactsAnswer> {
    await this.artifacts.addTask(
      owner(user),
      id,
      requireArtifactTask(dto),
      Trace.start(user.id),
    );
    return this._answer(user);
  }

  /** Writes a kind down in the catalogue, on a shelf she has or a new one. */
  @Post('catalog/types')
  async addType(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateCatalogTypeDto,
  ): Promise<ArtifactsAnswer> {
    await this.artifacts.addType(owner(user), requireCatalogType(dto));
    return this._answer(user);
  }

  @Post('goals')
  async addGoal(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateGoalDto,
  ): Promise<ArtifactsAnswer> {
    await this.artifacts.addGoal(owner(user), requireGoal(dto));
    return this._answer(user);
  }

  @Delete('goals/:id')
  async removeGoal(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<ArtifactsAnswer> {
    await this.artifacts.removeGoal(owner(user), id);
    return this._answer(user);
  }

  private _answer(user: AuthUser): Promise<ArtifactsAnswer> {
    return this.artifacts.answer(owner(user));
  }
}
