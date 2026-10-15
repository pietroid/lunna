import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CalendarService } from '../calendar/calendar.service';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { TimelineCard } from '../events/entities/event.entity';
import { EventLayoutService } from '../events/event-layout.service';
import { TimelineService } from '../events/timeline.service';
import { TaskStore } from '../tasks/task.store';
import {
  DEFAULT_WORK_DAY,
  formatMinuteOfDay,
  Interval,
  nextFreeSlot,
  roundUpToFiveMinutes,
} from '../time/work-hours';
import {
  addDaysIn,
  formatTimeIn,
  instantOf,
  isoDayIn,
  isoIn,
  sameDayIn,
  startOfDayIn,
  Zone,
} from '../time/zone';
import { contextLine, SYSTEM_PROMPT, TOOLS } from './agent.prompt';
import { ChatMessage, OpenRouterClient, ToolCall } from './openrouter.client';
import {
  CHANGE_KINDS,
  ChangeKind,
  Plan,
  PlanChange,
  PlanStore,
  Undo,
} from './plan';

/** One message of the conversation, as the app keeps it. */
export interface AgentMessage {
  role: 'user' | 'assistant';
  text: string;
}

/** What one turn answers with. */
export interface AgentReply {
  reply: string;
  /** What the agent did, one short line each, in the order it did it. */
  steps: string[];
  /** The changes it proposes, when it proposes any. */
  plan?: { id: string; changes: PlanChange[] };
}

/** A proposal the agent makes without being asked. */
export interface Suggestion {
  text: string;
  plan: { id: string; changes: PlanChange[] };
}

/** How many model round-trips one turn is allowed. */
const MAX_ITERATIONS = 6;

/** How far ahead the agent can see and plan. */
const HORIZON_DAYS = 14;

/**
 * Lunna's agent: it reads the day and proposes changes to it.
 *
 * The contract is Focus's, made stricter: reads run the moment the model
 * asks, and there are no writes at all. The one tool that looks like a write,
 * `propose_plan`, only files a [Plan]. The user applies it, and it is this
 * service, not the model, that makes each change, through the same layout
 * the app's own buttons go through, keeping enough to undo it.
 */
@Injectable()
export class AgentService {
  private readonly _plans = new PlanStore();
  /** The suggestion last offered to each person, so it is offered once. */
  private readonly _suggested = new Map<string, Plan>();

  constructor(
    private readonly _model: OpenRouterClient,
    private readonly _timeline: TimelineService,
    private readonly _layout: EventLayoutService,
    private readonly _calendar: CalendarService,
    private readonly _tasks: TaskStore,
  ) {}

  get configured(): boolean {
    return this._model.configured;
  }

  /** Answers the last message of [history]. Changes nothing. */
  async turn(
    user: CalendarUser,
    history: AgentMessage[],
    focusDay: string | undefined,
    trace: Trace,
    now = new Date(),
  ): Promise<AgentReply> {
    const zone = this._timeline.zone(user);
    const workDay = user.workDay ?? DEFAULT_WORK_DAY;
    const messages: ChatMessage[] = [
      { role: 'system', content: SYSTEM_PROMPT },
      {
        role: 'system',
        content: contextLine(
          wallText(now, zone),
          weekdayOf(now, zone),
          zone,
          {
            start: formatMinuteOfDay(workDay.start),
            end: formatMinuteOfDay(workDay.end),
          },
          focusDay,
        ),
      },
      ...history.map((it) => ({ role: it.role, content: it.text })),
    ];

    const steps: string[] = [];
    let plan: Plan | undefined;

    for (let iteration = 1; iteration <= MAX_ITERATIONS; iteration++) {
      const outcome = await trace.span('agent.model', { iteration }, () =>
        this._model.generate(messages, TOOLS),
      );

      if (outcome.kind === 'final') {
        return this._reply(outcome.content, steps, plan);
      }

      messages.push({
        role: 'assistant',
        content: '',
        tool_calls: outcome.toolCalls,
      });

      for (const call of outcome.toolCalls) {
        const result = await this._run(user, call, now, trace, steps);
        if (result.plan !== undefined) plan = result.plan;
        messages.push({
          role: 'tool',
          tool_call_id: call.id,
          content: JSON.stringify(result.answer),
        });
      }
    }

    // Out of round-trips: one last call with no tools leaves the model
    // nothing to do but say where it got to.
    trace.warn('agent.iterationLimit');
    const closing = await this._model.generate(
      [
        ...messages,
        {
          role: 'system',
          content: 'Stop calling tools and answer now, in Portuguese.',
        },
      ],
      [],
    );

    return this._reply(
      closing.kind === 'final' ? closing.content : '',
      steps,
      plan,
    );
  }

