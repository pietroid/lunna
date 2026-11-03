#!/usr/bin/env node
// Generate an HTML cost report from queue-session CSV.
// Usage: node report.mjs < sessions.csv > report.html
import { readFileSync } from 'node:fs';

const input = readFileSync(0, 'utf8').trim();
const lines = input.split('\n');
const header = ['file','mins','turns','peak_context','in','cache_read','cache_write','raw','out','think','rate_start','rate_end'];
const rows = lines.map((l) => {
  const parts = l.split(',');
  const o = {};
  for (let i = 0; i < header.length; i++) o[header[i]] = parts[i];
  return o;
}).map((r) => ({
  file: r.file,
  issue: r.file.split('-')[0],
  phase: r.file.match(/-(design|build|revise|fix)\./)?.[1] ?? 'other',
  date: r.file.match(/(\d{4}-\d{2}-\d{2})/)?.[1] ?? '',
  mins: +r.mins,
  turns: +r.turns,
  peakContext: +r.peak_context,
  tokensIn: +r.in,
  cacheRead: +r.cache_read,
  cacheWrite: +r.cache_write,
  raw: +r.raw,
  out: +r.out,
  think: +r.think,
  rateStart: r.rate_start === '' ? null : +r.rate_start,
  rateEnd: r.rate_end === '' ? null : +r.rate_end,
}));

const byPhase = (phase) => rows.filter((r) => r.phase === phase);
const avg = (xs, key) => xs.length ? xs.reduce((a, b) => a + b[key], 0) / xs.length : 0;
const med = (xs, key) => {
  const s = [...xs].sort((a, b) => a[key] - b[key]);
  const m = s.length >> 1;
  return s.length ? (s.length % 2 ? s[m][key] : (s[m][key] + s[m - 1][key]) / 2) : 0;
};

const phases = ['design', 'build', 'revise', 'fix'];
const stats = phases.map((p) => {
  const xs = byPhase(p);
  return {
    phase: p,
    count: xs.length,
    medMins: med(xs, 'mins'),
    medTurns: med(xs, 'turns'),
    medPeak: med(xs, 'peakContext'),
    medIn: med(xs, 'tokensIn'),
    medOut: med(xs, 'out'),
  };
});

