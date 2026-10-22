// Every RFC's shape as a deck, from `.tool/doc shape`: a CSV of slides
// (data/slides.csv), a summary table on stdout, and the chart of words per
// slide (img/words-per-slide.png). Q/A notes are not counted: they are the
// conversation, not the RFC.
//
//   node code/measure.mjs              (from this folder, or anywhere)
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { capture } from '../../../../.tool/shot.mjs';

const here = resolve(import.meta.dirname, '..');
const root = resolve(here, '../../..');
const rfcs = ['agent-reliability', 'agent-queue', 'agent-ui', 'agent-full-surface', 'posthog'];

const rows = [];
for (const rfc of rfcs) {
  const out = execFileSync(join(root, '.tool/doc'), ['shape', 'research', rfc], { encoding: 'utf8' });
  for (const line of out.split('\n')) {
    const m = line.match(/^\s*(\d+)\s+(\d+)\s+(\S+)\s+([✓✗])\s(\s*)(.*?)(\s{2}\(.*\))?$/);
    if (m) rows.push({ rfc, n: +m[1], words: +m[2], visual: m[3], ok: m[4] === '✓', level: m[5] ? 3 : 2, title: m[6] });
  }
}
writeFileSync(join(here, 'data/slides.csv'), 'rfc,n,level,words,visual,ok,title\n' +
  rows.map((r) => [r.rfc, r.n, r.level, r.words, r.visual, r.ok, JSON.stringify(r.title)].join(',')).join('\n') + '\n');

console.log('| RFC | Sections | Biggest | Over 150 words | `##` with no visual | Diagrams | Images |');
console.log('|---|---|---|---|---|---|---|');
for (const rfc of rfcs) {
  const s = rows.filter((r) => r.rfc === rfc);
  const top = s.filter((r) => r.level === 2);
  const over = s.filter((r) => r.words > 150).length;
  const bare = top.filter((r) => r.visual === '—' && !/^(references|decided)/i.test(r.title)).length;
  const big = Math.max(...s.map((r) => r.words));
  const count = (k) => s.filter((r) => r.visual.includes(k)).length;
  console.log(`| ${rfc} | ${s.length} | ${big} | ${over} | ${bare} of ${top.length} | ${count('diagram')} | ${count('image')} |`);
}

// The chart: one dot per section, words on x, one row per RFC, the 150-word budget as a line.
const W = 720, rowH = 54, left = 150, right = 30, top = 40, max = 700;
const x = (w) => left + (Math.min(w, max) / max) * (W - left - right);
const H = top + rfcs.length * rowH + 40;
const dots = rows.map((r) => {
  const y = top + rfcs.indexOf(r.rfc) * rowH + rowH / 2 + (r.level === 3 ? 8 : -8);
  return `<circle cx="${x(r.words)}" cy="${y}" r="6" fill="${r.words > 150 ? '#e8697c' : '#6b6b6b'}" fill-opacity=".85"/>`;
}).join('');
const labels = rfcs.map((r, i) => `<text x="${left - 16}" y="${top + i * rowH + rowH / 2 + 5}" text-anchor="end" fill="#d4d4d4" font-size="15">${r}</text>`).join('');
const ticks = [0, 150, 300, 450, 600].map((t) => `<text x="${x(t)}" y="${H - 12}" text-anchor="middle" fill="#6b6b6b" font-size="13">${t}</text>`).join('');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" font-family="Onest, sans-serif">
  <rect width="100%" height="100%" fill="#0d0d0d"/>
  <text x="${left}" y="24" fill="#a1a1a1" font-size="14">words per section (each dot is one heading; upper row ##, lower ###)</text>
  <rect x="${x(0)}" y="${top}" width="${x(150) - x(0)}" height="${rfcs.length * rowH}" fill="#eeffbb" fill-opacity=".07"/>
  <line x1="${x(150)}" x2="${x(150)}" y1="${top}" y2="${top + rfcs.length * rowH}" stroke="#eeffbb" stroke-dasharray="4 4"/>
  <text x="${x(150) + 6}" y="${top + 14}" fill="#eeffbb" font-size="13">budget: 150</text>
  ${labels}${dots}${ticks}
</svg>`;
const html = `<!doctype html><link href="https://fonts.googleapis.com/css2?family=Onest:wght@400;500&display=swap" rel="stylesheet">
<body style="margin:0;background:#0d0d0d"><div id="c" style="width:${W}px">${svg}</div><script>document.fonts.ready.then(() => document.body.dataset.ready = 1)</script></body>`;
const page = join(here, 'data/.chart.html');
writeFileSync(page, html);
const { files } = await capture(`file://${page}`, { selector: '#c', out: join(here, 'img'), width: W, scale: 2 });
execFileSync('mv', [files[0], join(here, 'img/words-per-slide.png')]);
execFileSync('rm', [page]);
console.log(`\n${rows.length} sections → data/slides.csv, img/words-per-slide.png`);