  /** Makes every change of [planId], or none of them. */
  async apply(
    user: CalendarUser,
    planId: string,
    trace: Trace,
  ): Promise<string[]> {
    const plan = this._plans.get(user.id, planId);
    if (plan === undefined) {
      throw new NotFoundException('Esse plano expirou. Peça de novo.');
    }
    if (plan.applied !== undefined) {
      throw new ConflictException('Esse plano já foi aplicado.');
    }

    const undo: Undo[] = [];
    const touched: string[] = [];

    try {
      for (const change of plan.changes) {
        touched.push(await this._make(user, change, undo, trace));
      }
    } catch (error) {
      trace.warn('agent.applyFailed', {
        planId,
        error: error instanceof Error ? error.message : String(error),
      });
      await this._takeBack(user, undo, trace);
      throw new BadRequestException(
        'Não consegui aplicar o plano: o dia mudou desde que ele foi feito. ' +
          'Peça de novo.',
      );
    }

    plan.applied = { undo, touched };
    trace.log('agent.applied', { planId, changes: plan.changes.length });

    return touched;
  }

  /** Takes an applied plan back, every change of it, and leaves it a plan. */
  async undo(user: CalendarUser, planId: string, trace: Trace): Promise<void> {
    const plan = this._plans.get(user.id, planId);
    if (plan?.applied === undefined) {
      throw new NotFoundException('Não há mais o que desfazer.');
    }

    await this._takeBack(user, plan.applied.undo, trace);
    // Back to a proposal: the card offers Aplicar again.
    plan.applied = undefined;
    trace.log('agent.undone', { planId });
  }

  /**
   * One thing worth offering without being asked: the first task in the
   * backlog that fits in the room left today.
   *
   * No model: a suggestion is drawn every time Tempo opens, and this one
   * needs only arithmetic. It is the same plan a turn would make, so the
   * app applies and undoes it the same way.
   */
  async suggestion(
    user: CalendarUser,
    now = new Date(),
  ): Promise<Suggestion | undefined> {
    const zone = this._timeline.zone(user);
    const workDay = user.workDay ?? DEFAULT_WORK_DAY;
    const view = this._timeline.view(await this._timeline.day(user, 1, now));
    const busy: Interval[] = view.cards.map((card) => ({
      start: new Date(card.startTime),
      end: new Date(card.endTime),
    }));
    const from = roundUpToFiveMinutes(now);

    for (const task of view.backlog.slice(0, 3)) {
      const slot = nextFreeSlot(
        from,
        task.durationMinutes,
        busy,
        zone,
        workDay,
      );
      if (!sameDayIn(slot.start, now, zone)) continue;

      const at = slot.start.toISOString();
      const last = this._suggested.get(user.id);
      const offered =
        last !== undefined &&
        this._plans.get(user.id, last.id) !== undefined &&
        last.applied === undefined &&
        last.changes[0]?.id === task.id &&
        last.changes[0]?.at === at
          ? last
          : this._plans.put(
              user.id,
              [],
              [
                {
                  kind: 'move_task',
                  id: task.id,
                  title: task.title,
                  minutes: task.durationMinutes,
                  at,
                  routine: task.routine !== undefined,
                },
              ],
            );
      this._suggested.set(user.id, offered);

      return {
        text:
          `"${task.title}" está esperando no Depois eu priorizo. ` +
          `Hoje às ${formatTimeIn(slot.start, zone)} tem espaço para ela. ` +
          'Quer encaixar?',
        plan: { id: offered.id, changes: offered.changes },
      };
    }

    return undefined;
  }

  private _reply(
    content: string,
    steps: string[],
    plan: Plan | undefined,
  ): AgentReply {
    const reply =
      content.trim() !== ''
        ? content.trim()
        : plan !== undefined
          ? 'Fica assim:'
          : 'Não consegui responder agora. Tente de novo.';

    return {
      reply,
      steps: [...steps, ...(plan?.findings ?? [])],
      plan:
        plan === undefined ? undefined : { id: plan.id, changes: plan.changes },
    };
  }

  /** Runs one tool call, and says what it found in the model's terms. */
  private async _run(
    user: CalendarUser,
    call: ToolCall,
    now: Date,
    trace: Trace,
    steps: string[],
  ): Promise<{ answer: unknown; plan?: Plan }> {
    let args: Record<string, unknown>;
    try {
      args = JSON.parse(call.function.arguments) as Record<string, unknown>;
    } catch {
      return { answer: { error: 'Arguments were not valid JSON.' } };
    }

    trace.log('agent.tool', { name: call.function.name });

    switch (call.function.name) {
      case 'read_timeline': {
        const read = await this._read(user, args, now);
        const step = `Olhei ${read.label}`;
        if (!steps.includes(step)) steps.push(step);
        return { answer: read.snapshot };
      }
      case 'propose_plan': {
        try {
          const plan = await this._propose(user, args, now);
          return { answer: { ok: true, changes: plan.changes.length }, plan };
        } catch (error) {
          return {
            answer: {
              error: error instanceof Error ? error.message : String(error),
            },
          };
        }
      }
      default:
        return { answer: { error: `Unknown tool ${call.function.name}` } };
    }
  }

