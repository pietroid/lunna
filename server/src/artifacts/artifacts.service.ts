import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { EventLayoutService } from '../events/event-layout.service';
import { Day, TimelineService } from '../events/timeline.service';
import { TaskStore } from '../tasks/task.store';
import { Task } from '../tasks/task.types';
import { DEFAULT_WORK_DAY, Interval, WorkDay } from '../time/work-hours';
import { atMinuteIn, instantOf, isoDayIn, Zone } from '../time/zone';
import { ArtifactStore } from './artifact.store';
import {
  Artifact,
  ArtifactEdit,
  ArtifactsAnswer,
  ArtifactTaskView,
  ArtifactView,
  CatalogCategoryView,
  CatalogType,
  Goal,
  GoalKind,
  GoalPeriod,
  GoalStart,
  GoalView,
  NewArtifact,
  QueueEnd,
  TaskPlace,
} from './artifact.types';
import {
  addDays,
  daysBetween,
  endOfMonth,
  nextStretch,
  stretchStart,
} from './stretch';

/** How many of the most used kinds the answer names. */
const TOP_TYPES = 3;

/**
 * The deliveries, the catalogue they come from, the goals they count
 * towards, and where their tasks are.
 *
 * A delivery's task is an ordinary task with `artifactId`, on the day like
 * any other: written down at the end of the backlog, and from there moved,
 * begun and finished by the day itself, through [EventLayoutService], so
 * the time rules hold. A delivery only reads where its tasks are.
 */
@Injectable()
export class ArtifactsService {
  constructor(
    private readonly _artifacts: ArtifactStore,
    private readonly _tasks: TaskStore,
    private readonly _timeline: TimelineService,
    private readonly _layout: EventLayoutService,
  ) {}

  /**
   * Everything Entregas draws: the deliveries with their tasks, the
   * catalogue, the goals measured, the schedule set against the queue, and
   * the kinds used most.
   */
  async answer(user: CalendarUser, now = new Date()): Promise<ArtifactsAnswer> {
    const zone = this._timeline.zone(user);
    const today = isoDayIn(now, zone);
    const until = endOfMonth(today);
    const [artifacts, tasks, day, categories, types, goals] = await Promise.all(
      [
        this._artifacts.list(user),
        this._tasks.ofArtifacts(user),
        this._timeline.day(user, daysBetween(today, until) + 1, now),
        this._artifacts.categories(user),
        this._artifacts.types(user),
        this._artifacts.goals(user),
      ],
    );

    const views = artifacts.map((artifact) =>
      viewOf(
        artifact,
        tasks.filter((task) => task.artifactId === artifact.id),
        day,
      ),
    );
    const open = views.filter((it) => it.doneAt === null);
    const done = views
      .filter((it) => it.doneAt !== null)
      .sort((a, b) => b.doneAt!.localeCompare(a.doneAt!));
    const doneDay = new Map(
      artifacts
        .filter((it) => it.doneAt !== undefined)
        .map((it) => [it.id, isoDayIn(new Date(it.doneAt!), zone)]),
    );

    const catalog: CatalogCategoryView[] = categories.map((category) => ({
      id: category.id,
      name: category.name,
      types: types
        .filter((type) => type.categoryId === category.id)
        .map((type) => ({
          id: type.id,
          name: type.name,
          minutes: type.minutes,
          price: type.price ?? null,
          blockMinutes: type.blockMinutes ?? null,
        })),
    }));

    const left = (it: ArtifactView) => Math.max(0, it.minutes - it.doneMinutes);
    const workDay = user.workDay ?? DEFAULT_WORK_DAY;

    return {
      artifacts: [...open, ...done],
      catalog,
      goals: goals
        .map((goal) => measure(goal, today, open, done, doneDay))
        .sort((a, b) => a.start.localeCompare(b.start)),
      schedule: {
        needMinutes: open
          .filter((it) => it.deadline !== null && it.deadline <= until)
          .reduce((sum, it) => sum + left(it), 0),
        freeMinutes: freeMinutes(day, now, today, until, zone, workDay),
        until,
      },
      topTypes: topTypes(
        artifacts,
        catalog.flatMap((it) => it.types.map((type) => type.id)),
      ),
    };
  }

