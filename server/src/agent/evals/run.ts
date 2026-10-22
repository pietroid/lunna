/**
 * Runs the agent's eval cases against a real model, through OpenRouter.
 *
 *   npm run eval:agent -- --model google/gemini-3.1-flash-lite --k 4 --budget 0.5
 *   npm run eval:agent -- --model a,b,c --k 4 --budget 0.5 --out runs/today
 *   npm run eval:agent -- --model a --case between-is-a-place --k 1
 *   npm run eval:agent -- --model a --schema flat,variants --k 1
 *
 * Each case starts from its own day in memory, at its own frozen minute, and
 * is graded on the day the agent leaves after Aplicar, not on its words,
 * and then on Desfazer: undoing the plan must leave every row as it was.
 * pass^k is the share of cases that passed every one of their k runs: the
 * number to watch, since a request that fails one time in four feels broken.
 *
 * This costs money and is never run in CI. A model stops once the cost
 * OpenRouter reports for it reaches --budget (USD). Several models run side
 * by side, one process each.
 */
import { spawn } from 'child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'fs';
import { join } from 'path';
import { ConfigService } from '@nestjs/config';
import FakeTimers from '@sinonjs/fake-timers';
import { CalendarService } from '../../calendar/calendar.service';
import { MemoryCalendarStore } from '../../calendar/calendar.store';
import { CalendarUser } from '../../calendar/calendar.types';
import { Trace } from '../../common/trace';
import { EventLayoutService } from '../../events/event-layout.service';
import { TimelineService } from '../../events/timeline.service';
import { MemoryArtifactStore } from '../../artifacts/artifact.store';
import { ArtifactsService } from '../../artifacts/artifacts.service';
import { MemoryTaskStore } from '../../tasks/task.store';
import { DEFAULT_WORK_DAY } from '../../time/work-hours';
import { instantOf, isoIn } from '../../time/zone';
import { DEFAULT_SHAPE } from '../actions';
import { AgentMessage, AgentService, TurnResult } from '../agent.service';
import { leaksRef } from '../speech';
import { normalize } from '../board';
import { MemoryConversationStore } from '../conversation.store';
import {
  ChatMessage,
  ModelOutcome,
  OpenRouterClient,
  ToolDefinition,
} from '../openrouter.client';
import { Case, CASES, Seen, State, World } from './cases';

const ZONE = 'America/Sao_Paulo';
const DEFAULT_NOW = '2026-10-16 15:00';

const USER: CalendarUser = {
  id: 'eval-user',
  timeZone: ZONE,
  workDay: DEFAULT_WORK_DAY,
};

interface Run {
  case: string;
  run: number;
  pass: boolean;
  why?: string;
  ms: number;
  calls: number;
  cost: number;
  promptTokens: number;
  completionTokens: number;
  cachedTokens: number;
  reply?: string;
  steps?: string[];
  plan?: unknown;
  options?: string[];
  /** The blocks drawn, by kind. */
  blocks?: string[];
  /** Whether the model wrote a ref or a banned word, before `speakable`. */
  rawLeak: boolean;
  /** Whether one still reached the person: always a failure. */
  leaked: boolean;
  transcript?: {
    messages: ChatMessage[];
    outcome?: ModelOutcome;
    error?: string;
  }[];
}

interface ModelReport {
  /** The model, and the shape of the changes when more than one ran. */
  model: string;
  runs: Run[];
  stopped?: string;
}

function args(): Record<string, string> {
  const out: Record<string, string> = {};
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    if (!argv[i].startsWith('--')) continue;
    const next = argv[i + 1];
    out[argv[i].slice(2)] =
      next === undefined || next.startsWith('--') ? 'true' : (i++, next);
  }
  return out;
}

/** "2026-10-16 15:00" in São Paulo, as an instant. */
function instant(wall: string): Date {
  const [day, time] = wall.split(' ');
  const [year, month, date] = day.split('-').map(Number);
  const [hour, minute] = time.split(':').map(Number);
  return instantOf({ year, month, day: date, hour, minute, second: 0 }, ZONE);
}

function wallOf(iso: string): string {
  return isoIn(new Date(iso), ZONE).slice(0, 16).replace('T', ' ');
}

