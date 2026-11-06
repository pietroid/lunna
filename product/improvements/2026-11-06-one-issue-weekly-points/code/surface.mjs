// Where a queue run's tool calls went: searching (grep/find/ls/Read of a file
// it never edits) vs working on the files it edits. Usage:
//   node surface.mjs <run.jsonl>...
import { readFileSync } from 'node:fs';
for (const f of process.argv.slice(2)) {
  const calls = [], edited = new Set(), read = new Map();
  for (const l of readFileSync(f, 'utf8').split('\n')) {
    let e; try { e = JSON.parse(l); } catch { continue; }
    if (e.type !== 'assistant') continue;
    for (const c of e.message?.content ?? []) if (c.type === 'tool_use') calls.push(c);
  }
  let search = 0, bash = 0;
  for (const c of calls) {
    const i = c.input ?? {};
    if (c.name === 'Edit' || c.name === 'Write') edited.add(i.file_path);
    if (c.name === 'Read') read.set(i.file_path, (read.get(i.file_path) ?? 0) + 1);
    if (c.name === 'Bash') { bash++; if (/\b(grep|rg|find|ls|sed -n|cat|head)\b/.test(i.command ?? '') && !/flutter|npm|\.tool\//.test(i.command ?? '')) search++; }
  }
  const readOnly = [...read.keys()].filter((p) => !edited.has(p));
  console.log(`${f.split('/').pop().slice(0, 34)} calls ${calls.length} · bash ${bash} (search ${search}) · read ${read.size} files (${readOnly.length} never edited) · edited ${edited.size}`);
}