  /** The days the model asked for, in the words it plans in. */
  private async _read(
    user: CalendarUser,
    args: Record<string, unknown>,
    now: Date,
  ): Promise<{ label: string; snapshot: unknown }> {
    const zone = this._timeline.zone(user);
    const today = isoDayIn(now, zone);
    const from =
      typeof args.from === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(args.from)
        ? args.from
        : today;
    const span = clampInt(args.days, 1, 7, 1);
    const offset = Math.max(0, daysBetween(today, from));
    const days = Math.min(offset + span, HORIZON_DAYS);
    const view = this._timeline.view(await this._timeline.day(user, days, now));
    const until = isoDayIn(
      addDaysIn(startOfDayIn(dayInstant(from, zone), zone), span, zone),
      zone,
    );

    const items = view.cards
      .filter((card) => card.day >= from && card.day < until)
      .map((card) => ({
        id: card.id,
        kind: card.kind,
        title: card.title,
        start: wallText(new Date(card.startTime), zone),
        end: wallText(new Date(card.endTime), zone),
        minutes: card.workMinutes,
        fixed: card.fixed,
        routine: card.routine !== undefined,
        started: card.started || Date.parse(card.startTime) <= now.getTime(),
        anchored: card.notBefore !== undefined,
      }));

    return {
      label: span === 1 ? dayLabel(from, today, zone) : `${span} dias`,
      snapshot: {
        from,
        days: span,
        items,
        backlog: view.backlog.map((card) => ({
          id: card.id,
          title: card.title,
          minutes: card.durationMinutes,
        })),
      },
    };
  }

  /** Checks a proposal against the day, and files it when it holds. */
  private async _propose(
    user: CalendarUser,
    args: Record<string, unknown>,
    now: Date,
  ): Promise<Plan> {
    const zone = this._timeline.zone(user);
    const raw = Array.isArray(args.changes) ? args.changes : [];
    if (raw.length === 0) throw new Error('A plan needs at least one change.');

    const view = this._timeline.view(
      await this._timeline.day(user, HORIZON_DAYS, now),
    );
    const changes = raw.map((item) =>
      this._change(item as Record<string, unknown>, view, zone, now),
    );
    const findings = (Array.isArray(args.findings) ? args.findings : [])
      .filter((it): it is string => typeof it === 'string' && it.trim() !== '')
      .slice(0, 3)
      .map((it) => it.trim().slice(0, 80));

    return this._plans.put(user.id, findings, changes);
  }

  private _change(
    item: Record<string, unknown>,
    view: {
      tasks: TimelineCard[];
      cards: TimelineCard[];
      backlog: { id: string; title: string; durationMinutes: number }[];
    },
    zone: Zone,
    now: Date,
  ): PlanChange {
    const kind = item.kind as ChangeKind;
    if (!CHANGE_KINDS.includes(kind)) {
      throw new Error(`Unknown change kind "${String(item.kind)}".`);
    }

    const at = parseWall(item.at, zone);
    if (at === undefined) {
      throw new Error(`"at" must be YYYY-MM-DDTHH:mm, got ${String(item.at)}.`);
    }
    if (at.getTime() < now.getTime() - 60_000) {
      throw new Error(`${wallText(at, zone)} is in the past.`);
    }

    if (kind === 'add_task' || kind === 'add_event') {
      const title = typeof item.title === 'string' ? item.title.trim() : '';
      if (title === '') throw new Error(`${kind} needs a title.`);

      return {
        kind,
        title: title.slice(0, 200),
        minutes: clampInt(item.minutes, 5, 720, 30),
        at: at.toISOString(),
        routine: false,
      };
    }

    const id = typeof item.id === 'string' ? item.id : '';

    if (kind === 'move_task') {
      const queued = view.tasks.find((card) => card.id === id);
      const waiting = view.backlog.find((card) => card.id === id);
      if (queued === undefined && waiting === undefined) {
        throw new Error(`No task with id "${id}".`);
      }
      if (queued?.started === true) {
        throw new Error(`"${queued.title}" has already started.`);
      }

      return {
        kind,
        id,
        title: queued?.title ?? waiting!.title,
        minutes: queued?.workMinutes ?? waiting!.durationMinutes,
        at: at.toISOString(),
        before: queued?.startTime,
        routine: queued?.routine !== undefined,
      };
    }

    const event = view.cards.find(
      (card) => card.id === id && card.kind === 'event',
    );
    if (event === undefined) throw new Error(`No event with id "${id}".`);
    if (!event.managed) throw new Error(`"${event.title}" is not Lunna's.`);
    if (Date.parse(event.startTime) <= now.getTime()) {
      throw new Error(`"${event.title}" has already started.`);
    }

    return {
      kind,
      id,
      title: event.title,
      minutes: event.workMinutes,
      at: at.toISOString(),
      before: event.startTime,
      routine: event.routine !== undefined,
    };
  }