  /**
   * Writes a delivery down, at the top of the queue or at its end.
   *
   * A delivery of a kind takes the kind's time, value and blocks, unless it
   * says otherwise.
   */
  async create(
    user: CalendarUser,
    input: NewArtifact,
    at: QueueEnd,
  ): Promise<void> {
    let next = input;
    if (input.typeId !== undefined) {
      const type = await this._type(user, input.typeId);
      next = {
        minutes: type.minutes,
        ...(type.price === undefined ? {} : { value: type.price }),
        ...(type.blockMinutes === undefined
          ? {}
          : { blockMinutes: type.blockMinutes }),
        ...input,
      };
    }
    const positions = (await this._artifacts.list(user))
      .filter((it) => it.doneAt === undefined)
      .map((it) => it.position);
    const position =
      positions.length === 0
        ? 0
        : at === 'top'
          ? Math.min(...positions) - 1
          : Math.max(...positions) + 1;

    const { blockMinutes, ...rest } = next;
    await this._artifacts.insert(user, {
      ...rest,
      ...(blockMinutes == null ? {} : { blockMinutes }),
      position,
    });
  }

  async edit(
    user: CalendarUser,
    id: string,
    edit: ArtifactEdit,
    now = new Date(),
  ): Promise<void> {
    const artifact = await this._require(user, id);
    const next: Artifact = { ...artifact };
    if (edit.title !== undefined) next.title = edit.title;
    if (edit.notes !== undefined) next.notes = edit.notes;
    if (edit.deadline === null) delete next.deadline;
    if (typeof edit.deadline === 'string') next.deadline = edit.deadline;
    for (const key of ['minutes', 'value', 'blockMinutes'] as const) {
      const value = edit[key];
      if (value === null) delete next[key];
      if (typeof value === 'number') next[key] = value;
    }
    if (edit.done === true && artifact.doneAt === undefined) {
      next.doneAt = now.toISOString();
    }
    if (edit.done === false) delete next.doneAt;

    await this._artifacts.update(user, next);
  }

  /**
   * Moves an open delivery to [index] in the queue of open ones, counted as
   * the queue will be once it is there. Fractional, so one row is written.
   */
  async move(user: CalendarUser, id: string, index: number): Promise<void> {
    const artifact = await this._require(user, id);
    if (artifact.doneAt !== undefined) {
      throw new BadRequestException('Essa entrega já foi entregue.');
    }
    const others = (await this._artifacts.list(user)).filter(
      (it) => it.doneAt === undefined && it.id !== id,
    );
    const at = Math.max(0, Math.min(index, others.length));
    const before = others[at - 1]?.position;
    const after = others[at]?.position;
    const position =
      before === undefined && after === undefined
        ? artifact.position
        : before === undefined
          ? after - 1
          : after === undefined
            ? before + 1
            : (before + after) / 2;

    await this._artifacts.update(user, { ...artifact, position });
  }

  /**
   * Removes a delivery.
   *
   * What was waiting in the backlog for it goes with it: nobody had given
   * it a turn yet. Whatever is on the day, or was done, stays, and simply
   * belongs to no delivery.
   */
  async remove(user: CalendarUser, id: string): Promise<void> {
    await this._require(user, id);

    for (const task of await this._tasks.ofArtifacts(user)) {
      if (task.artifactId !== id) continue;
      if (task.backlog && task.doneAt === undefined) {
        await this._tasks.remove(user, task.id);
      } else {
        await this._tasks.update(user, { ...task, artifactId: undefined });
      }
    }
    await this._artifacts.remove(user, id);
  }

  /** Writes a task down in a delivery, at the end of the backlog. */
  async addTask(
    user: CalendarUser,
    artifactId: string,
    input: { title: string; minutes: number },
    trace: Trace,
  ): Promise<void> {
    await this._require(user, artifactId);
    await this._layout.createTask(
      user,
      { ...input, backlog: true, artifactId },
      trace,
    );
  }

