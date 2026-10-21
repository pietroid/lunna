// How long the queue took to act on each answer: the owner's last comment
// before a run, against that run's start. Reads .git/queue/ and GitHub (gh).
// Run from this folder: node code/latency.mjs > data/latency.md
import { execFileSync } from 'node:child_process';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const sh = (cmd, args) => execFileSync(cmd, args, { encoding: 'utf8', maxBuffer: 1 << 26 }).trim();
const home = join(sh('git', ['rev-parse', '--path-format=absolute', '--git-common-dir']), 'queue');
const cfg = JSON.parse(readFileSync(join(home, 'config.json'), 'utf8'));
const api = (p) => JSON.parse(sh('gh', ['api', '--paginate', '--slurp', `repos/${cfg.repo}/${p}`])).flat();

const rows = [];
for (const f of readdirSync(join(home, 'issues'))) {
  const st = JSON.parse(readFileSync(join(home, 'issues', f), 'utf8'));
  const said = [st.issue, st.pr].filter(Boolean).flatMap((n) => api(`issues/${n}/comments`))
    .concat(st.pr ? api(`pulls/${st.pr}/comments`) : [])
    .concat(st.pr ? api(`pulls/${st.pr}/reviews`).map((r) => ({ ...r, created_at: r.submitted_at })) : [])
    .filter((c) => c.user?.login === cfg.owner && c.created_at && !(c.body ?? '').includes('<!-- queue'))
    .map((c) => Date.parse(c.created_at)).sort((a, b) => a - b);
  st.runs.forEach((run, i) => {
    if (i === 0) return;
    const start = Date.parse(run.started);
    const prevEnd = Date.parse(st.runs[i - 1].started) + st.runs[i - 1].ms;
    const asked = said.filter((t) => t > prevEnd && t <= start);
    if (!asked.length) return;
    rows.push({ issue: st.issue, phase: run.phase, comment: new Date(asked.at(-1)).toISOString().slice(0, 19), wait: Math.round((start - asked.at(-1)) / 1000) });
  });
}
rows.sort((a, b) => a.comment.localeCompare(b.comment));
const w = rows.map((r) => r.wait).sort((a, b) => a - b);
const q = (p) => w[Math.min(w.length - 1, Math.floor(p * w.length))];
console.log('| Issue | Phase | Last comment (UTC) | Seconds to run start |\n|---|---|---|---|');
for (const r of rows) console.log(`| #${r.issue} | ${r.phase} | ${r.comment} | ${r.wait} |`);
console.log(`\n${w.length} answers. Median ${q(0.5)} s, p75 ${q(0.75)} s, max ${w.at(-1)} s.`);
