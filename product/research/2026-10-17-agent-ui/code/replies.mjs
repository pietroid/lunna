// Measures what the agent actually said: how long its replies are, how many
// steps come with them, and how often a board ref (t3, e1, b2) leaks into
// the text the person reads.
//
//   node code/replies.mjs            (from the topic folder)
//
// Reads DATABASE_URL from server/.env.local (the Neon dev branch). Read only.
// Writes data/replies.json (aggregates) and data/leaks.md (the leaking
// replies, verbatim, since they are the evidence).
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '../../../..');
const require = createRequire(join(root, 'server/package.json'));
const { Client } = require('pg');

const env = readFileSync(join(root, 'server/.env.local'), 'utf8');
const url = /^DATABASE_URL=(.*)$/m.exec(env)?.[1]?.trim().replace(/^"|"$/g, '');
if (!url) throw new Error('DATABASE_URL is not set in server/.env.local');

// A ref as the board writes it, standing alone ("t3", "e1", "b12"), and
// any letter and digits ("a2"), in case the model invents a letter.
const STRICT = /(?<![\p{L}\p{N}])[teb][0-9]{1,2}(?![\p{L}\p{N}])/giu;
const ANY = /(?<![\p{L}\p{N}])[a-z][0-9]{1,2}(?![\p{L}\p{N}])/giu;

const client = new Client({ connectionString: url });
await client.connect();
const { rows } = await client.query(
  `select text, steps, plan, plan_status, created_at
     from agent_message where role = 'assistant' order by created_at`,
);
await client.end();

const words = (s) => s.split(/\s+/).filter(Boolean).length;
const median = (xs) => {
  const s = [...xs].sort((a, b) => a - b);
  return s.length === 0 ? 0 : s[Math.floor(s.length / 2)];
};
const p90 = (xs) => {
  const s = [...xs].sort((a, b) => a - b);
  return s.length === 0 ? 0 : s[Math.floor(s.length * 0.9)];
};

const withPlan = rows.filter((r) => r.plan !== null);
const leaks = rows.filter((r) => r.text.match(ANY));
const strict = rows.filter((r) => r.text.match(STRICT));

const summary = {
  measuredAt: new Date().toISOString(),
  replies: rows.length,
  withPlan: withPlan.length,
  words: { median: median(rows.map((r) => words(r.text))), p90: p90(rows.map((r) => words(r.text))) },
  wordsWithPlan: {
    median: median(withPlan.map((r) => words(r.text))),
    p90: p90(withPlan.map((r) => words(r.text))),
  },
  sentencesWithPlan: median(withPlan.map((r) => r.text.split(/[.!?]+\s/).length)),
  steps: { median: median(rows.map((r) => r.steps.length)), p90: p90(rows.map((r) => r.steps.length)) },
  // Lines of text drawn above the card for a plan: steps + reply sentences.
  linesAboveCard: median(
    withPlan.map((r) => r.steps.length + r.text.split(/[.!?]+\s/).length),
  ),
  refLeaks: { anyLetterDigit: leaks.length, boardRefs: strict.length },
  firstAt: rows[0]?.created_at,
  lastAt: rows.at(-1)?.created_at,
};
writeFileSync(join(here, '../data/replies.json'), JSON.stringify(summary, null, 2) + '\n');

const md = [
  '# Replies that name a board ref',
  '',
  `From \`code/replies.mjs\`, ${summary.measuredAt.slice(0, 10)}: ${leaks.length} of ${rows.length} assistant replies.`,
  '',
  ...leaks.map(
    (r) =>
      `- ${new Date(r.created_at).toISOString().slice(0, 16)} · refs ${[...new Set(r.text.match(ANY))].join(', ')}\n  > ${r.text.replace(/\n/g, ' ')}`,
  ),
  '',
];
writeFileSync(join(here, '../data/leaks.md'), md.join('\n'));
console.log(JSON.stringify(summary, null, 2));
