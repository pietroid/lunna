// Per-session token anatomy from Claude Code transcripts.
// node anatomy.mjs <session.jsonl>...
import { readFileSync } from 'node:fs';

for (const path of process.argv.slice(2)) {
  const turns = new Map(); // message id -> usage
  const toolName = new Map();
  const byTool = {}; // name -> { calls, chars, images }
  let firstUser = '';
  let subagentTurns = 0;
  const contexts = [];
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    if (!line) continue;
    let e;
    try { e = JSON.parse(line); } catch { continue; }
    const m = e.message;
    if (!m) continue;
    if (e.type === 'user' && !firstUser && typeof m.content === 'string') firstUser = m.content.slice(0, 90).replace(/\s+/g, ' ');
    if (e.type === 'user' && !firstUser && Array.isArray(m.content)) {
      const t = m.content.find((c) => c.type === 'text' && !c.text.startsWith('<'));
      if (t) firstUser = t.text.slice(0, 90).replace(/\s+/g, ' ');
    }
    if (e.type === 'assistant' && m.usage && m.id) {
      if (e.isSidechain) subagentTurns++;
      turns.set(m.id, m.usage);
      for (const c of m.content ?? []) if (c.type === 'tool_use') {
        let name = c.name;
        if (name === 'Bash') name = 'Bash:' + (c.input.command.match(/(flutter (?:build|test|analyze)|npm (?:test|run \S+)|npx (?:tsc|eslint|jest)|shoot-flutter|board\.mjs|git \w+|grep|sed|cat|find|ls)/)?.[1] ?? 'other');
        toolName.set(c.id, name);
      }
    }
    if (e.type === 'user' && Array.isArray(m.content)) for (const c of m.content) if (c.type === 'tool_result') {
      const name = toolName.get(c.tool_use_id) ?? '?';
      const t = (byTool[name] ??= { calls: 0, chars: 0, images: 0 });
      t.calls++;
      const parts = Array.isArray(c.content) ? c.content : [{ type: 'text', text: String(c.content ?? '') }];
      for (const p of parts) {
        if (p.type === 'image') t.images++;
        else t.chars += (p.text ?? '').length;
      }
    }
  }
  let cr = 0, cw = 0, inp = 0, out = 0;
  for (const u of turns.values()) {
    cr += u.cache_read_input_tokens ?? 0; cw += u.cache_creation_input_tokens ?? 0;
    inp += u.input_tokens ?? 0; out += u.output_tokens ?? 0;
    contexts.push((u.cache_read_input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0) + (u.input_tokens ?? 0));
  }
  const k = (n) => (n >= 1e6 ? (n / 1e6).toFixed(2) + 'M' : (n / 1e3).toFixed(0) + 'k');
  const first = contexts[0] ?? 0;
  console.log(`\n## ${path.split('/').pop().slice(0, 8)}  "${firstUser}"`);
  console.log(`turns ${turns.size} (subagent ${subagentTurns}) | in ${k(cr + cw + inp)} (cacheRead ${k(cr)}, cacheWrite ${k(cw)}, raw ${k(inp)}) | out ${k(out)} | ratio ${((cr + cw + inp) / out).toFixed(0)}:1`);
  console.log(`context: first turn ${k(first)}, mean ${k(contexts.reduce((a, b) => a + b, 0) / contexts.length)}, max ${k(Math.max(...contexts))}`);
  const rows = Object.entries(byTool).sort((a, b) => b[1].chars - a[1].chars).slice(0, 12);
  console.log('tool results (chars ≈ tokens×4):', rows.map(([n, t]) => `${n} ${t.calls}× ${k(t.chars / 4)}tok${t.images ? ` ${t.images}img` : ''}`).join(' | '));
}