/** The model, keeping every call it made for the transcript. */
class RecordingClient extends OpenRouterClient {
  calls: NonNullable<Run['transcript']> = [];

  async generate(
    messages: ChatMessage[],
    tools: ToolDefinition[],
  ): Promise<ModelOutcome> {
    const entry: NonNullable<Run['transcript']>[number] = {
      messages: [...messages],
    };
    this.calls.push(entry);
    try {
      entry.outcome = await super.generate(messages, tools);
      return entry.outcome;
    } catch (error) {
      entry.error = error instanceof Error ? error.message : String(error);
      throw error;
    }
  }
}

async function runCase(
  model: string,
  schema: string,
  apiKey: string,
  c: Case,
  run: number,
): Promise<Run> {
  const now = instant(c.now ?? DEFAULT_NOW);
  const clock = FakeTimers.install({ now, toFake: ['Date'] });
  const config = new ConfigService({
    OPENROUTER_API_KEY: apiKey,
    OPENROUTER_MODEL: model,
    LUNNA_TIMEZONE: ZONE,
    AGENT_SCHEMA: schema,
  });
  const client = new RecordingClient(config);
  const tasks = new MemoryTaskStore();
  const artifacts = new MemoryArtifactStore();
  const calendar = new CalendarService(new MemoryCalendarStore(), config);
  const timeline = new TimelineService(calendar, tasks);
  const layout = new EventLayoutService(timeline, calendar, tasks, artifacts);
  const deliveries = new ArtifactsService(artifacts, tasks, timeline, layout);
  const agent = new AgentService(
    client,
    timeline,
    layout,
    calendar,
    tasks,
    artifacts,
    new MemoryConversationStore(),
    undefined,
    config,
  );
  const trace = Trace.start(USER.id, 'eval');

  const world: World = {
    async task(title, minutes, opts = {}) {
      await layout.createTask(
        USER,
        {
          title,
          minutes,
          backlog: opts.backlog === true,
          ...(opts.artifact === undefined ? {} : { artifactId: opts.artifact }),
          ...(opts.at === undefined
            ? {}
            : { notBefore: instant(opts.at).toISOString() }),
        },
        trace,
        now,
      );
    },
    async artifact(title, deadline, opts = {}) {
      return deliveries.create(
        USER,
        {
          title,
          ...(deadline === undefined ? {} : { deadline }),
          ...(opts.value === undefined ? {} : { value: opts.value }),
          ...(opts.kind === undefined ? {} : { typeId: opts.kind }),
        },
        'end',
      );
    },
    async kind(name, shelf, minutes, price) {
      return deliveries.addType(USER, {
        name,
        category: shelf,
        minutes,
        ...(price === undefined ? {} : { price }),
      });
    },
    async goal(kind, target, period, typeId) {
      await deliveries.addGoal(
        USER,
        { kind, target, period, typeId, start: 'now' },
        now,
      );
    },
    async event(title, at, minutes = 60) {
      await layout.createEvent(
        USER,
        {
          title,
          durationMinutes: minutes,
          startTime: instant(at).toISOString(),
        },
        trace,
      );
    },
  };

  const result: Run = {
    case: c.id,
    run,
    pass: false,
    ms: 0,
    calls: 0,
    cost: 0,
    promptTokens: 0,
    completionTokens: 0,
    cachedTokens: 0,
    rawLeak: false,
    leaked: false,
  };
  const started = performance.now();

  try {
    await c.setup?.(world);
    // Each thing said is a turn of one conversation; the last is checked.
    const said = typeof c.said === 'string' ? [c.said] : c.said;
    const history: AgentMessage[] = [];
    let conversationId: string | undefined;
    let reply: TurnResult | undefined;
    try {
      for (const text of said) {
        history.push({ role: 'user', text });
        reply = await agent.turn(
          USER,
          conversationId,
          [...history],
          undefined,
          undefined,
          trace,
          now,
        );
        conversationId = reply.conversationId;
        history.push({ role: 'assistant', text: reply.reply });
        result.rawLeak ||= reply.raw.some(
          (it) => leaksRef(it) || BANNED.test(it),
        );
        result.leaked ||= reply.blocks.some(
          (it) =>
            (it.kind === 'caption' && leaks(it.text)) ||
            (it.kind === 'cards' && leaks(it.title ?? '')) ||
            (it.kind === 'choices' &&
              it.options.some((o) => leaks(o.label) || leaks(o.say ?? ''))),
        );
      }
    } finally {
      result.ms = Math.round(performance.now() - started);
    }
    reply = reply!;
    result.reply = reply.reply;
    result.steps = reply.steps;
    result.plan = reply.plan;
    result.options = reply.options.map((it) => it.label);
    result.blocks = reply.blocks.map((it) => it.kind);

    const choices = reply.blocks.some((it) => it.kind === 'choices');
    const asked =
      reply.plan === undefined &&
      (choices || reply.options.length > 0 || reply.reply.includes('?'));
    const verdict = (): true | string => {
      switch (c.expect) {
        case 'ask':
          return asked
            ? true
            : reply.plan === undefined
              ? 'neither a plan nor a question'
              : 'proposed instead of asking';
        case 'answer':
          return reply.plan === undefined && reply.options.length === 0
            ? true
            : 'proposed a change to a question';
        case 'plan':
          if (reply.plan === undefined)
            return asked ? 'asked instead of proposing' : 'no plan';
          return 'apply';
        case 'either':
          if (reply.plan === undefined)
            return asked ? true : 'neither a plan nor a question';
          return 'apply';
      }
    };

    const missing =
      c.drawn !== undefined && !reply.blocks.some((it) => it.kind === c.drawn)
        ? `no ${c.drawn} block`
        : undefined;
    let outcome =
      missing !== undefined
        ? missing
        : result.leaked
          ? 'a ref or a banned word reached the person'
          : verdict();
    if (outcome === 'apply') {
      const before = await stateOf(timeline, artifacts, tasks, now);
      await agent.apply(USER, reply.plan!.id, trace, now);
      outcome =
        c.check === undefined
          ? true
          : c.check(await stateOf(timeline, artifacts, tasks, now));
      // Desfazer must leave everything as it was before Aplicar.
      if (outcome === true) {
        await agent.undo(USER, reply.plan!.id, trace);
        const undone = await stateOf(timeline, artifacts, tasks, now);
        if (JSON.stringify(undone) !== JSON.stringify(before)) {
          outcome = 'undo left the state changed';
        }
      }
    }
    result.pass = outcome === true;
    if (outcome !== true) result.why = outcome;
  } catch (error) {
    result.why = `threw: ${error instanceof Error ? error.message : String(error)}`;
  } finally {
    clock.uninstall();
  }

  for (const call of client.calls) {
    const usage = call.outcome?.usage;
    result.calls++;
    result.cost += usage?.cost ?? 0;
    result.promptTokens += usage?.promptTokens ?? 0;
    result.completionTokens += usage?.completionTokens ?? 0;
    result.cachedTokens += usage?.cachedTokens ?? 0;
  }
  if (!result.pass) result.transcript = client.calls;

  return result;
}

