import { Inject, Injectable, Optional } from '@nestjs/common';
import { ANALYTICS, NoAnalytics } from '../analytics/analytics';
import type { Analytics } from '../analytics/analytics';
import { ArtifactStore } from '../artifacts/artifact.store';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { TimelineService } from '../events/timeline.service';
import { DEFAULT_WORK_DAY, formatMinuteOfDay } from '../time/work-hours';
import {
  addDaysIn,
  formatTimeIn,
  instantOf,
  isoDayIn,
  Zone,
} from '../time/zone';
import { AgentService, Subject } from './agent.service';
import {
  ChatMessage,
  ModelOutcome,
  OpenRouterClient,
  ToolDefinition,
} from './openrouter.client';

/** What one line of the composer was read as. */
export type ComposeKind = 'task' | 'event' | 'goal' | 'plan';

/**
 * What the composer will write down, drawn in the box over it before
 * anything is. Every fact is the server's: the model names a delivery by
 * its ref and a day as `YYYY-MM-DD`, and the server turns both into what
 * the app draws.
 */
export interface ComposeDraft {
  kind: ComposeKind;
  /** The task's, event's or goal's name; for a plan, the agent's answer. */
  title: string;
  /** ISO 8601: the hour, when it has one (always, for an event). */
  start?: string;
  minutes?: number;
  /** The delivery the task goes under. */
  parent?: { id: string; title: string };
  /** Its own tasks, in order. */
  subtasks: { title: string; minutes?: number }[];
  /** A goal's amount, in whole reais. */
  value?: number;
  /** A goal's last day, `YYYY-MM-DD`. */
  due?: string;
  /** A plan's turn: the conversation it was written into. */
  conversationId?: string;
  /** A plan's id, for Aplicar; absent when the agent proposed nothing. */
  planId?: string;
  /** A plan's changes, one line each. */
  changes: string[];
}

/** How long the fast read may take before the agent's turn takes over. */
export const COMPOSE_TIMEOUT_MS = 8_000;

/** How many subtasks one line may carry. */
const MAX_SUBTASKS = 12;

const READ_TOOL: ToolDefinition = {
  type: 'function',
  function: {
    name: 'read_request',
    description:
      'Say what one line the person typed or said is, so it can be written down after they confirm.',
    parameters: {
      type: 'object',
      properties: {
        kind: {
          type: 'string',
          enum: ['task', 'event', 'goal', 'plan'],
          description:
            'task: one thing to do. event: one block whose hour is the point of it (a meeting, an appointment). goal: an amount of money to bill by a day. plan: anything else, a question, or more than one change to the day.',
        },
        title: {
          type: 'string',
          description:
            'The name, short, in the words the person used, without the hour or the length.',
        },
        day: {
          type: 'string',
          description: 'YYYY-MM-DD, when a day was said.',
        },
        time: { type: 'string', description: 'HH:MM, when an hour was said.' },
        minutes: {
          type: 'integer',
          description: 'How long, when said (an event without one: 60).',
        },
        parent: {
          type: 'string',
          description:
            'The ref (p1, p2…) of the delivery it goes under, only when the person named one.',
        },
        subtasks: {
          type: 'array',
          description:
            'A task’s own steps, in order, when listed (after a colon, or "first… then…").',
          items: {
            type: 'object',
            properties: {
              title: { type: 'string' },
              minutes: { type: 'integer' },
            },
            required: ['title'],
          },
        },
        value: {
          type: 'integer',
          description: 'A goal’s amount, in whole reais.',
        },
      },
      required: ['kind', 'title'],
    },
  },
};

interface ReadArgs {
  kind?: unknown;
  title?: unknown;
  day?: unknown;
  time?: unknown;
  minutes?: unknown;
  parent?: unknown;
  subtasks?: unknown;
  value?: unknown;
}

