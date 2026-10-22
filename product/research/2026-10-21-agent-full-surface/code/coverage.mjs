// Which of the person's controls can the agent reach?
//
// Lists every route of the server's controllers, the service method each
// one calls, and whether the agent (gestures.ts, agent.service.ts) calls the
// same method. Writes data/coverage.csv and prints the totals.
//
//   node code/coverage.mjs        (from this folder)

import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = fileURLToPath(new URL('..', import.meta.url));
const root = join(here, '../../..');
const src = join(root, 'server/src');

// Routes the person never drives by hand, or that only serve the app itself.
const PLUMBING = new Set([
  'GET /',
  'GET /health',
  'GET /links/preview',
  'GET /links/image',
  'GET /notifications/schedule',
  'GET /agent/suggestion',
  'POST /agent/turn',
  'GET /agent/conversations',
  'POST /agent/plans/:id/apply',
  'POST /agent/plans/:id/undo',
]);

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

// What the agent can make: the body of make(), not takeBack() (undo only).
const gestures = readFileSync(join(src, 'agent/gestures.ts'), 'utf8');
const agent = gestures.slice(
  gestures.indexOf('export async function make('),
  gestures.indexOf('export async function takeBack('),
);

// Reads are not service calls the agent repeats: what the board shows of
// each, judged by reading board.ts (see the RFC's domain map).
const READS = {
  'GET /timeline': 'yes',
  'GET /artifacts': 'partial',
  'GET /tasks/done': 'no',
  'GET /routines': 'no',
  'GET /users/me': 'partial',
  // Calls moveTask, but answers the start_now guard, which the agent never
  // raises: a running task is never moved by a plan.
  'POST /tasks/timing': 'no',
};

// Calls that are plumbing, not the work: tracing, the ticker, the answer.
const NOT_WORK = new Set(['watch', 'get', 'start', 'log', '_answer']);

const rows = [];
for (const file of walk(src).filter((it) => it.endsWith('.controller.ts'))) {
  const text = readFileSync(file, 'utf8');
  const base = (text.match(/@Controller\(\s*'([^']*)'/) ?? [, ''])[1];
  const parts = text.split(/(?=@(?:Get|Post|Patch|Put|Delete)\()/);
  for (const part of parts.slice(1)) {
    const [, verb, path = ''] = part.match(
      /@(Get|Post|Patch|Put|Delete)\(\s*(?:'([^']*)')?/,
    );
    const route = `${verb.toUpperCase()} /${[base, path].filter(Boolean).join('/')}`;
    if (PLUMBING.has(route)) continue;
    // The first service call in the handler is the one that does the work.
    const calls = [...part.matchAll(/this\.(\w+)\.(\w+)\(/g)]
      .filter(([, field, m]) => field !== 'ticker' && !NOT_WORK.has(m))
      .map(([, , m]) => m);
    const method =
      calls[0] ?? (/this\._db\s*\.update/.test(part) ? '(db, in the controller)' : '');
    const reached =
      READS[route] ??
      (method !== '' && new RegExp(`\\.${method}\\(`).test(agent) ? 'yes' : 'no');
    rows.push({ route, method, reached, file: relative(root, file) });
  }
}

const csv = [
  'route,service_method,agent_calls_it,controller',
  ...rows.map((r) => [r.route, r.method, r.reached, r.file].join(',')),
].join('\n');
writeFileSync(join(here, 'data/coverage.csv'), `${csv}\n`);

const count = (v) => rows.filter((r) => r.reached === v);
console.log(
  `${rows.length} routes a person drives: the agent reaches ${count('yes').length}, ` +
    `part of ${count('partial').length}, none of ${count('no').length}.`,
);
for (const r of rows) console.log(`  ${r.reached.padEnd(7)} ${r.route} (${r.method})`);