/** Words the person must never read (the app's glossary, §5.1). */
const BANNED = /\b(backlog|sistema|servidor|âncora|ancorad[ao])\b/i;

function leaks(text: string): boolean {
  return leaksRef(text) || BANNED.test(text);
}

async function stateOf(
  timeline: TimelineService,
  artifacts: MemoryArtifactStore,
  tasks: MemoryTaskStore,
  now: Date,
): Promise<State> {
  const view = timeline.view(await timeline.day(USER, 14, now));
  const [list, types, goals, theirs] = await Promise.all([
    artifacts.list(USER),
    artifacts.types(USER),
    artifacts.goals(USER),
    tasks.ofArtifacts(USER),
  ]);
  const cards: Seen[] = [
    ...view.cards.map((card) => ({
      title: card.title,
      kind: card.kind,
      at: wallOf(card.startTime),
      minutes: card.workMinutes,
      anchored: card.notBefore !== undefined,
      backlog: false,
    })),
    ...view.backlog.map((card) => ({
      title: card.title,
      kind: 'task' as const,
      minutes: card.durationMinutes,
      anchored: false,
      backlog: true,
    })),
  ];

  return {
    cards,
    artifacts: [
      ...list.filter((it) => it.doneAt === undefined),
      ...list.filter((it) => it.doneAt !== undefined),
    ].map((it) => ({
      title: it.title,
      done: it.doneAt !== undefined,
      ...(it.deadline === undefined ? {} : { deadline: it.deadline }),
      ...(it.value === undefined ? {} : { value: it.value }),
      ...(it.typeId === undefined
        ? {}
        : { kind: types.find((type) => type.id === it.typeId)?.name }),
      tasks: theirs
        .filter((task) => task.artifactId === it.id)
        .map((task) => task.title),
    })),
    kinds: types.map((it) => it.name),
    goals: goals.map((it) => ({
      kind: it.kind,
      target: it.target,
      period: it.period,
    })),
    queue: view.tasks.map((it) => it.title),
    named: (title) => cards.filter((card) => sameStem(card.title, title)),
  };
}

