// Every Claude Code session on this repo, from its transcript: when it ran,
// which skill it was, its turns, its tokens and (when the session wrote it)
// its API-equivalent USD. Also the hours of the day the user works in.
//   node code/sessions.mjs [--csv data/sessions.csv] > data/sessions.txt
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const dir = join(homedir(), '.claude/projects/-Users-pietro-Documents-pietroid-dev-lunna');
const csvAt = process.argv.indexOf('--csv');
const rows = [];
const hours = new Array(24).fill(0); // minutes with a user prompt, by local hour

for (const f of readdirSync(dir).filter((f) => f.endsWith('.jsonl'))) {
  let first, start, end, kind = 'other', turns = 0, inTok = 0, outTok = 0, usd = 0;
  const seen = new Set();
  const promptMinutes = new Set();
  for (const line of readFileSync(join(dir, f), 'utf8').split('\n')) {
    if (!line) continue;
    let e; try { e = JSON.parse(line); } catch { continue; }
    const at = e.timestamp && new Date(e.timestamp);
    if (at) { start ??= at; end = at; }
    const m = e.message;
    if (e.type === 'user' && !e.isMeta && typeof m?.content === 'string' && !m.content.startsWith('<local-command')) {
      const name = m.content.match(/<command-name>\/?([\w:-]+)<\/command-name>/)?.[1];
      if (!first) { first = name ? `/${name}` : m.content.slice(0, 40); if (name) kind = name; }
      if (at) promptMinutes.add(`${at.getHours()}:${at.getMinutes()}`);
    }
    if (e.type === 'assistant' && m?.usage && m.id && !seen.has(m.id)) {
      seen.add(m.id); turns++;
      const u = m.usage;
      inTok += (u.input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0);
      outTok += u.output_tokens ?? 0;
    }
    const c = line.includes('"costUSD"') && line.match(/"costUSD":([\d.]+)/g);
    if (c) usd = Math.max(usd, ...c.map((s) => +s.split(':')[1]));
  }
  for (const k of promptMinutes) hours[+k.split(':')[0]]++;
  if (!turns || ['clear', 'mcp'].includes(kind)) continue;
  rows.push({ id: f.slice(0, 8), day: start.toLocaleDateString('sv') /* local day, not UTC */, kind, minutes: Math.round((end - start) / 60000), turns, inTok, outTok, usd });
}
rows.sort((a, b) => a.day.localeCompare(b.day));

const M = (n) => (n / 1e6).toFixed(2) + 'M';
const byKind = {};
for (const r of rows) {
  const k = (byKind[r.kind] ??= { n: 0, turns: 0, inTok: 0, outTok: 0, usd: 0, priced: 0 });
  k.n++; k.turns += r.turns; k.inTok += r.inTok; k.outTok += r.outTok;
  if (r.usd) { k.usd += r.usd; k.priced++; }
}
console.log(`sessions: ${rows.length}, ${rows[0]?.day} → ${rows.at(-1)?.day}\n`);
console.log('| kind | sessions | median turns | tokens in | tokens out | API-eq USD (priced sessions) |');
console.log('|---|---|---|---|---|---|');
for (const [k, v] of Object.entries(byKind).sort((a, b) => b[1].inTok - a[1].inTok)) {
  const t = rows.filter((r) => r.kind === k).map((r) => r.turns).sort((a, b) => a - b);
  console.log(`| ${k} | ${v.n} | ${t[t.length >> 1]} | ${M(v.inTok)} | ${M(v.outTok)} | ${v.priced ? `$${v.usd.toFixed(2)} (${v.priced})` : '—'} |`);
}
const days = {};
for (const r of rows) { const d = (days[r.day] ??= { n: 0, inTok: 0, minutes: 0 }); d.n++; d.inTok += r.inTok; d.minutes += r.minutes; }
console.log('\n| day | sessions | tokens in | session-minutes |\n|---|---|---|---|');
for (const [d, v] of Object.entries(days)) console.log(`| ${d} | ${v.n} | ${M(v.inTok)} | ${v.minutes} |`);
console.log('\nminutes with a prompt, by local hour (0..23):');
console.log(hours.map((n, h) => `${String(h).padStart(2, '0')} ${'#'.repeat(Math.ceil(n / 5))} ${n}`).join('\n'));
if (csvAt > 0) writeFileSync(process.argv[csvAt + 1], 'id,day,kind,minutes,turns,in,out,usd\n' + rows.map((r) => Object.values(r).join(',')).join('\n') + '\n');