/**
 * The composer: one line read into one draft.
 *
 * A single task, event or goal comes back from one short read on the
 * agent's own model (one forced tool over a short context: the date, the
 * zone, the working day, the open deliveries by ref). Anything else, a
 * read that fails, or one that takes longer than [COMPOSE_TIMEOUT_MS],
 * goes to the agent's whole turn, whose plan is the draft. Nothing is
 * written here: the app writes a draft through the routes the old sheet
 * used, and a plan through its own apply.
 */
@Injectable()
export class ComposeService {
  constructor(
    private readonly _model: OpenRouterClient,
    private readonly _agent: AgentService,
    private readonly _timeline: TimelineService,
    private readonly _artifacts: ArtifactStore,
    @Optional()
    @Inject(ANALYTICS)
    private readonly _analytics: Analytics = new NoAnalytics(),
  ) {}

  async read(
    user: CalendarUser,
    text: string,
    about: Subject | undefined,
    trace: Trace,
    now = new Date(),
  ): Promise<ComposeDraft> {
    const began = Date.now();
    const zone = this._timeline.zone(user);
    const open = (await this._artifacts.list(user)).filter(
      (it) => it.doneAt === undefined,
    );
    const refs = new Map(open.map((it, i) => [`p${i + 1}`, it]));

    let draft: ComposeDraft | undefined;
    try {
      const outcome = await withTimeout(
        this._model.generate(
          this._context(user, zone, refs, text, about, now),
          [READ_TOOL],
          { force: READ_TOOL.function.name },
        ),
        COMPOSE_TIMEOUT_MS,
      );
      draft = draftOf(outcome, refs, zone, now);
    } catch (error) {
      trace.log('compose.fallback', {
        reason: error instanceof Error ? error.message : String(error),
      });
    }

    const fast = draft !== undefined;
    draft ??= await this._plan(user, text, about, trace, now);
    const ms = Date.now() - began;
    trace.log('compose.read', { kind: draft.kind, ms, fast });
    this._analytics.capture(user.id, 'compose_kind', {
      kind: draft.kind,
      ms,
      fast,
    });
    return draft;
  }

  /** The agent's whole turn on [text], its plan as the draft. */
  private async _plan(
    user: CalendarUser,
    text: string,
    about: Subject | undefined,
    trace: Trace,
    now: Date,
  ): Promise<ComposeDraft> {
    const turn = await this._agent.turn(
      user,
      undefined,
      [{ role: 'user', text }],
      undefined,
      about,
      trace,
      now,
    );
    const zone = this._timeline.zone(user);
    return {
      kind: 'plan',
      title: turn.reply,
      subtasks: [],
      conversationId: turn.conversationId,
      ...(turn.plan === undefined ? {} : { planId: turn.plan.id }),
      changes: (turn.plan?.changes ?? []).map((it) =>
        it.at === undefined
          ? `${it.title} · Para depois`
          : `${it.title} · ${formatTimeIn(new Date(it.at), zone)}`,
      ),
    };
  }

  private _context(
    user: CalendarUser,
    zone: Zone,
    refs: Map<string, { id: string; title: string }>,
    text: string,
    about: Subject | undefined,
    now: Date,
  ): ChatMessage[] {
    const workDay = user.workDay ?? DEFAULT_WORK_DAY;
    const weekday = new Intl.DateTimeFormat('en-US', {
      timeZone: zone,
      weekday: 'long',
    }).format(now);
    const deliveries =
      refs.size === 0
        ? 'none'
        : [...refs].map(([ref, it]) => `${ref} · ${it.title}`).join('\n');
    const page =
      about !== undefined && 'artifactId' in about
        ? about.artifactId
        : undefined;
    const opened =
      page === undefined
        ? undefined
        : [...refs].find(([, it]) => it.id === page);

    return [
      {
        role: 'system',
        content: [
          'You read one line a person typed or said in a day planner, in Brazilian Portuguese, and call read_request once.',
          `Now: ${weekday} ${isoDayIn(now, zone)} ${formatTimeIn(now, zone)} (${zone}). Tomorrow is ${isoDayIn(addDaysIn(now, 1, zone), zone)}.`,
          `The working day: ${formatMinuteOfDay(workDay.start)} to ${formatMinuteOfDay(workDay.end)}.`,
          `Open deliveries:\n${deliveries}`,
          ...(opened === undefined
            ? []
            : [
                `The line was written on the page of ${opened[0]}: a task goes under it unless said otherwise.`,
              ]),
          'One task, event or goal: say it. A question, or more than one change to the day: plan.',
        ].join('\n'),
      },
      { role: 'user', content: text },
    ];
  }
}