/** Titles that say the same thing, as "Treino" does "Treinar". */
function sameStem(a: string, b: string): boolean {
  const x = normalize(a).split(' ');
  const y = normalize(b).split(' ');

  return (
    x.length === y.length &&
    x.every(
      (word, i) =>
        word === y[i] ||
        (word.length >= 5 &&
          y[i].length >= 5 &&
          word.slice(0, 5) === y[i].slice(0, 5)),
    )
  );
}

async function runModel(
  model: string,
  schema: string,
  k: number,
  budget: number,
  only?: string,
): Promise<ModelReport> {
  const apiKey = apiKeyOf();
  const report: ModelReport = { model: `${model} (${schema})`, runs: [] };
  let spent = 0;

  const picked = only?.split(',');
  for (const c of CASES.filter(
    (it) => picked === undefined || picked.includes(it.id),
  )) {
    for (let run = 1; run <= k; run++) {
      if (spent >= budget) {
        report.stopped = `budget of $${budget} spent at ${c.id} run ${run}`;
        return report;
      }
      const result = await runCase(model, schema, apiKey, c, run);
      spent += result.cost;
      report.runs.push(result);
      process.stderr.write(
        `${report.model} ${c.id} #${run} ${result.pass ? '✓' : `✗ ${result.why}`} (${result.ms} ms, $${result.cost.toFixed(4)})\n`,
      );
    }
  }

  return report;
}

/** OPENROUTER_API_KEY from the environment, or from server/.env.local. */
function apiKeyOf(): string {
  if (process.env.OPENROUTER_API_KEY) return process.env.OPENROUTER_API_KEY;
  try {
    const env = readFileSync(join(__dirname, '../../../.env.local'), 'utf8');
    const found = /^OPENROUTER_API_KEY=(.*)$/m.exec(env);
    if (found !== null && found[1].trim() !== '') return found[1].trim();
  } catch {
    // No file: say so below.
  }
  throw new Error('OPENROUTER_API_KEY is not set (nor in server/.env.local).');
}

function percentile(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[
    Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)
  ];
}

