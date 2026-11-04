/**
 * The composer's fast read against a real model, through OpenRouter: does
 * one line come back as the right kind, and how long does it take.
 *
 *   npm run eval:compose -- --model google/gemini-3.1-flash-lite --k 3
 *
 * Only the fast read is called (a case read as `plan` is graded on that,
 * not on the agent's turn, which `eval:agent` measures). Prints each run and
 * the latency's p50 and p95. Costs money; never run in CI.
 */
import { readFileSync } from 'fs';
import { join } from 'path';
import { ConfigService } from '@nestjs/config';
import { MemoryArtifactStore } from '../../artifacts/artifact.store';
import { CalendarService } from '../../calendar/calendar.service';
import { MemoryCalendarStore } from '../../calendar/calendar.store';
import { CalendarUser } from '../../calendar/calendar.types';
import { Trace } from '../../common/trace';
import { TimelineService } from '../../events/timeline.service';
import { MemoryTaskStore } from '../../tasks/task.store';
import { DEFAULT_WORK_DAY } from '../../time/work-hours';
import { AgentService } from '../agent.service';
import { ComposeDraft, ComposeService } from '../compose';
import { OpenRouterClient } from '../openrouter.client';

const USER: CalendarUser = {
  id: 'eval-user',
  timeZone: 'America/Sao_Paulo',
  workDay: DEFAULT_WORK_DAY,
};

interface ComposeCase {
  text: string;
  expect: (draft: ComposeDraft) => boolean;
}

const CASES: ComposeCase[] = [
  {
    text: 'dentista amanhã às 15h',
    expect: (it) => it.kind === 'event' && it.start !== undefined,
  },
  {
    text: 'responder os e-mails, meia hora',
    expect: (it) => it.kind === 'task' && it.minutes === 30,
  },
  {
    text: 'vídeo do post de touro, 1h30: roteiro, gravar, editar',
    expect: (it) =>
      it.kind === 'task' && it.parent !== undefined && it.subtasks.length === 3,
  },
  {
    text: 'faturar 10 mil até 30 de novembro',
    expect: (it) => it.kind === 'goal' && it.value === 10000,
  },
  {
    text: 'tira os e-mails de hoje e coloca o estudo no lugar',
    expect: (it) => it.kind === 'plan',
  },
];

function arg(name: string): string | undefined {
  const at = process.argv.indexOf(`--${name}`);
  return at < 0 ? undefined : process.argv[at + 1];
}

function apiKey(): string {
  if (process.env.OPENROUTER_API_KEY) return process.env.OPENROUTER_API_KEY;
  const env = readFileSync(join(__dirname, '../../../.env.local'), 'utf8');
  return /^OPENROUTER_API_KEY=(.*)$/m.exec(env)?.[1].trim() ?? '';
}

function percentile(values: number[], p: number): number {
  const sorted = [...values].sort((a, b) => a - b);
  return (
    sorted[
      Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)
    ] ?? 0
  );
}

async function main(): Promise<void> {
  const model = arg('model') ?? process.env.OPENROUTER_MODEL ?? '';
  const k = Number(arg('k') ?? '1');
  const config = new ConfigService({
    OPENROUTER_API_KEY: apiKey(),
    OPENROUTER_MODEL: model,
  });
  const client = new OpenRouterClient(config);
  const calendar = new CalendarService(new MemoryCalendarStore(), config);
  const tasks = new MemoryTaskStore();
  const artifacts = new MemoryArtifactStore();
  await artifacts.insert(USER, {
    title: 'Post: Lua cheia em Touro',
    position: 0,
  });
  const timeline = new TimelineService(calendar, tasks, artifacts);
  // The fallback turn is never reached: a plan is graded on the read.
  const never = {
    turn: () => Promise.reject(new Error('read as plan')),
  } as unknown as AgentService;
  const compose = new ComposeService(client, never, timeline, artifacts);

  const ms: number[] = [];
  let passed = 0;
  for (const c of CASES) {
    for (let run = 1; run <= k; run++) {
      const began = Date.now();
      let draft: ComposeDraft | undefined;
      try {
        draft = await compose.read(
          USER,
          c.text,
          undefined,
          Trace.start(USER.id),
        );
      } catch {
        draft = { kind: 'plan', title: '', subtasks: [], changes: [] };
      }
      const took = Date.now() - began;
      ms.push(took);
      const pass = c.expect(draft);
      if (pass) passed++;
      process.stdout.write(
        `${pass ? '✓' : '✗'} ${c.text} → ${draft.kind} "${draft.title}" (${took} ms)\n`,
      );
    }
  }
  process.stdout.write(
    `\n${model}: ${passed}/${CASES.length * k} · p50 ${percentile(ms, 50)} ms · p95 ${percentile(ms, 95)} ms\n`,
  );
}

main().catch((error: unknown) => {
  process.stderr.write(`${String(error)}\n`);
  process.exit(1);
});