  /**
   * Writes a kind down in the catalogue, at the end of its shelf.
   *
   * The shelf is one she has ([categoryId]), or one named ([category]):
   * the one of that name if she has it, a new one at the end otherwise.
   */
  async addType(
    user: CalendarUser,
    input: {
      name: string;
      minutes: number;
      price?: number;
      blockMinutes?: number;
      categoryId?: string;
      category?: string;
    },
  ): Promise<void> {
    const categories = await this._artifacts.categories(user);
    let categoryId = input.categoryId;
    if (categoryId !== undefined) {
      if (!categories.some((it) => it.id === categoryId)) {
        throw new BadRequestException('Essa categoria não existe mais.');
      }
    } else {
      const name = input.category!;
      const known = categories.find(
        (it) =>
          it.name.toLocaleLowerCase('pt-BR') ===
          name.toLocaleLowerCase('pt-BR'),
      );
      categoryId =
        known?.id ??
        (
          await this._artifacts.insertCategory(user, {
            name,
            position: Math.max(-1, ...categories.map((it) => it.position)) + 1,
          })
        ).id;
    }
    const shelf = (await this._artifacts.types(user)).filter(
      (it) => it.categoryId === categoryId,
    );

    await this._artifacts.insertType(user, {
      categoryId,
      name: input.name,
      minutes: input.minutes,
      ...(input.price === undefined ? {} : { price: input.price }),
      ...(input.blockMinutes === undefined
        ? {}
        : { blockMinutes: input.blockMinutes }),
      position: Math.max(-1, ...shelf.map((it) => it.position)) + 1,
    });
  }

  /**
   * Writes a goal down, counting from the stretch [now] is in or from the
   * next one.
   */
  async addGoal(
    user: CalendarUser,
    input: {
      kind: GoalKind;
      target: number;
      period: GoalPeriod;
      typeId?: string;
      start: GoalStart;
    },
    now = new Date(),
  ): Promise<void> {
    if (input.kind === 'count') await this._type(user, input.typeId!);

    const current = stretchStart(
      isoDayIn(now, this._timeline.zone(user)),
      input.period,
    );
    await this._artifacts.insertGoal(user, {
      kind: input.kind,
      target: input.target,
      period: input.period,
      ...(input.kind === 'count' ? { typeId: input.typeId } : {}),
      starts:
        input.start === 'now' ? current : nextStretch(current, input.period),
    });
  }

  async removeGoal(user: CalendarUser, id: string): Promise<void> {
    if (!(await this._artifacts.goals(user)).some((it) => it.id === id)) {
      throw new NotFoundException(`No goal "${id}"`);
    }
    await this._artifacts.removeGoal(user, id);
  }

  private async _type(user: CalendarUser, id: string): Promise<CatalogType> {
    const type = (await this._artifacts.types(user)).find((it) => it.id === id);
    if (type === undefined) {
      throw new BadRequestException('Esse tipo não existe mais.');
    }
    return type;
  }

  private async _require(user: CalendarUser, id: string): Promise<Artifact> {
    const artifact = await this._artifacts.get(user, id);
    if (artifact === undefined) {
      throw new NotFoundException(`No artifact "${id}"`);
    }
    return artifact;
  }
}

/** [artifact] as the app draws it, with [tasks], its own, on [day]. */
function viewOf(artifact: Artifact, tasks: Task[], day: Day): ArtifactView {
  const total = tasks.reduce((sum, task) => sum + task.minutes, 0);
  const done = tasks
    .filter((task) => task.doneAt !== undefined)
    .reduce((sum, task) => sum + task.minutes, 0);

  return {
    id: artifact.id,
    title: artifact.title,
    notes: artifact.notes,
    typeId: artifact.typeId ?? null,
    minutes: artifact.minutes ?? total,
    doneMinutes: done,
    value: artifact.value ?? null,
    blockMinutes: artifact.blockMinutes ?? null,
    deadline: artifact.deadline ?? null,
    createdAt: artifact.createdAt,
    doneAt: artifact.doneAt ?? null,
    tasks: tasks.map((task) => taskViewOf(task, day)),
  };
}

