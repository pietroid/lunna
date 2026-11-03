#!/usr/bin/env node
// Analyze unattended queue logs for cost drivers.
// Usage: node analyze-queue.mjs <log.jsonl> [log2.jsonl ...]
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const files = process.argv.slice(2);
if (!files.length) {
  console.error('usage: node analyze-queue.mjs <log.jsonl>...');
  process.exit(1);
}

function analyze(path) {
  const lines = readFileSync(path, 'utf8').split('\n').filter(Boolean);
  let firstAt = null;
  let lastAt = null;
  let assistantTurns = 0;
  let totalIn = 0;
  let totalCacheRead = 0;
  let totalCacheWrite = 0;
  let totalRaw = 0;
  let totalOut = 0;
  let totalThink = 0;
  let peakContext = 0;
  const toolSizes = [];
  const contextOverTime = [];
  const rateEvents = [];

  for (const line of lines) {
    let e;
    try { e = JSON.parse(line); } catch { continue; }
    const at = e.timestamp ? new Date(e.timestamp) : null;
    if (at) {
      if (!firstAt) firstAt = at;
      lastAt = at;
    }

    if (e.type === 'rate_limit_event' && e.rate_limit_info) {
      rateEvents.push({ at, ...e.rate_limit_info.unifiedWindows?.five_hour });
    }

    if (e.type === 'assistant' && e.message?.usage) {
      assistantTurns++;
      const u = e.message.usage;
      const read = u.cache_read_input_tokens ?? 0;
      const write = u.cache_creation_input_tokens ?? 0;
      const raw = u.input_tokens ?? 0;
      const out = u.output_tokens ?? 0;
      const think = u.output_tokens_details?.thinking_tokens ?? 0;
      totalCacheRead += read;
      totalCacheWrite += write;
      totalRaw += raw;
      totalOut += out;
      totalThink += think;
      totalIn += read + write + raw;
      const ctx = read + write + raw;
      if (ctx > peakContext) peakContext = ctx;
      contextOverTime.push({ at, context: ctx, out, think });
    }

    if (e.type === 'user' && e.message?.content) {
      const content = e.message.content;
      const text = typeof content === 'string' ? content : JSON.stringify(content);
      toolSizes.push({ at, size: text.length });
    }
  }

  const mins = firstAt && lastAt ? Math.round((lastAt - firstAt) / 60000) : 0;
  return {
    name: path.split('/').pop(),
    firstAt,
    lastAt,
    mins,
    assistantTurns,
    totalIn,
    totalCacheRead,
    totalCacheWrite,
    totalRaw,
    totalOut,
    totalThink,
    peakContext,
    contextOverTime,
    toolSizes,
    rateEvents,
  };
}

const k = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(2)}M` : n >= 1e3 ? `${Math.round(n / 1e3)}k` : `${n}`);

for (const f of files) {
  const path = f.startsWith('/') ? f : resolve(process.cwd(), f);
  const a = analyze(path);
  console.log(`\n## ${a.name}`);
  console.log(`- Wall time: ${a.mins} min`);
  console.log(`- Assistant turns: ${a.assistantTurns}`);
  console.log(`- Peak context: ${k(a.peakContext)}`);
  console.log(`- Tokens in: ${k(a.totalIn)} (cache read ${k(a.totalCacheRead)}, cache write ${k(a.totalCacheWrite)}, raw ${k(a.totalRaw)})`);
  console.log(`- Tokens out: ${k(a.totalOut)} (thinking ${k(a.totalThink)})`);
  const rateStart = a.rateEvents[0]?.utilization ?? '—';
  const rateEnd = a.rateEvents.at(-1)?.utilization ?? '—';
  console.log(`- 5h window: ${rateStart} → ${rateEnd}`);
  if (a.toolSizes.length) {
    const sizes = a.toolSizes.map((t) => t.size).sort((a, b) => b - a);
    console.log(`- Tool result count: ${sizes.length}; largest: ${k(sizes[0])} chars; top 5: ${sizes.slice(0, 5).map(k).join(', ')}`);
  }
}

// CSV summary for all files
console.log('\n## CSV summary');
console.log('file,mins,turns,peak_context,in,cache_read,cache_write,raw,out,think,rate_start,rate_end');
for (const f of files) {
  const path = f.startsWith('/') ? f : resolve(process.cwd(), f);
  const a = analyze(path);
  console.log([
    a.name,
    a.mins,
    a.assistantTurns,
    a.peakContext,
    a.totalIn,
    a.totalCacheRead,
    a.totalCacheWrite,
    a.totalRaw,
    a.totalOut,
    a.totalThink,
    a.rateEvents[0]?.utilization ?? '',
    a.rateEvents.at(-1)?.utilization ?? '',
  ].join(','));
}
