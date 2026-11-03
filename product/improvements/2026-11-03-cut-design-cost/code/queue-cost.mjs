#!/usr/bin/env node
// Cost of a queue run, from its .git/queue/logs/<issue>-<iso>-<phase>.jsonl.
// Usage: node queue-cost.mjs <log.jsonl>
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const file = process.argv[2];
if (!file) {
  console.error('usage: node queue-cost.mjs <log.jsonl>');
  process.exit(1);
}
const path = file.startsWith('/') ? file : resolve(process.cwd(), file);

function said(entry) {
  if (entry.type !== 'user') return undefined;
  const content = entry.message?.content;
  const text = typeof content === 'string' ? content : content?.find?.((c) => c.type === 'text')?.text;
  if (!text) return undefined;
  if (text.startsWith('<') || text.startsWith('[Image')) return undefined;
  return text;
}

const rows = [];
const usage = new Map();
let total;
for (const line of readFileSync(path, 'utf8').split('\n')) {
  if (!line) continue;
  let e;
  try { e = JSON.parse(line); } catch { continue; }
  const text = said(e);
  if (text !== undefined) rows.push({ at: new Date(e.timestamp), text, turns: 0, read: 0, write: 0, raw: 0, out: 0, think: 0, units: 0, peak: 0 });
  const m = e.message;
  if (e.type === 'assistant' && m?.usage && m.id && rows.length) usage.set(m.id, { row: rows.at(-1), u: m.usage, at: new Date(e.timestamp) });
  const cost = line.includes('"costUSD"') && line.match(/"modelUsage":\{.*?"costUSD":([\d.]+)/);
  if (cost) total = Number(cost[1]);
}
for (const { row, u, at } of usage.values()) {
  const w1h = u.cache_creation?.ephemeral_1h_input_tokens ?? 0;
  const write = u.cache_creation_input_tokens ?? 0;
  row.turns++;
  row.read += u.cache_read_input_tokens ?? 0;
  row.write += write;
  row.raw += u.input_tokens ?? 0;
  row.out += u.output_tokens ?? 0;
  row.think += u.output_tokens_details?.thinking_tokens ?? 0;
  row.peak = Math.max(row.peak, (u.cache_read_input_tokens ?? 0) + write + (u.input_tokens ?? 0));
  row.units += (u.input_tokens ?? 0) + 0.1 * (u.cache_read_input_tokens ?? 0) + 2 * w1h + 1.25 * (write - w1h) + 5 * (u.output_tokens ?? 0);
  row.end = at;
}

const k = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(2)}M` : n >= 1e3 ? `${Math.round(n / 1e3)}k` : `${n}`);
const hm = (d) => d.toTimeString().slice(0, 5);
const mins = (a, b) => (b ? `${Math.max(1, Math.round((b - a) / 60000))} min` : '—');

console.log(`Queue log ${path.split('/').pop()}. In = cache read + cache write + raw input; out includes thinking.`);
console.log(`USD: ${total ? "the transcript's own total" : 'unknown until the session ends'}.\n`);
console.log('| # | At | Took | Message | Turns | Peak context | In (cache read) | Out (thinking) |');
console.log('|---|---|---|---|---|---|---|---|');
const sum = { turns: 0, read: 0, write: 0, raw: 0, out: 0, think: 0, units: 0 };
rows.forEach((r, i) => {
  const words = r.text.replace(/\s+/g, ' ').replace(/\|/g, '/');
  const label = words.length > 48 ? `${words.slice(0, 47)}…` : words;
  console.log(`| ${i + 1} | ${hm(r.at)} | ${mins(r.at, r.end)} | ${label} | ${r.turns} | ${k(r.peak)} | ${k(r.read + r.write + r.raw)} (${k(r.read)}) | ${k(r.out)} (${k(r.think)}) |`);
  for (const key of Object.keys(sum)) sum[key] += r[key];
});
const span = rows.length ? mins(rows[0].at, rows.findLast((r) => r.end)?.end) : '—';
console.log(`| | | **${span}** | **Total** | **${sum.turns}** | | **${k(sum.read + sum.write + sum.raw)}** (${k(sum.read)}) | **${k(sum.out)}** (${k(sum.think)}) |`);
