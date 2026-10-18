// What one run of each skill costs in percent of the weekly limit.
// Splits every transcript (subagents included) into segments at each /clear,
// names a segment after its first skill command, weighs its tokens by the
// usual price ratios (cache read 0.1×, cache write 1.25× / 2× for 1 h,
// output 5×), and calibrates units → % with one reading of /usage: the
// units spent since the week began are the week's used %.
//   node code/weekly.mjs <week-start ISO> <used %> <reading ISO> > data/weekly.txt
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const [weekStart, usedPct, readAt] = [new Date(process.argv[2]), +process.argv[3], new Date(process.argv[4])];
const dir = join(homedir(), '.claude/projects/-Users-pietro-Documents-pietroid-dev-lunna');
const files = [];
const walk = (d) => { for (const f of readdirSync(d)) { const p = join(d, f); statSync(p).isDirectory() ? walk(p) : p.endsWith('.jsonl') && files.push(p); } };
walk(dir);

const IGNORE = new Set(['clear', 'mcp', 'model', 'effort', 'compact', 'usage', 'cost', 'fast', 'config', 'login']);
const ALIAS = { feature: 'create', 'design-proposal': 'create' }; // the skill's earlier names
const segs = [];
const seen = new Set();
for (const f of files) {
  const sub = f.includes('/subagents/');
  let seg = null;
  const open = (at) => { seg = { file: f, kind: 'other', named: false, start: at, units: 0, week: 0, turns: 0 }; segs.push(seg); };
  for (const line of readFileSync(f, 'utf8').split('\n')) {
    if (!line) continue;
    let e; try { e = JSON.parse(line); } catch { continue; }
    const at = e.timestamp && new Date(e.timestamp);
    const m = e.message;
    if (!sub && e.type === 'user' && typeof m?.content === 'string') {
      const name = m.content.match(/<command-name>\/?([\w:-]+)<\/command-name>/)?.[1];
      const args = m.content.match(/<command-args>([^<]*)/)?.[1] ?? '';
      if (name === 'clear' || !seg) open(at);
      if (name && !IGNORE.has(name) && !seg.named) {
        seg.named = true;
        const k = ALIAS[name] ?? name;
        seg.kind = k === 'create' ? (/^\s*build\b/.test(args) ? 'create-build' : 'create-design') : k;
      }
    }
    if (e.type === 'assistant' && m?.usage && m.id && !seen.has(m.id)) {
      seen.add(m.id);
      if (!seg) open(at); // a subagent file: one segment, filed under its parent below
      const u = m.usage, w1h = u.cache_creation?.ephemeral_1h_input_tokens ?? 0, w = u.cache_creation_input_tokens ?? 0;
      const units = (u.input_tokens ?? 0) + 0.1 * (u.cache_read_input_tokens ?? 0) + 2 * w1h + 1.25 * (w - w1h) + 5 * (u.output_tokens ?? 0);
      seg.units += units; seg.turns++;
      if (at >= weekStart && at <= readAt) seg.week += units;
    }
  }
}
// A subagent's units belong to the segment of its parent session that was running then.
for (const s of segs.filter((s) => s.file.includes('/subagents/'))) {
  const parent = s.file.split('/subagents/')[0] + '.jsonl';
  const host = segs.filter((p) => p.file === parent && p.start <= s.start).at(-1);
  if (host) { host.units += s.units; host.week += s.week; s.units = s.week = 0; }
}
const real = segs.filter((s) => s.units > 0 && !s.file.includes('/subagents/'));
const weekUnits = real.reduce((a, s) => a + s.week, 0);
const pctPerUnit = usedPct / weekUnits;
console.log(`calibration: ${(weekUnits / 1e6).toFixed(1)}M units from ${weekStart.toISOString()} to ${readAt.toISOString()} = ${usedPct}% of the week → 1% ≈ ${(1 / pctPerUnit / 1e6).toFixed(2)}M units\n`);

const q = (xs, p) => { const s = [...xs].sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor(p * s.length))]; };
const kinds = {};
for (const s of real) (kinds[s.kind] ??= []).push(s);
console.log('| kind | runs | median turns | median % of week | p75 % | max % | % of week spent on it (this week) |');
console.log('|---|---|---|---|---|---|---|');
for (const [k, ss] of Object.entries(kinds).sort((a, b) => b[1].length - a[1].length)) {
  const p = ss.map((s) => s.units * pctPerUnit);
  console.log(`| ${k} | ${ss.length} | ${q(ss.map((s) => s.turns), 0.5)} | ${q(p, 0.5).toFixed(1)} | ${q(p, 0.75).toFixed(1)} | ${Math.max(...p).toFixed(1)} | ${(ss.reduce((a, s) => a + s.week, 0) * pctPerUnit).toFixed(1)} |`);
}
console.log('\nruns this week:');
for (const s of real.filter((s) => s.week > 0).sort((a, b) => a.start - b.start))
  console.log(`  ${s.start.toLocaleString('sv')}  ${s.kind.padEnd(14)} ${s.turns} turns  ${(s.week * pctPerUnit).toFixed(1)}%`);
