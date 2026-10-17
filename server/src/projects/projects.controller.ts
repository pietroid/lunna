import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { Trace } from '../common/trace';
import { owner } from '../events/request';
import {
  CreateProjectDto,
  CreateProjectTaskDto,
  EditProjectDto,
} from './dto/project.dto';
import { ProjectsAnswer } from './project.types';
import { ProjectsService } from './projects.service';
import {
  requireProject,
  requireProjectEdit,
  requireProjectTask,
} from './request';

/**
 * The subjects that outlive a day.
 *
 * Every route answers with every project, so the screen never works out
 * what a change did. A project's tasks are moved, begun and finished on the
 * day, through the day's own routes.
 */
@Controller('projects')
@UseGuards(SessionGuard)
export class ProjectsController {
  constructor(private readonly projects: ProjectsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser): Promise<ProjectsAnswer> {
    return this._answer(user);
  }

  @Post()
  async create(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateProjectDto,
  ): Promise<ProjectsAnswer> {
    await this.projects.create(owner(user), requireProject(dto));
    return this._answer(user);
  }

  /** Renames it, edits its notes, moves its deadline, or marks it done. */
  @Patch(':id')
  async edit(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: EditProjectDto,
  ): Promise<ProjectsAnswer> {
    await this.projects.edit(owner(user), id, requireProjectEdit(dto));
    return this._answer(user);
  }

  @Delete(':id')
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<ProjectsAnswer> {
    await this.projects.remove(owner(user), id);
    return this._answer(user);
  }

  /** Writes a task down in the project, at the end of the backlog. */
  @Post(':id/tasks')
  async addTask(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateProjectTaskDto,
  ): Promise<ProjectsAnswer> {
    await this.projects.addTask(
      owner(user),
      id,
      requireProjectTask(dto),
      Trace.start(user.id),
    );
    return this._answer(user);
  }

  private async _answer(user: AuthUser): Promise<ProjectsAnswer> {
    return { projects: await this.projects.list(owner(user)) };
  }
}