/** The model's call as a draft; undefined when it is not one to trust. */
export function draftOf(
  outcome: ModelOutcome,
  refs: Map<string, { id: string; title: string }>,
  zone: Zone,
  now: Date,
): ComposeDraft | undefined {
  if (outcome.kind !== 'tool_calls') return undefined;
  const call = outcome.toolCalls.find(
    (it) => it.function.name === READ_TOOL.function.name,
  );
  if (call === undefined) return undefined;

  let args: ReadArgs;
  try {
    args = JSON.parse(call.function.arguments) as ReadArgs;
  } catch {
    return undefined;
  }

  const kind = args.kind;
  const title = typeof args.title === 'string' ? args.title.trim() : '';
  if (kind === 'plan' || title === '') return undefined;
  if (kind !== 'task' && kind !== 'event' && kind !== 'goal') return undefined;

  const day = dayOf(args.day);
  const start = startOf(day ?? isoDayIn(now, zone), args.time, zone);
  const minutes = lengthOf(args.minutes);

  if (kind === 'goal') {
    const value = lengthOf(args.value);
    if (value === undefined || day === undefined) return undefined;
    return { kind, title, value, due: day, subtasks: [], changes: [] };
  }

  if (kind === 'event') {
    if (start === undefined) return undefined;
    return {
      kind,
      title,
      start: start.toISOString(),
      minutes: minutes ?? 60,
      subtasks: [],
      changes: [],
    };
  }

  const parent =
    typeof args.parent === 'string' ? refs.get(args.parent.trim()) : undefined;
  const subtasks = Array.isArray(args.subtasks)
    ? (args.subtasks as { title?: unknown; minutes?: unknown }[])
        .map((it) => ({
          title: typeof it?.title === 'string' ? it.title.trim() : '',
          minutes: lengthOf(it?.minutes),
        }))
        .filter((it) => it.title !== '')
        .slice(0, MAX_SUBTASKS)
        .map((it) => (it.minutes === undefined ? { title: it.title } : it))
    : [];

  return {
    kind,
    title,
    ...(start === undefined ? {} : { start: start.toISOString() }),
    ...(minutes === undefined ? {} : { minutes }),
    ...(parent === undefined
      ? {}
      : { parent: { id: parent.id, title: parent.title } }),
    subtasks,
    changes: [],
  };
}

function dayOf(raw: unknown): string | undefined {
  return typeof raw === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(raw.trim())
    ? raw.trim()
    : undefined;
}

/** The hour [time] on [day] in [zone]; undefined without an hour. */
function startOf(day: string, time: unknown, zone: Zone): Date | undefined {
  if (typeof time !== 'string') return undefined;
  const hm = /^(\d{1,2}):(\d{2})$/.exec(time.trim());
  if (hm === null) return undefined;
  const hour = Number(hm[1]);
  const minute = Number(hm[2]);
  if (hour > 23 || minute > 59) return undefined;
  const [year, month, date] = day.split('-').map(Number);
  return instantOf({ year, month, day: date, hour, minute, second: 0 }, zone);
}

function lengthOf(raw: unknown): number | undefined {
  return typeof raw === 'number' && Number.isInteger(raw) && raw > 0
    ? raw
    : undefined;
}

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  const late = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error('compose read timed out')), ms);
  });
  return Promise.race([promise, late]).finally(() => clearTimeout(timer));
}