const phaseColor = { design: '#ef4444', build: '#f97316', revise: '#3b82f6', fix: '#22c55e' };
const fmtNum = (n) => n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${(n / 1e3).toFixed(0)}k` : `${n}`;
const fmtUsd = (tokensIn) => {
  // Calibrated from #83 design: 12.57M tokens in → $11.06 API-eq.
  return `$${((tokensIn / 1e6) * 0.88).toFixed(2)}`;
};

const chartData = (key) => phases.map((p) => ({ label: p, data: byPhase(p).map((r) => r[key]), color: phaseColor[p] }));

const html = `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Lunna queue session cost analysis</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<style>
body{font-family:system-ui,-apple-system,sans-serif;max-width:1100px;margin:40px auto;padding:0 20px;color:#1f2937;line-height:1.5}
h1{font-size:1.75rem;margin-bottom:.25rem}h2{font-size:1.25rem;margin-top:2rem}
table{border-collapse:collapse;width:100%;margin:1rem 0;font-size:.9rem}
th,td{border:1px solid #e5e7eb;padding:8px 10px;text-align:left}
th{background:#f9fafb}.num{text-align:right}
.chart{height:300px;margin:1.5rem 0}
.callout{background:#fef3c7;border-left:4px solid #f59e0b;padding:1rem;margin:1rem 0}
.recommendation{background:#eff6ff;border-left:4px solid #3b82f6;padding:1rem;margin:1rem 0}
</style>
</head>
<body>
<h1>Lunna queue session cost analysis</h1>
<p>Generated ${new Date().toLocaleString('sv-SE')}. Covers ${rows.length} unattended queue runs.</p>

<h2>1. Medians by phase</h2>
<table>
<tr><th>Phase</th><th>Runs</th><th class=num>Wall min</th><th class=num>Turns</th><th class=num>Peak context</th><th class=num>Tokens in</th><th class=num>Tokens out</th><th class=num>API-eq USD</th></tr>
${stats.map((s) => `<tr><td><strong>${s.phase}</strong></td><td class=num>${s.count}</td><td class=num>${s.medMins.toFixed(0)}</td><td class=num>${s.medTurns.toFixed(0)}</td><td class=num>${fmtNum(s.medPeak)}</td><td class=num>${fmtNum(s.medIn)}</td><td class=num>${fmtNum(s.medOut)}</td><td class=num>${fmtUsd(s.medIn)}</td></tr>`).join('')}
</table>

<div class="callout">
<strong>Finding:</strong> A design session now burns a median of ~${fmtNum(med(byPhase('design'), 'tokensIn'))} tokens in ~${med(byPhase('design'), 'mins').toFixed(0)} min. In the worst recent run (#83 design) the 5-hour Claude Code window went from 50% to 85% in 10 minutes. Build sessions are 3–6× heavier.
</div>

<h2>2. Tokens in per session</h2>
<div class="chart"><canvas id="inChart"></canvas></div>

<h2>3. Assistant turns per session</h2>
<div class="chart"><canvas id="turnsChart"></canvas></div>

<h2>4. Peak context per session</h2>
<div class="chart"><canvas id="peakChart"></canvas></div>

<h2>5. 5-hour rate window end utilization</h2>
<div class="chart"><canvas id="rateChart"></canvas></div>

<h2>6. Root causes</h2>
<ul>
<li><strong>Screenshots in context are the biggest burn.</strong> In #83 design, 7 image reads totalled 2.2M chars (~550k tokens). These images stay in context and are re-read on every turn. At 111 turns they likely account for the majority of the 12.18M cache-read tokens.</li>
<li><strong>Re-reading large files.</strong> Tool results of 20k+ chars appear from <code>cat</code>ing entire Dart files; the agent reads them again on later turns.</li>
<li><strong>High turn count.</strong> 72–330 assistant turns per session; each turn re-reads the full accumulated context (cache reads dominate at 95%+ of input tokens).</li>
<li><strong>Massive peak context.</strong> 120k–360k tokens means every later turn is expensive even if little new work happens.</li>
<li><strong>Design and build use the same heavy model.</strong> Mockups are essentially project-structure + widget-composition work, yet they run on <code>claude-opus-5-5</code>.</li>
<li><strong>Build sessions re-explore.</strong> The hand-off is supposed to carry decisions, but build runs still issue broad <code>ls</code>/<code>cat</code> exploration and absorb full build logs.</li>
</ul>

<h2>7. Recommendations and estimated impact</h2>
${[
  {title:'Never read full-resolution screenshots into the LLM context', impact:'5–7× on design', detail:'The board/strip PNGs are ~300k–550k chars of base64 each. Use a 80×180 thumbnail, or a separate vision tool that returns a compact layout description, or let board.mjs emit OCR/pin verification text. Read the full image only when the user asks to see it.'},
  {title:'Switch design/mockup phase to a cheaper model', impact:'3–5× cost cut', detail:'Mockups are widget layout, project navigation and image review — exactly what Sonnet handles well. Opus is overkill for placement and pin decisions. Use claude-sonnet-5-5 for design, keep Opus for build.'},
  {title:'Ban broad file reads; read by offset or grep', impact:'2–4× context reduction', detail:'Replace "cat whole file" with Read(offset/limit) or grep for the class/method. Add a linter-style pre-check that warns when a tool result exceeds 50k chars.'},
  {title:'Pre-compute and cache a project widget index', impact:'1.5–2× fewer turns', detail:'A small JSON/TS index of screens, widgets, tokens, icons and their file paths lets the design agent query instead of explore. Regenerate on commit via .tool/check hook.'},
  {title:'Cap mockup screens to 3 and iterations to 1 re-shoot', impact:'1.5–2×', detail:'The skill already targets 3–5 screens. Enforce 3 for simple changes and one fix pass before re-shooting, avoiding 5+ preview loops.'},
  {title:'Streamline build hand-off so build re-reads only the brief', impact:'2–3× on build', detail:'The build session should start from the delivery README and the list of files Phase 1 changed. It should not re-explore packages or re-read unchanged specs.'},
  {title:'Truncate tool output at the source', impact:'1.5–2×', detail:".tool/preview and .tool/check already aim for one-line output, but build/test logs still leak in. Cap any Bash/Read result at 20k chars in the harness; the agent can ask for more if it really needs it."},
].map((r) => `<div class="recommendation"><strong>${r.title}</strong> — <em>estimated ${r.impact}</em><br>${r.detail}</div>`).join('')}

<h2>8. Combined target</h2>
<p>With the top three changes (no full screenshots + cheaper model + smaller reads), a design session should drop from ~${fmtNum(med(byPhase('design'), 'tokensIn'))} tokens to ~1–2M tokens, i.e. from ~${fmtUsd(med(byPhase('design'), 'tokensIn'))} to ~$0.25–$0.50 API-equivalent — close to the 10× goal. Build sessions should fall from ~${fmtNum(med(byPhase('build'), 'tokensIn'))} tokens to ~10–20M tokens.</p>

<h2>9. Files to change</h2>
<ul>
<li><code>.claude/skills/create/SKILL.md</code> — add "model: sonnet for design, opus for build" rule; tighten read instructions; enforce 3-screen cap and one re-shoot.</li>
<li><code>.tool/queue.mjs</code> — pick model per phase when spawning <code>claude -p</code>.</li>
<li><code>.tool/README.md</code> — document the new project index command and output-capping rules.</li>
<li>New <code>.tool/index.mjs</code> — generate the widget/project index.</li>
<li><code>.tool/preview</code>, <code>.tool/check</code> — ensure outputs are capped/truncated.</li>
</ul>

<script>
const rows = ${JSON.stringify(rows)};
const phaseOrder = ['design','build','revise','fix'];
const phaseColor = {design:'#ef4444',build:'#f97316',revise:'#3b82f6',fix:'#22c55e'};
function datasets(key, label) {
  return phaseOrder.map(p => ({
    label: p,
    data: rows.filter(r => r.phase === p).map(r => r[key]),
    backgroundColor: phaseColor[p]
  }));
}
function labelsFor(key) {
  // one shared label set: just run index within phase
  const max = Math.max(...phaseOrder.map(p => rows.filter(r => r.phase === p).length));
  return Array.from({length:max},(_,i)=>i+1);
}
function makeBar(id, key, title) {
  new Chart(document.getElementById(id), {
    type: 'bar',
    data: { labels: labelsFor(key), datasets: datasets(key, title) },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { title: { display: true, text: title }, legend: { position: 'top' } },
      scales: { y: { beginAtZero: true } }
    }
  });
}
makeBar('inChart','tokensIn','Tokens in');
makeBar('turnsChart','turns','Assistant turns');
makeBar('peakChart','peakContext','Peak context');
makeBar('rateChart','rateEnd','5h window utilization at end');
</script>
</body>
</html>
`;

console.log(html);