  /** Makes one change, noting how to take it back. Answers the card's id. */
  private async _make(
    user: CalendarUser,
    change: PlanChange,
    undo: Undo[],
    trace: Trace,
  ): Promise<string> {
    switch (change.kind) {
      case 'add_task': {
        const id = await this._layout.createTask(
          user,
          {
            title: change.title,
            minutes: change.minutes,
            backlog: false,
            notBefore: change.at,
          },
          trace,
        );
        undo.push({ kind: 'remove_task', id });
        return id;
      }
      case 'add_event': {
        const id = await this._layout.createEvent(
          user,
          {
            title: change.title,
            durationMinutes: change.minutes,
            startTime: change.at,
          },
          trace,
        );
        undo.push({ kind: 'remove_event', id });
        return id;
      }
      case 'move_task': {
        const id = change.id!;
        const before = await this._tasks.get(user, id);
        if (before === undefined) throw new Error(`No task "${id}"`);
        await this._layout.editTask(user, id, { startTime: change.at }, trace);
        undo.push({ kind: 'restore_task', task: before });
        return id;
      }
      case 'move_event': {
        const id = change.id!;
        const before = await this._calendar.find(user, id);
        if (before === undefined) throw new Error(`No event "${id}"`);
        await this._layout.editEvent(user, id, { startTime: change.at }, trace);
        undo.push({ kind: 'restore_event', event: before });
        return id;
      }
    }
  }

  /** Undoes [undo], last change first. */
  private async _takeBack(
    user: CalendarUser,
    undo: Undo[],
    trace: Trace,
  ): Promise<void> {
    for (const step of [...undo].reverse()) {
      switch (step.kind) {
        case 'remove_task':
          await this._layout.removeTask(user, step.id, trace);
          break;
        case 'remove_event':
          await this._layout.removeEvent(user, step.id, trace);
          break;
        case 'restore_task':
          await this._tasks.update(user, step.task);
          break;
        case 'restore_event':
          await this._calendar.save(user, step.event);
          break;
      }
    }
  }
}

/** "2026-10-16T08:00", the wall clock the model reads and writes. */
function wallText(at: Date, zone: Zone): string {
  return isoIn(at, zone).slice(0, 16);
}

/** Reads the model's wall clock back into an instant in [zone]. */
function parseWall(value: unknown, zone: Zone): Date | undefined {
  if (typeof value !== 'string') return undefined;

  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/.exec(value.trim());
  if (match === null) return undefined;

  const [year, month, day, hour, minute] = match.slice(1).map(Number);
  return instantOf({ year, month, day, hour, minute, second: 0 }, zone);
}

/** Noon of the day "2026-10-16" in [zone], safely inside it. */
function dayInstant(day: string, zone: Zone): Date {
  const [year, month, date] = day.split('-').map(Number);
  return instantOf(
    { year, month, day: date, hour: 12, minute: 0, second: 0 },
    zone,
  );
}

/** Whole days from [a] to [b], both "YYYY-MM-DD". */
function daysBetween(a: string, b: string): number {
  return Math.round(
    (Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000,
  );
}

function weekdayOf(at: Date, zone: Zone): string {
  return new Intl.DateTimeFormat('en-US', {
    timeZone: zone,
    weekday: 'long',
  }).format(at);
}

/** "hoje", "amanhã", or "quinta-feira, 16/10", for a step the user reads. */
function dayLabel(day: string, today: string, zone: Zone): string {
  const offset = daysBetween(today, day);
  if (offset === 0) return 'hoje';
  if (offset === 1) return 'amanhã';

  return new Intl.DateTimeFormat('pt-BR', {
    timeZone: zone,
    weekday: 'long',
    day: '2-digit',
    month: '2-digit',
  }).format(dayInstant(day, zone));
}

function clampInt(
  value: unknown,
  min: number,
  max: number,
  fallback: number,
): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;

  return Math.min(max, Math.max(min, Math.round(value)));
}
