import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CalendarService } from '../calendar/calendar.service';
import { CalendarEvent, CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { TaskStore } from '../tasks/task.store';
import { Task } from '../tasks/task.types';
import {
  addMinutes,
  floorToMinute,
  roundUpToFiveMinutes,
} from '../time/work-hours';
import {
  EventEdit,
  EventRequest,
  TaskEdit,
  TaskRequest,
} from './entities/event.entity';
import { intervalOf, isRunning } from './event-sections';
import { StartNowGuard, TimingAction } from './timing';
import { Day, TimelineService, workSecondsOf } from './timeline.service';

/**
 * Something running at this minute: a task that was begun, or an event.
 *
 * What the guard asks about, and what its answer finishes or puts off.
 */
type Running =
  | { kind: 'task'; task: Task; event: CalendarEvent }
  | { kind: 'event'; event: CalendarEvent };

/**
 * When things happen.
 *
 * The day is a queue of tasks flowing around a handful of events, packed as
 * close to now as they will go. A task's hour is never written down: it is
 * where the queue puts it on the read that asks. So adding a task, dragging
 * one and finishing one only change the queue, and the next read lays it
 * out again. An event's hour is written down, because the hour is the point
 * of it, and so is a task's once it is begun, because by then it is a fact.
 *
 * No model is involved, and nothing is asked that arithmetic can answer. The
 * single surviving question is what to do with the thing that was already
 * running when a task was dragged on top of it.
 */
@Injectable()
export class EventLayoutService {
  constructor(
    private readonly _timeline: TimelineService,
    private readonly _calendar: CalendarService,
    private readonly _tasks: TaskStore,
  ) {}

  // -------------------------------------------------------------------------
  // Events
  // -------------------------------------------------------------------------

  /**
   * Writes a fixed block down at the hour it was given, whatever else is
   * there: the user named it, so it is not the server's to negotiate. The
   * tasks around it make room on the next read.
   */
  async createEvent(
    user: CalendarUser,
    request: EventRequest,
    trace: Trace,
  ): Promise<void> {
    const start = roundUpToFiveMinutes(new Date(request.startTime));
    const created = await this._calendar.create(user, {
      title: request.title,
      startTime: start.toISOString(),
      endTime: addMinutes(start, request.durationMinutes).toISOString(),
      fixed: true,
    });

    trace.log('event.create', {
      eventId: created.id,
      start: created.startTime,
    });
  }

  /**
   * Renames a block, changes its notes, changes how long it takes, or gives
   * it another hour.
   *
   * The duration is the work, pauses left out, so it goes through [extend]
   * as the difference from what it was. A new hour can only be named for
   * something that has not started: a running block's start is a fact.
   */
  async editEvent(
    user: CalendarUser,
    eventId: string,
    edit: EventEdit,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    let event = await this._event(user, eventId);
    event = await this._reword(user, event, edit, trace);

    if (edit.startTime !== undefined) {
      const interval = intervalOf(event);
      if (interval !== undefined && interval.start <= now) {
        throw new BadRequestException(
          'Não dá para mudar o início de algo que já começou.',
        );
      }

      const start = floorToMinute(new Date(edit.startTime));
      const work = edit.workMinutes ?? Math.round(workSecondsOf(event) / 60);

      trace.log('event.pin', { eventId, start: start.toISOString() });
      await this._revise(
        user,
        event,
        {
          startTime: start.toISOString(),
          endTime: addMinutes(start, work).toISOString(),
          pausedAt: undefined,
          remainingSeconds: undefined,
          pausedSeconds: undefined,
        },
        trace,
      );
      return;
    }

    if (edit.workMinutes !== undefined) {
      const delta = edit.workMinutes - Math.round(workSecondsOf(event) / 60);
      if (delta !== 0) await this._extend(user, event, delta, trace, now);
    }
  }

  /**
   * Marks a block done. A running one keeps the hour it really took; one
   * that never started had no hour to keep, and leaves.
   */
  async doneEvent(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    await this._finish(user, await this._event(user, eventId), trace, now);
  }

  /** Takes a block off the calendar entirely, as if it had never been. */
  async removeEvent(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
  ): Promise<void> {
    const event = await this._event(user, eventId);
    trace.log('event.remove', { eventId });
    await this._calendar.remove(user, event);
  }

  async pauseEvent(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    await this._pause(user, await this._event(user, eventId), trace, now);
  }

  async resumeEvent(
    user: CalendarUser,
    eventId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    await this._resume(user, await this._event(user, eventId), trace, now);
  }

  async extendEvent(
    user: CalendarUser,
    eventId: string,
    minutes: number,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    const event = await this._event(user, eventId);
    await this._extend(user, event, minutes, trace, now);
  }

  // -------------------------------------------------------------------------
  // Tasks
  // -------------------------------------------------------------------------

  /**
   * Writes a task down at the end of the backlog, which is where everything
   * waits until it is dragged into the queue.
   *
   * One asked for straight in the queue goes at its end. With a floor it
   * goes into the queue where that floor falls instead, after everything the
   * queue puts before it, and keeps the floor so the next read does not pull
   * it back to now.
   */
  async createTask(
    user: CalendarUser,
    request: TaskRequest,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    const day = await this._timeline.day(user, 1, now);

    if (request.backlog) {
      const created = await this._tasks.insert(user, {
        title: request.title,
        minutes: request.minutes,
        position: await this._positionAt(user, day.backlog, day.backlog.length),
        backlog: true,
      });
      trace.log('task.create', { taskId: created.id, backlog: true });
      return;
    }

    const queue = queueOf(day);
    const floor =
      request.notBefore === undefined
        ? undefined
        : floorToMinute(new Date(request.notBefore));
    const useful = floor !== undefined && floor > now ? floor : undefined;

    const index =
      useful === undefined
        ? queue.length
        : queue.filter((task) => day.placed.get(task.id)!.start < useful)
            .length;

    const created = await this._tasks.insert(user, {
      title: request.title,
      minutes: request.minutes,
      position: await this._positionAt(user, queue, index),
      notBefore: useful?.toISOString(),
    });

    trace.log('task.create', { taskId: created.id, index });
  }

  /**
   * Renames a task, changes its notes, or how long it takes.
   *
   * A task that is running takes the new length on its hour as well, and
   * whatever comes after it moves on the next read.
   */
  async editTask(
    user: CalendarUser,
    taskId: string,
    edit: TaskEdit,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    const day = await this._timeline.day(user, 1, now);
    let task = pendingOf(day, taskId);
    const live = day.live.get(taskId);

    const words = {
      ...(edit.title !== undefined && edit.title !== task.title
        ? { title: edit.title }
        : {}),
      ...(edit.notes !== undefined && edit.notes !== task.notes
        ? { notes: edit.notes }
        : {}),
    };
    if (Object.keys(words).length > 0) {
      trace.log('task.revise', { taskId, keys: Object.keys(words) });
      task = await this._tasks.update(user, { ...task, ...words });
      // The hour on the calendar carries the name, so a reminder about it
      // says the same thing the card does.
      if (live !== undefined && words.title !== undefined) {
        await this._revise(user, live, { title: words.title }, trace);
      }
    }

    if (edit.workMinutes === undefined) return;

    if (live === undefined) {
      if (edit.workMinutes !== task.minutes) {
        await this._tasks.update(user, { ...task, minutes: edit.workMinutes });
      }
      return;
    }

    const delta = edit.workMinutes - Math.round(workSecondsOf(live) / 60);
    if (delta !== 0) {
      await this._extend(user, live, delta, trace, now);
      await this._tasks.update(user, { ...task, minutes: edit.workMinutes });
    }
  }

  /**
   * Moves a task to [action.index] in the list and lets the queue lay itself
   * out again.
   *
   * The index counts what is running at the top of the list, so dropping
   * something just under the running task makes it the next thing, and
   * dropping it above is doing it now. That one, while something else is
   * running, is the only drag that destroys something, and so the only one
   * that asks first: the answer comes back as a guard and nothing changes
   * until the user picks one.
   */
  async moveTask(
    user: CalendarUser,
    action: TimingAction,
    trace: Trace,
    now = new Date(),
  ): Promise<StartNowGuard | undefined> {
    const day = await this._timeline.day(user, 1, now);
    const task = pendingOf(day, action.taskId);

    if (action.backlog === true) {
      await this._shelve(user, day, task, action.index, trace);
      return undefined;
    }

    const running = runningOf(day, task.id);

    if (action.start === true && running !== undefined && !action.decision) {
      trace.log('task.guard', { taskId: task.id, current: running.event.id });

      return {
        kind: 'start_now',
        taskId: task.id,
        index: action.index,
        current: {
          id: running.kind === 'task' ? running.task.id : running.event.id,
          title:
            running.kind === 'task' ? running.task.title : running.event.title,
          startTime: running.event.startTime,
          endTime: running.event.endTime,
        },
      };
    }

    // What the guard's answer does to what was running. Postponing a fixed
    // block does nothing: its hour is the point of it, so the task waits
    // for it instead.
    let postponed: Task | undefined;
    if (action.start === true && running !== undefined) {
      if (action.decision === 'solve_current') {
        await this._finishRunning(user, running, trace, now);
      } else if (running.kind === 'task') {
        trace.log('task.postpone', { taskId: running.task.id });
        await this._calendar.remove(user, running.event);
        postponed = running.task;
      }
    }

    // A running task dragged anywhere but the top stops running: it goes
    // back in the queue, owing its whole length, and starts again when it
    // comes round.
    const own = day.live.get(task.id);
    if (own !== undefined && action.start !== true) {
      trace.log('task.unstart', { taskId: task.id });
      await this._calendar.remove(user, own);
    }

    // A drop into a gap asks for that gap, so the task is not laid out any
    // earlier than where it starts. A drop between two cards asks for no
    // such thing, and lifts whatever floor it had.
    const floor =
      action.after === undefined
        ? undefined
        : laterOf(floorToMinute(new Date(action.after)), floorToMinute(now));

    const still = [...day.live.keys()].filter(
      (id) => id !== task.id && id !== postponed?.id,
    ).length;
    const queue = queueOf(day).filter((it) => it.id !== task.id);
    const index = Math.max(0, Math.min(action.index - still, queue.length));

    trace.log('task.move', { taskId: task.id, index });
    const moved = await this._tasks.update(user, {
      ...task,
      position: await this._positionAt(user, queue, index),
      notBefore: floor?.toISOString(),
      minutes: action.minutes ?? task.minutes,
      backlog: false,
    });

    // What was running and was put off is the next thing after this one.
    if (postponed !== undefined) {
      const after = [...queue.slice(0, index), moved, ...queue.slice(index)];
      await this._tasks.update(user, {
        ...postponed,
        position: await this._positionAt(user, after, index + 1),
        notBefore: undefined,
      });
    }

    // Dropping a task at the top is the user saying they are doing it now,
    // which is as clear a yes as the button that asks.
    if (action.start === true && own === undefined) {
      await this._beginIfFree(user, moved, trace, now);
    }

    return undefined;
  }

  /**
   * The user began a task.
   *
   * One whose hour has come is begun where it is. One further down the day
   * is the same request as dragging it to the top, and goes the same way,
   * guard and all.
   */
  async startTask(
    user: CalendarUser,
    taskId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<StartNowGuard | undefined> {
    const day = await this._timeline.day(user, 1, now);
    const task = pendingOf(day, taskId);
    if (day.live.has(taskId)) return undefined;

    const slot = day.placed.get(taskId);
    if (slot !== undefined && slot.start <= now) {
      await this._begin(user, task, trace, now);
      return undefined;
    }

    return this.moveTask(user, { taskId, index: 0, start: true }, trace, now);
  }

  /**
   * Not yet: the task waits [minutes] more before asking again.
   *
   * Written as a floor rather than as an hour, so the rest of the day keeps
   * flowing around it. One that was already running stops.
   */
  async snoozeTask(
    user: CalendarUser,
    taskId: string,
    minutes: number,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    const day = await this._timeline.day(user, 1, now);
    const task = pendingOf(day, taskId);
    const live = day.live.get(taskId);
    if (live !== undefined) await this._calendar.remove(user, live);

    const floor = floorToMinute(addMinutes(now, minutes));
    trace.log('task.snooze', { taskId, until: floor.toISOString() });

    await this._tasks.update(user, { ...task, notBefore: floor.toISOString() });
  }

  /**
   * Marks a task done.
   *
   * A running one keeps on the calendar the hour it really took, and the
   * rest of the day starts five minutes from now, which is the break. One
   * that never started just leaves the list.
   */
  async doneTask(
    user: CalendarUser,
    taskId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    const day = await this._timeline.day(user, 1, now);
    const task = pendingOf(day, taskId);
    const live = day.live.get(taskId);

    await this._finishRunning(
      user,
      live === undefined ? undefined : { kind: 'task', task, event: live },
      trace,
      now,
      task,
    );
  }

  /** Forgets a task, and the hour it was taking if it was running. */
  async removeTask(
    user: CalendarUser,
    taskId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    const day = await this._timeline.day(user, 1, now);
    pendingOf(day, taskId);

    const live = day.live.get(taskId);
    if (live !== undefined) await this._calendar.remove(user, live);

    trace.log('task.remove', { taskId });
    await this._tasks.remove(user, taskId);
  }

  async pauseTask(
    user: CalendarUser,
    taskId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    const live = await this._live(user, taskId, now);
    if (live === undefined) {
      throw new BadRequestException('Comece o bloco antes de pausar.');
    }

    await this._pause(user, live, trace, now);
  }

  async resumeTask(
    user: CalendarUser,
    taskId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    const live = await this._live(user, taskId, now);
    if (live !== undefined) await this._resume(user, live, trace, now);
  }

  /**
   * Gives a task [minutes] more. A running one takes them on its hour too,
   * and whatever comes after it moves on the next read.
   */
  async extendTask(
    user: CalendarUser,
    taskId: string,
    minutes: number,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    const day = await this._timeline.day(user, 1, now);
    const task = pendingOf(day, taskId);
    const live = day.live.get(taskId);

    if (live === undefined) {
      if (task.minutes + minutes < 5) {
        throw new BadRequestException('Essa duração é curta demais.');
      }
      await this._tasks.update(user, {
        ...task,
        minutes: task.minutes + minutes,
      });
      return;
    }

    const event = await this._extend(user, live, minutes, trace, now);
    await this._tasks.update(user, {
      ...task,
      minutes: Math.round(workSecondsOf(event) / 60),
    });
  }

  /**
   * Puts [task] at [index] in the backlog.
   *
   * It leaves the queue, and the queue closes up over it on the next read.
   * A running one stops running and gives back the rest of its hour; the
   * work it owes is its whole length again, as when it is dragged back down
   * the queue.
   */
  private async _shelve(
    user: CalendarUser,
    day: Day,
    task: Task,
    index: number,
    trace: Trace,
  ): Promise<void> {
    const live = day.live.get(task.id);
    if (live !== undefined) {
      trace.log('task.unstart', { taskId: task.id });
      await this._calendar.remove(user, live);
    }

    const backlog = day.backlog.filter((it) => it.id !== task.id);
    const at = Math.max(0, Math.min(index, backlog.length));

    trace.log('task.shelve', { taskId: task.id, index: at });
    await this._tasks.update(user, {
      ...task,
      position: await this._positionAt(user, backlog, at),
      notBefore: undefined,
      backlog: true,
    });
  }

  // -------------------------------------------------------------------------
  // The clock
  // -------------------------------------------------------------------------

  /**
   * Keeps the calendar true as the minutes pass.
   *
   * Drags every paused block's end along with the clock, and writes down as
   * done every task whose hour ran out. Run by the minute tick and before
   * every read of the day, and safe to run any number of times: the end of a
   * paused block is always now plus what is still owed, so a second call in
   * the same minute changes nothing and a call after the server was down for
   * an hour catches the whole hour up at once.
   */
  async catchUp(
    user: CalendarUser,
    trace: Trace,
    now = new Date(),
  ): Promise<void> {
    const events = await this._calendar.events(user, undefined, now);

    for (const event of events) {
      if (!event.managed || event.pausedAt === undefined) continue;

      const end = pausedEnd(event, now);
      if (end.getTime() === Date.parse(event.endTime)) continue;

      await this._revise(user, event, { endTime: end.toISOString() }, trace);
    }

    const over = events.filter(
      (event) =>
        event.taskId !== undefined &&
        Date.parse(event.endTime) <= now.getTime(),
    );
    if (over.length === 0) return;

    const pending = new Map(
      (await this._tasks.pending(user)).map((task) => [task.id, task]),
    );
    for (const event of over) {
      const task = pending.get(event.taskId!);
      if (task === undefined) continue;

      trace.log('task.over', { taskId: task.id });
      await this._tasks.update(user, { ...task, doneAt: event.endTime });
    }
  }

  // -------------------------------------------------------------------------
  // The arithmetic underneath
  // -------------------------------------------------------------------------

  /**
   * Begins [task] at this minute, when nothing else is running.
   *
   * Something still running here is a fixed block the user chose to wait
   * for, and the task waits with them.
   */
  private async _beginIfFree(
    user: CalendarUser,
    task: Task,
    trace: Trace,
    now: Date,
  ): Promise<void> {
    const day = await this._timeline.day(user, 1, now);
    const busy = day.events.some((event) => {
      const interval = intervalOf(event);
      return interval !== undefined && isRunning(now, interval);
    });

    if (!busy) await this._begin(user, task, trace, now);
  }

  /** Writes [task] onto the calendar from this minute, as begun. */
  private async _begin(
    user: CalendarUser,
    task: Task,
    trace: Trace,
    now: Date,
  ): Promise<void> {
    const start = floorToMinute(now);
    const event = await this._calendar.create(user, {
      title: task.title,
      startTime: start.toISOString(),
      endTime: addMinutes(start, task.minutes).toISOString(),
      fixed: false,
      started: true,
      taskId: task.id,
    });
    trace.log('task.begin', { taskId: task.id, eventId: event.id });

    if (task.notBefore !== undefined) {
      await this._tasks.update(user, { ...task, notBefore: undefined });
    }
  }

  /**
   * Finishes what was running, or [task] when it was not running at all.
   *
   * A task is written down as done. Its hour, or an event's, is cut off at
   * this minute and kept as what really happened, or taken off the calendar
   * when it had not really started.
   */
  private async _finishRunning(
    user: CalendarUser,
    running: Running | undefined,
    trace: Trace,
    now: Date,
    task?: Task,
  ): Promise<void> {
    if (running !== undefined) {
      await this._finish(user, running.event, trace, now);
    }

    const done = running?.kind === 'task' ? running.task : task;
    if (done !== undefined) {
      trace.log('task.done', { taskId: done.id });
      await this._tasks.update(user, { ...done, doneAt: now.toISOString() });
    }
  }

  /**
   * Off the day, as done. A block that is running is cut off at this minute
   * and stays as the hour it took; one that started this very second, or
   * not at all, has no hour to keep.
   */
  private async _finish(
    user: CalendarUser,
    event: CalendarEvent,
    trace: Trace,
    now: Date,
  ): Promise<void> {
    const interval = intervalOf(event);
    const running = interval !== undefined && isRunning(now, interval);
    trace.log('event.done', { eventId: event.id, running });

    if (running && interval.start < now) {
      await this._revise(
        user,
        event,
        {
          endTime: now.toISOString(),
          pausedAt: undefined,
          remainingSeconds: undefined,
        },
        trace,
      );
    } else {
      await this._calendar.remove(user, event);
    }
  }

  /**
   * Pauses a running block.
   *
   * Nothing moves yet. What is written down is the moment it stopped and how
   * much work was still owed, and from then on [catchUp] drags its end along
   * with the clock so the owed work is always still ahead of it.
   */
  private async _pause(
    user: CalendarUser,
    event: CalendarEvent,
    trace: Trace,
    now: Date,
  ): Promise<void> {
    const interval = intervalOf(event);
    if (interval === undefined || !isRunning(now, interval)) {
      throw new BadRequestException('Só dá para pausar o que está rodando.');
    }
    if (event.pausedAt !== undefined) return;

    trace.log('event.pause', { eventId: event.id });
    await this._revise(
      user,
      event,
      {
        pausedAt: now.toISOString(),
        remainingSeconds: Math.max(
          0,
          (interval.end.getTime() - now.getTime()) / 1000,
        ),
      },
      trace,
    );
  }

  /** Runs a paused block again, owing exactly what it owed when it stopped. */
  private async _resume(
    user: CalendarUser,
    event: CalendarEvent,
    trace: Trace,
    now: Date,
  ): Promise<void> {
    if (event.pausedAt === undefined) return;

    const pausedFor = Math.max(
      0,
      (now.getTime() - Date.parse(event.pausedAt)) / 1000,
    );

    trace.log('event.resume', { eventId: event.id, pausedFor });
    await this._revise(
      user,
      event,
      {
        endTime: pausedEnd(event, now).toISOString(),
        pausedAt: undefined,
        remainingSeconds: undefined,
        pausedSeconds: (event.pausedSeconds ?? 0) + pausedFor,
      },
      trace,
    );
  }

  /**
   * Gives a block [minutes] more, or fewer.
   *
   * The estimate was wrong, which is the whole of it: the end moves, and the
   * tasks after it follow on the next read. A paused block owes the extra
   * minutes too.
   */
  private async _extend(
    user: CalendarUser,
    event: CalendarEvent,
    minutes: number,
    trace: Trace,
    now: Date,
  ): Promise<CalendarEvent> {
    const end = addMinutes(new Date(event.endTime), minutes);

    if (end <= now || end.getTime() <= Date.parse(event.startTime)) {
      throw new BadRequestException('Essa duração já passou.');
    }

    trace.log('event.extend', { eventId: event.id, minutes });
    return this._revise(
      user,
      event,
      {
        endTime: end.toISOString(),
        ...(event.pausedAt === undefined
          ? {}
          : {
              remainingSeconds: Math.max(
                0,
                (event.remainingSeconds ?? 0) + minutes * 60,
              ),
            }),
      },
      trace,
    );
  }

  /** The new title and notes of [event], written when they changed. */
  private async _reword(
    user: CalendarUser,
    event: CalendarEvent,
    edit: EventEdit,
    trace: Trace,
  ): Promise<CalendarEvent> {
    const words = {
      ...(edit.title !== undefined && edit.title !== event.title
        ? { title: edit.title }
        : {}),
      ...(edit.notes !== undefined && edit.notes !== event.notes
        ? { notes: edit.notes }
        : {}),
    };

    return Object.keys(words).length === 0
      ? event
      : this._revise(user, event, words, trace);
  }

  /**
   * Changes anything about one event.
   *
   * A key named in [changes] with an undefined value clears it, which is how
   * a pause is lifted.
   */
  private async _revise(
    user: CalendarUser,
    event: CalendarEvent,
    changes: Partial<Omit<CalendarEvent, 'id' | 'managed'>>,
    trace: Trace,
  ): Promise<CalendarEvent> {
    trace.log('event.revise', {
      eventId: event.id,
      keys: Object.keys(changes),
    });

    return this._calendar.save(user, { ...event, ...changes });
  }

  /** One event Lunna booked, or a refusal. */
  private async _event(
    user: CalendarUser,
    eventId: string,
  ): Promise<CalendarEvent> {
    const event = await this._calendar.find(user, eventId);
    if (event === undefined) {
      throw new NotFoundException(`No event "${eventId}"`);
    }
    if (!event.managed) {
      throw new BadRequestException('Uma reunião não pode ser mudada aqui.');
    }

    return event;
  }

  /** The hour [taskId] is taking, when it was begun and is not over. */
  private async _live(
    user: CalendarUser,
    taskId: string,
    now: Date,
  ): Promise<CalendarEvent | undefined> {
    const day = await this._timeline.day(user, 1, now);
    pendingOf(day, taskId);

    return day.live.get(taskId);
  }

  /**
   * The position that puts a task at [index] in [queue], which does not
   * have it in.
   *
   * Halfway between its new neighbours, so a drag writes one row. Halving
   * runs out after fifty-odd drags into the same spot, and then the queue
   * is numbered again from zero first.
   */
  private async _positionAt(
    user: CalendarUser,
    queue: Task[],
    index: number,
  ): Promise<number> {
    const before = queue[index - 1]?.position;
    const after = queue[index]?.position;

    if (before === undefined && after === undefined) return 0;
    if (before === undefined) return after - 1;
    if (after === undefined) return before + 1;
    if (after - before > 1e-9) return (before + after) / 2;

    for (const [position, task] of queue.entries()) {
      task.position = position;
      await this._tasks.update(user, task);
    }

    return index - 0.5;
  }
}

/** The tasks waiting their turn, in queue order: everything not begun. */
function queueOf(day: Day): Task[] {
  return day.tasks.filter((task) => !day.live.has(task.id));
}

/** The task [taskId] while it is still to do, in the backlog or not, or a 404. */
function pendingOf(day: Day, taskId: string): Task {
  const task = [...day.tasks, ...day.backlog].find((it) => it.id === taskId);
  if (task === undefined) throw new NotFoundException(`No task "${taskId}"`);

  return task;
}

/**
 * Whatever Lunna booked that is running now, other than [taskId].
 *
 * A meeting is somebody else's and is never asked about. A task waiting to
 * be begun has not displaced anything, so dragging something over it is not
 * the destructive move: it is not on the calendar at all.
 */
function runningOf(day: Day, taskId: string): Running | undefined {
  for (const event of day.events) {
    const interval = intervalOf(event);
    if (!event.managed || interval === undefined) continue;
    if (!isRunning(day.now, interval)) continue;

    if (event.taskId === undefined) return { kind: 'event', event };
    if (event.taskId === taskId) continue;

    const task = day.tasks.find((it) => it.id === event.taskId);
    if (task !== undefined && day.live.get(task.id) === event) {
      return { kind: 'task', task, event };
    }
  }

  return undefined;
}

/**
 * Where a paused block ends at [now]: what it still owes, from now.
 *
 * Rounded up to the minute, so the tick moves the calendar once a minute and
 * not once a second.
 */
function pausedEnd(event: CalendarEvent, now: Date): Date {
  const end = new Date(now.getTime() + (event.remainingSeconds ?? 0) * 1000);
  if (end.getSeconds() !== 0 || end.getMilliseconds() !== 0) {
    end.setSeconds(60, 0);
  }

  return end;
}

/** Whichever of [a] and [b] comes later. */
function laterOf(a: Date, b: Date): Date {
  return a > b ? a : b;
}
