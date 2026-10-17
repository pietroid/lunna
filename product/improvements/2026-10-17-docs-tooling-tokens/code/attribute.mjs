// Attribute a session's input tokens to what caused them: each turn's growth
// in context, times the turns that re-read it afterwards.
import { readFileSync } from 'node:fs';
const turns = []; const names = new Map(); let pending = [];
const cat = (n, input) => {
  if (n !== 'Bash') return n.startsWith('mcp__') ? 'mcp' : n;
  const c = input.command;
  if (/flutter (build|test|analyze)|npm test|npx (tsc|eslint|jest)|shoot|board\.mjs/.test(c)) return 'Bash: build/test/shoot';
  if (/python3? -|<<'?EOF|sed -i|perl -i/.test(c)) return 'Bash: edit scripts';
  if (/^\s*(cd [^&]+&& )?(sed -n|cat|head|tail|grep|rg|find|ls|wc|git (show|log|diff))/.test(c)) return 'Bash: read/search code';
  return 'Bash: other';
};
const seen = new Set();
for (const l of readFileSync(process.argv[2], 'utf8').split('\n')) {
  if (!l) continue; let e; try { e = JSON.parse(l); } catch { continue; }
  const m = e.message; if (!m || e.isSidechain) continue;
  if (e.type === 'assistant' && m.usage) {
    for (const c of m.content ?? []) if (c.type === 'tool_use') names.set(c.id, cat(c.name, c.input));
    if (seen.has(m.id)) { turns.at(-1).uses = [...turns.at(-1).uses, ...(m.content ?? []).filter(c => c.type === 'tool_use').map(c => names.get(c.id))]; continue; }
    seen.add(m.id);
    const u = m.usage;
    turns.push({ ctx: u.cache_read_input_tokens + u.cache_creation_input_tokens + u.input_tokens, out: u.output_tokens, before: pending, uses: (m.content ?? []).filter(c => c.type === 'tool_use').map(c => names.get(c.id)) });
    pending = [];
  } else if (e.type === 'user') {
    const cs = Array.isArray(m.content) ? m.content : [{ type: 'text', text: m.content }];
    for (const c of cs) {
      if (c.type === 'tool_result') {
        const parts = Array.isArray(c.content) ? c.content : [{ type: 'text', text: String(c.content ?? '') }];
        for (const p of parts) pending.push({ k: p.type === 'image' ? 'images (screenshots)' : names.get(c.tool_use_id) ?? '?', w: p.type === 'image' ? 1600 : (p.text ?? '').length / 3.5 });
      } else pending.push({ k: 'user messages + reminders', w: (c.text ?? '').length / 3.5 });
    }
  }
}
const N = turns.length, total = turns.reduce((a, t) => a + t.ctx, 0), acc = {};
const add = (k, v) => (acc[k] = (acc[k] ?? 0) + v);
add('fixed prefix (system, tools, skills, AGENTS.md)', turns[0].ctx * N);
for (let i = 1; i < N; i++) {
  const delta = Math.max(0, turns[i].ctx - turns[i - 1].ctx), rest = N - i;
  // What the model wrote last turn: thinking + text + the tool inputs (code it wrote, commands).
  const out = Math.min(delta, turns[i - 1].out);
  const kinds = turns[i - 1].uses; const wrote = kinds.some(k => k === 'Write' || k === 'Edit' || k === 'Bash: edit scripts') ? 'model output: writing code' : 'model output: thinking, text, commands';
  add(wrote, out * rest);
  const items = turns[i].before, sum = items.reduce((a, x) => a + x.w, 0) || 1;
  for (const x of items) add('result: ' + x.k, (delta - out) * (x.w / sum) * rest);
}
const fmt = n => (n / 1e6).toFixed(2) + 'M';
console.log(`turns ${N}, in ${fmt(total)} (attributed ${fmt(Object.values(acc).reduce((a, b) => a + b, 0))})`);
for (const [k, v] of Object.entries(acc).sort((a, b) => b[1] - a[1])) if (v / total > 0.01) console.log(`${(100 * v / total).toFixed(0).padStart(3)}%  ${fmt(v).padStart(6)}  ${k}`);