/**
 * [goal] over the stretch [today] is in, or over its first one while that
 * has not come.
 *
 * What counts as done is what was delivered inside the stretch (by the day
 * it was delivered on, in her zone): its value, or one for each of the
 * kind. What counts as queued is what is still open and due before the
 * stretch ends: in the stretch being measured, also what is overdue, since
 * delivering it now counts now; in one still ahead, only what falls in it.
 */
function measure(
  goal: Goal,
  today: string,
  open: ArtifactView[],
  done: ArtifactView[],
  doneDay: Map<string, string>,
): GoalView {
  const future = goal.starts > today;
  const start = future ? goal.starts : stretchStart(today, goal.period);
  const end = nextStretch(start, goal.period);
  const counts = (it: ArtifactView) =>
    goal.kind === 'money' ? (it.value ?? 0) : it.typeId === goal.typeId ? 1 : 0;
  const sum = (list: ArtifactView[]) =>
    list.reduce((total, it) => total + counts(it), 0);

  return {
    id: goal.id,
    kind: goal.kind,
    typeId: goal.typeId ?? null,
    target: goal.target,
    period: goal.period,
    start,
    end,
    done: sum(
      done.filter((it) => {
        const on = doneDay.get(it.id)!;
        return on >= start && on < end;
      }),
    ),
    queued: sum(
      open.filter(
        (it) =>
          it.deadline !== null &&
          it.deadline < end &&
          (!future || it.deadline >= start),
      ),
    ),
  };
}

/**
 * The working time not taken by anything on [day], from [now] to the end
 * of [until]: each working day's hours, less every event and every task
 * the layout placed.
 */
function freeMinutes(
  day: Day,
  now: Date,
  today: string,
  until: string,
  zone: Zone,
  workDay: WorkDay,
): number {
  const busy: Interval[] = [
    ...day.events.map((it) => ({
      start: new Date(it.startTime),
      end: new Date(it.endTime),
    })),
    ...day.placed.values(),
  ].sort((a, b) => a.start.getTime() - b.start.getTime());

  let free = 0;
  for (let date = today; date <= until; date = addDays(date, 1)) {
    const [year, month, dayOfMonth] = date.split('-').map(Number);
    const noon = instantOf(
      { year, month, day: dayOfMonth, hour: 12, minute: 0, second: 0 },
      zone,
    );
    const end = atMinuteIn(noon, workDay.end, zone).getTime();
    let cursor = Math.max(
      atMinuteIn(noon, workDay.start, zone).getTime(),
      now.getTime(),
    );
    for (const interval of busy) {
      if (cursor >= end) break;
      const from = interval.start.getTime();
      const to = interval.end.getTime();
      if (to <= cursor || from >= end) continue;
      if (from > cursor) free += from - cursor;
      cursor = Math.max(cursor, to);
    }
    if (cursor < end) free += end - cursor;
  }

  return Math.floor(free / 60_000);
}

/**
 * The kinds of the most deliveries, open or delivered, all time; [order],
 * the catalogue's, breaks ties. A kind never used is not among them.
 */
function topTypes(artifacts: Artifact[], order: string[]): string[] {
  const uses = new Map<string, number>();
  for (const it of artifacts) {
    if (it.typeId !== undefined) {
      uses.set(it.typeId, (uses.get(it.typeId) ?? 0) + 1);
    }
  }
  return order
    .filter((id) => uses.has(id))
    .sort((a, b) => uses.get(b)! - uses.get(a)!)
    .slice(0, TOP_TYPES);
}

/** Where [task] is, and its hour when it is on [day]. */
function taskViewOf(task: Task, day: Day): ArtifactTaskView {
  const place: TaskPlace =
    task.doneAt !== undefined
      ? 'done'
      : task.backlog
        ? 'backlog'
        : task.notBefore !== undefined
          ? 'scheduled'
          : 'queue';
  const live = day.live.get(task.id);
  const at =
    place === 'queue' || place === 'scheduled'
      ? (live?.startTime ?? day.placed.get(task.id)?.start.toISOString())
      : undefined;

  return {
    id: task.id,
    title: task.title,
    notes: task.notes,
    minutes: task.minutes,
    place,
    ...(at === undefined ? {} : { at }),
    ...(task.doneAt === undefined ? {} : { doneAt: task.doneAt }),
  };
}
