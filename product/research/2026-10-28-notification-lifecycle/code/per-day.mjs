// Reminders one ordinary day fires, today and under the proposal.
//
//   node product/research/2026-10-28-notification-lifecycle/code/per-day.mjs
//
// The day: 3 fixed blocks (breakfast, lunch, dinner) and 6 tasks, each task
// becoming "the next" in turn. Writes data/per-day.csv. Every assumption is
// a constant below.
import * as fs from 'node:fs';
import * as path from 'node:path';

const root = path.join(path.dirname(new URL(import.meta.url).pathname), '..');

const FIXED = 3;
const TASKS = 6;
const DAILY = 2; // morning + evening
const ASKS = 3; // at the edge, +10, +20
const HEADS = FIXED - 1; // "X em 15 minutos": every block but the day's first has something before it

const rows = [
  // today: a fixed block gets `starting` + `almostFinishing`; a task its `confirmStart`.
  ['today', DAILY + FIXED * 2 + TASKS * 1],
  // proposal, each ask answered the first time: one ask per edge.
  ['proposed_answered', DAILY + HEADS + (FIXED + TASKS) * 2],
  // proposal, nothing ever answered: three asks per edge.
  ['proposed_silent', DAILY + HEADS + (FIXED + TASKS) * 2 * ASKS],
];

const csv = ['case,reminders_a_day', ...rows.map((r) => r.join(','))].join('\n') + '\n';
fs.writeFileSync(path.join(root, 'data', 'per-day.csv'), csv);
console.log(csv);