/** One Markdown row per model, and the failing cases under it. */
function summarize(reports: ModelReport[], k: number): string {
  const lines = [
    `| Model | pass^${k} | pass@1 | leak@1 (raw) | p50 | p95 | calls/turn | tokens in/turn | cost |`,
    '|---|---|---|---|---|---|---|---|---|',
  ];
  const failures: string[] = [];

  for (const report of reports) {
    const byCase = new Map<string, Run[]>();
    for (const run of report.runs)
      byCase.set(run.case, [...(byCase.get(run.case) ?? []), run]);
    const complete = [...byCase.values()].filter((runs) => runs.length === k);
    const passedAll = complete.filter((runs) =>
      runs.every((it) => it.pass),
    ).length;
    const runs = report.runs;
    const sum = (f: (r: Run) => number) => runs.reduce((a, r) => a + f(r), 0);

    lines.push(
      `| ${report.model} | ${passedAll}/${complete.length} (${Math.round((100 * passedAll) / Math.max(1, complete.length))}%) | ` +
        `${Math.round((100 * runs.filter((r) => r.pass).length) / Math.max(1, runs.length))}% | ` +
        `${Math.round((100 * runs.filter((r) => r.rawLeak).length) / Math.max(1, runs.length))}% | ` +
        `${(
          percentile(
            runs.map((r) => r.ms),
            50,
          ) / 1000
        ).toFixed(1)} s | ${(
          percentile(
            runs.map((r) => r.ms),
            95,
          ) / 1000
        ).toFixed(1)} s | ` +
        `${(sum((r) => r.calls) / Math.max(1, runs.length)).toFixed(2)} | ${Math.round(sum((r) => r.promptTokens) / Math.max(1, runs.length))} | ` +
        `$${sum((r) => r.cost).toFixed(3)}${report.stopped === undefined ? '' : ' (stopped)'} |`,
    );

    for (const [id, caseRuns] of byCase) {
      const failed = caseRuns.filter((r) => !r.pass);
      if (failed.length === 0) continue;
      failures.push(
        `- ${report.model} · \`${id}\` ${failed.length}/${caseRuns.length}: ${[...new Set(failed.map((r) => r.why))].join('; ')}`,
      );
    }
    if (report.stopped !== undefined)
      failures.push(`- ${report.model}: ${report.stopped}`);
  }

  return [
    ...lines,
    '',
    ...(failures.length === 0
      ? ['Every run passed.']
      : ['Failures:', ...failures]),
  ].join('\n');
}

async function main(): Promise<void> {
  const a = args();
  const models = (
    a.model ??
    process.env.OPENROUTER_MODEL ??
    'google/gemini-3.1-flash-lite'
  )
    .split(',')
    .map((it) => it.trim());
  const k = Number(a.k ?? 4);
  const budget = Number(a.budget ?? 0.5);
  const schemas = (a.schema ?? process.env.AGENT_SCHEMA ?? DEFAULT_SHAPE)
    .split(',')
    .map((it) => it.trim());
  const runs = models.flatMap((model) =>
    schemas.map((schema) => ({ model, schema })),
  );

  // The layout writes a trace line for every step; the report is enough.
  console.log = () => {};
  console.warn = () => {};
  console.error = () => {};

  if (a.child !== undefined) {
    process.stdout.write(
      JSON.stringify(await runModel(models[0], schemas[0], k, budget, a.case)),
    );
    return;
  }

  const reports =
    runs.length === 1
      ? [await runModel(models[0], schemas[0], k, budget, a.case)]
      : await Promise.all(runs.map((it) => child(it.model, it.schema, a)));

  const summary = summarize(reports, k);
  process.stdout.write(`${summary}\n`);

  if (a.out !== undefined) {
    mkdirSync(a.out, { recursive: true });
    writeFileSync(join(a.out, 'summary.md'), `${summary}\n`);
    for (const report of reports) {
      writeFileSync(
        join(a.out, `${report.model.replace(/\W+/g, '_')}.json`),
        JSON.stringify(report, null, 2),
      );
    }
    process.stdout.write(`Runs and failing transcripts in ${a.out}\n`);
  }
}

/** One model in a process of its own: the frozen clock is per process. */
function child(
  model: string,
  schema: string,
  a: Record<string, string>,
): Promise<ModelReport> {
  const argv = [
    ...process.execArgv,
    process.argv[1],
    '--child',
    '--model',
    model,
    '--schema',
    schema,
    '--k',
    a.k ?? '4',
    '--budget',
    a.budget ?? '0.5',
    ...(a.case === undefined ? [] : ['--case', a.case]),
  ];

  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, argv, {
      stdio: ['ignore', 'pipe', 'inherit'],
    });
    let out = '';
    proc.stdout.on('data', (chunk: Buffer) => (out += chunk.toString()));
    proc.on('close', (code) => {
      try {
        resolve(JSON.parse(out) as ModelReport);
      } catch {
        reject(new Error(`${model} exited ${code}`));
      }
    });
  });
}

main().catch((error: unknown) => {
  process.stderr.write(
    `${error instanceof Error ? error.message : String(error)}\n`,
  );
  process.exit(1);
});
