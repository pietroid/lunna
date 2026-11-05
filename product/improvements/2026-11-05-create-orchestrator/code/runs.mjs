#!/usr/bin/env node
// One row per queue run: model, minutes, turns, tokens in, peak context,
// USD (the transcript's own), the cost split, and the 5 h / weekly window
// points it used. Usage: node runs.mjs <log.jsonl>...   (from .git/queue/logs)
import { readFileSync } from 'node:fs';
import { basename } from 'node:path';

const PRICE = { // per million tokens: input, output, cache read (1 h cache writes cost 2× input)
  'claude-opus-5-5': [4, 20, 0.2],
  'claude-sonnet-5-5': [2, 10, 0.2],
  'claude-haiku-5-5': [0.1, 0.5, 0.01],
};
const k = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : `${Math.round(n / 1e3)}k`);
const pct = (a, b) => (a == null || b == null ? '—' : `+${Math.round((b - a) * 100)}`);

console.log('| Run | Model | Min | Turns | In | Peak | USD | read/write/out | 5 h pts | week pts |');
console.log('|---|---|---|---|---|---|---|---|---|---|');
for (const f of process.argv.slice(2)) {
  const turns = new Map();
  let model, first, last, usd, mu, h0, h1, w0, w1;
  for (const line of readFileSync(f, 'utf8').split('\n')) {
    if (!line) continue;
    let e; try { e = JSON.parse(line); } catch { continue; }
    if (e.type === 'system' && e.subtype === 'init') model ??= e.model;
    if (e.timestamp) { first ??= new Date(e.timestamp); last = new Date(e.timestamp); }
    if (e.type === 'assistant' && e.message?.usage && e.message.id) turns.set(e.message.id, e.message.usage);
    if (e.type === 'result' && usd == null) { usd = e.total_cost_usd; mu = Object.values(e.modelUsage ?? {})[0]; }
    const w = e.type === 'rate_limit_event' && e.rate_limit_info?.unifiedWindows;
    if (w) { h0 ??= w.five_hour?.utilization; h1 = w.five_hour?.utilization ?? h1; w0 ??= w.seven_day?.utilization; w1 = w.seven_day?.utilization ?? w1; }
  }
  let read = 0, write = 0, out = 0, peak = 0;
  for (const u of turns.values()) {
    const ctx = (u.input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0);
    read += u.cache_read_input_tokens ?? 0; write += u.cache_creation_input_tokens ?? 0; out += u.output_tokens ?? 0;
    peak = Math.max(peak, ctx);
  }
  const [pi, po, pr] = PRICE[model] ?? PRICE['claude-opus-5-5'];
  if (mu) { read = mu.cacheReadInputTokens; write = mu.cacheCreationInputTokens; out = mu.outputTokens; } // the stream undercounts output
  const parts = [read * pr, write * pi * 2, out * po].map((x) => x / 1e6);
  const sum = parts.reduce((a, b) => a + b, 0) || 1;
  const split = parts.map((x) => `${Math.round((x / sum) * 100)}%`).join('/');
  const name = basename(f).replace(/^(\d+)-.*-([a-z-]+)\.jsonl$/, '#$1 $2');
  const min = first && last ? Math.round((last - first) / 60000) : 0;
  console.log(`| ${name} | ${(model ?? '?').replace('claude-', '')} | ${min} | ${turns.size} | ${k(read + write)} | ${k(peak)} | ${usd != null ? '$' + usd.toFixed(2) : '—'} | ${split} | ${pct(h0, h1)} | ${pct(w0, w1)} |`);
}
