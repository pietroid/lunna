// Which of the person's controls can the agent reach, and does every route
// go through a service?
//
// Lists every route of the server's controllers, the service method each
// one calls first, and whether one of the agent's actions (src/agent/actions/)
// calls the same method. Then checks that no handler does the work itself
// (a database write, or no service call at all): a rule that lives in a
// controller is a rule the agent skips. Exits 1 when one does.
//
//   node tool/coverage.mjs           (from server/)
//   node tool/coverage.mjs --csv out.csv
//
// Moved from product/research/2026-10-21-agent-full-surface/code/, where the
// RFC measured 6 of 39 with it.

import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const server = fileURLToPath(new URL('..', import.meta.url));
const src = join(server, 'src');

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

// What the agent can make: every service method its actions call, by class,
// through the hands (gestures.ts) they are given.
const HANDS = {
  timeline: 'TimelineService',
  layout: 'EventLayoutService',
  calendar: 'CalendarService',
  tasks: 'TaskStore',
  artifacts: 'ArtifactStore',
  deliveries: 'ArtifactsService',
  routines: 'RoutinesService',
  users: 'UsersService',
};
const agent = new Set(
  walk(join(src, 'agent/actions'))
    .filter((it) => it.endsWith('.ts') && !it.endsWith('.spec.ts'))
    .flatMap((it) => [
      ...readFileSync(it, 'utf8').matchAll(
        new RegExp(`\\b(${Object.keys(HANDS).join('|')})\\.(\\w+)\\(`, 'g'),
      ),
    ])
    .map(([, field, method]) => `${HANDS[field]}.${method}`),
);

// Reads are not service calls the agent repeats: what the board shows of
// each, judged by reading board.ts (see the RFC's domain map).
const READS = {
  'GET /timeline': 'yes',
  'GET /artifacts': 'yes',
  'GET /tasks/done': 'no',
  'GET /routines': 'yes',
  'GET /users/me': 'yes',
  // Calls moveTask, but answers the start_now guard, which the agent never
  // raises: a running task is never moved by a plan.
  'POST /tasks/timing': 'no',
};

// Calls that are plumbing, not the work: tracing, the ticker, the answer.
const NOT_WORK = new Set(['watch', 'get', 'start', 'log', '_answer']);

const rows = [];
const inController = [];
for (const file of walk(src).filter((it) => it.endsWith('.controller.ts'))) {
  const text = readFileSync(file, 'utf8');
  const base = (text.match(/@Controller\(\s*'([^']*)'/) ?? [, ''])[1];
  // Each injected field, to the class it is.
  const fields = Object.fromEntries(
    [...text.matchAll(/readonly (\w+): (\w+)/g)].map(([, f, c]) => [f, c]),
  );
  const parts = text.split(/(?=@(?:Get|Post|Patch|Put|Delete)\()/);
  for (const part of parts.slice(1)) {
    const [, verb, path = ''] = part.match(
      /@(Get|Post|Patch|Put|Delete)\(\s*(?:'([^']*)')?/,
    );
    const route = `${verb.toUpperCase()} /${[base, path].filter(Boolean).join('/')}`;
    // The handler's own code: up to the next decorator or the class's end.
    // (Its parameters' decorators are indented deeper than a member's.)
    const body = part.slice(1).split(/\n {2}@|\n(?:export )?function |\n}\n/)[0];
    const writes = /this\._db\s*\./.test(body);
    if (writes) inController.push(`${route} writes the database itself`);
    if (PLUMBING.has(route)) continue;
    // The first service call in the handler is the one that does the work.
    const calls = [...body.matchAll(/this\.(\w+)\.(\w+)\(/g)]
      .filter(([, field, m]) => field !== 'ticker' && !NOT_WORK.has(m))
      .map(([, field, m]) => ({ method: m, of: `${fields[field]}.${m}` }));
    const method = calls[0]?.method ?? '';
    if (method === '' && !(route in READS) && !/^GET /.test(route)) {
      inController.push(`${route} calls no service`);
    }
    const reached =
      READS[route] ??
      (calls[0] !== undefined && agent.has(calls[0].of) ? 'yes' : 'no');
    rows.push({ route, method, reached, file: relative(server, file) });
  }
}

const csvAt = process.argv.indexOf('--csv');
if (csvAt > 0) {
  const csv = [
    'route,service_method,agent_calls_it,controller',
    ...rows.map((r) => [r.route, r.method, r.reached, r.file].join(',')),
  ].join('\n');
  writeFileSync(process.argv[csvAt + 1], `${csv}\n`);
}

const count = (v) => rows.filter((r) => r.reached === v);
console.log(
  `${rows.length} routes a person drives: the agent reaches ${count('yes').length}, ` +
    `part of ${count('partial').length}, none of ${count('no').length}.`,
);
for (const r of rows) console.log(`  ${r.reached.padEnd(7)} ${r.route} (${r.method})`);
if (inController.length > 0) {
  console.log('\nRules left in a controller:');
  for (const line of inController) console.log(`  ${line}`);
  process.exit(1);
}
console.log('\nEvery handler hands its work to a service.');
