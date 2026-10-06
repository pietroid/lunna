import {
  Body,
  Controller,
  Delete,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { Trace } from '../common/trace';
import { CreateTaskDto } from './dto/create-task.dto';
import { EditEventDto } from './dto/edit-event.dto';
import { ExtendEventDto } from './dto/extend-event.dto';
import { MoveEventDto } from './dto/move-event.dto';
import { SnoozeEventDto } from './dto/snooze-event.dto';
import { TimingDto } from './dto/timing.dto';
import { Timeline } from './entities/event.entity';
import { EventLayoutService } from './event-layout.service';
import { PauseTickerService } from './pause-ticker.service';
import {
  daysOf,
  owner,
  requireDelta,
  requireMove,
  requireSnooze,
  requireTask,
  requireTaskEdit,
  requireTiming,
} from './request';
import { TimelineService } from './timeline.service';
import { StartNowGuard } from './timing';

/**
 * What there is to do, in the order it is to be done.
 *
 * Every route answers with the whole timeline, for the [days] the screen is
 * drawing, because a task that moves in the queue moves every task after it
 * on the calendar.
 */
@Controller('tasks')
@UseGuards(SessionGuard)
export class TasksController {
  constructor(
    private readonly timeline: TimelineService,
    private readonly layout: EventLayoutService,
    private readonly ticker: PauseTickerService,
  ) {}

  /** Writes a task down at the end of the queue. */
  @Post()
  async create(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateTaskDto,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    const trace = Trace.start(user.id);
    trace.log('turn.begin', { kind: 'task' });
    await this.layout.createTask(owner(user), requireTask(dto), trace);

    return this._answer(user, days);
  }

  /**
   * Answers a guard.
   *
   * Its own route rather than an action on a task, because a guard is about
   * where a card goes and what it displaces, not about one task.
   */
  @Post('timing')
  async applyTiming(
    @CurrentUser() user: AuthUser,
    @Body() dto: TimingDto,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    const action = requireTiming(dto.action ?? {});
    const trace = Trace.start(user.id, action.taskId);
    trace.log('timing.received', { decision: action.decision });

    const guard = await this.layout.moveTask(owner(user), action, trace);
    return this._answer(user, days, guard);
  }

  /** Renames a task, edits its notes, or changes how long it takes. */
  @Patch(':id')
  async edit(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: EditEventDto,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.editTask(
      owner(user),
      id,
      requireTaskEdit(dto),
      Trace.start(user.id, id),
    );

    return this._answer(user, days);
  }

  /**
   * Moves a task to a new place in the list.
   *
   * Dropping it at the very top while something else is running answers
   * with a guard and changes nothing.
   */
  @Post(':id/move')
  async move(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: MoveEventDto,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    const guard = await this.layout.moveTask(
      owner(user),
      requireMove(id, dto),
      Trace.start(user.id, id),
    );

    return this._answer(user, days, guard);
  }

  /**
   * The user began a task.
   *
   * What a waiting task's reminder and its card both ask for. One further
   * down the day goes to the top instead, which can raise the guard.
   */
  @Post(':id/start')
  async start(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    const guard = await this.layout.startTask(
      owner(user),
      id,
      Trace.start(user.id, id),
    );

    return this._answer(user, days, guard);
  }

  /** Not yet: a waiting task waits a few minutes more before asking again. */
  @Post(':id/snooze')
  async snooze(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: SnoozeEventDto,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.snoozeTask(
      owner(user),
      id,
      requireSnooze(dto.minutes),
      Trace.start(user.id, id),
    );

    return this._answer(user, days);
  }

  /** Ticks a task off. A running one keeps the hour it really took. */
  @Post(':id/done')
  async done(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.doneTask(owner(user), id, Trace.start(user.id, id));

    return this._answer(user, days);
  }

  /** Forgets a task, keeping nothing of it. */
  @Delete(':id')
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.removeTask(owner(user), id, Trace.start(user.id, id));

    return this._answer(user, days);
  }

  /** Pauses the running task, which then keeps its work owed. */
  @Post(':id/pause')
  async pause(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    const who = owner(user);
    this.ticker.watch(who);
    await this.layout.pauseTask(who, id, Trace.start(user.id, id));

    return this._answer(user, days);
  }

  /** Runs a paused task again. */
  @Post(':id/resume')
  async resume(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.resumeTask(owner(user), id, Trace.start(user.id, id));

    return this._answer(user, days);
  }

  /** Gives a task more time, or less. */
  @Post(':id/extend')
  async extend(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ExtendEventDto,
    @Query('days') days?: string,
  ): Promise<Timeline> {
    await this.layout.extendTask(
      owner(user),
      id,
      requireDelta(dto.minutes),
      Trace.start(user.id, id),
    );

    return this._answer(user, days);
  }

  private async _answer(
    user: AuthUser,
    days?: string,
    guard?: StartNowGuard,
  ): Promise<Timeline> {
    const timeline = this.timeline.view(
      await this.timeline.day(owner(user), daysOf(days)),
    );

    return guard === undefined ? timeline : { ...timeline, guard };
  }
}
