// How often a day of the calendar would wear the right phase, by how far
// ahead it is, for the forecast this RFC proposes: the next period starts
// one median cycle after the last logged start, ovulation 13 days before
// it (Apple's rule), bleeding lasts 5 days.
//
// The "truth" is simulated from published figures: a person's mean cycle
// ~ N(28.7, 2.5) days (AWHS 2023: mean 28.7), their cycle-to-cycle spread
// σ of 2, 4 or 6 days (AWHS: within-person variability 4–6 days in most
// groups), each cycle's luteal phase ~ N(12.4, 2.4) clipped to 7–17 (Bull
// 2019). Six past cycles are known; today is a random day of the current
// cycle. Writes data/forecast-accuracy.csv and img/forecast-accuracy.png.
//
//   node code/forecast.mjs
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { capture } from '../../../../.tool/shot.mjs';

const here = resolve(import.meta.dirname, '..');
const HORIZON = 120; // the calendar reaches 120 days (TimelineExtended)
const PEOPLE = 4000;
const BLEED = 5;

// Seeded, so the figures in the README come back the same.
let seed = 42;
const rand = () => ((seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296);
const normal = () => Math.sqrt(-2 * Math.log(rand() || 1e-9)) * Math.cos(2 * Math.PI * rand());
const clip = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const median = (xs) => { const s = [...xs].sort((a, b) => a - b); const m = s.length >> 1; return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };

// A phase per day from a list of cycle starts and each cycle's luteal length.
function label(starts, luteal, day) {
  let i = starts.findLastIndex((s) => s <= day);
  const start = starts[i], next = starts[i + 1];
  if (day - start < BLEED) return 'menstrual';
  const ovulation = next - luteal[i];
  if (day >= ovulation - 5 && day <= ovulation) return 'fertile';
  return day > ovulation ? 'luteal' : 'follicular';
}

const sigmas = [2, 4, 6];
const hits = Object.fromEntries(sigmas.map((s) => [s, new Array(HORIZON + 1).fill(0)]));
// Of the days the forecast paints as a period, how many are one: within the
// first month and beyond it.
const menstrualHit = Object.fromEntries(sigmas.map((s) => [s, { near: [0, 0], far: [0, 0] }]));
// Label shares, for the agreement a guess with no information would reach.
const truthShare = {}, saidShare = {};

for (const sigma of sigmas) {
  for (let p = 0; p < PEOPLE; p++) {
    const mean = clip(28.7 + 2.5 * normal(), 22, 38);
    const cycles = Array.from({ length: 6 + 8 }, () => Math.round(clip(mean + sigma * normal(), 18, 50)));
    const luteal = cycles.map((c) => Math.min(Math.round(clip(12.4 + 2.4 * normal(), 7, 17)), c - BLEED - 1));
    const starts = [0];
    for (const c of cycles) starts.push(starts.at(-1) + c);

    // The last logged start is the 7th; today falls somewhere in that cycle.
    const anchor = starts[6];
    const m = median(cycles.slice(0, 6));
    const today = anchor + Math.floor(rand() * Math.min(cycles[6], Math.round(m)));
    const predicted = Array.from({ length: 10 }, (_, k) => Math.round(anchor + k * m));
    const predictedLuteal = predicted.map(() => 13);

    for (let d = 0; d <= HORIZON; d++) {
      const truth = label(starts, luteal, today + d);
      const said = label(predicted, predictedLuteal, today + d);
      if (truth === said) hits[sigma][d]++;
      truthShare[truth] = (truthShare[truth] ?? 0) + 1;
      saidShare[said] = (saidShare[said] ?? 0) + 1;
      if (said === 'menstrual') {
        const bucket = menstrualHit[sigma][d <= 30 ? 'near' : 'far'];
        bucket[0]++;
        if (truth === 'menstrual') bucket[1]++;
      }
    }
  }
}

const share = (s, d) => hits[s][d] / PEOPLE;
const csv = ['days_ahead,' + sigmas.map((s) => `sigma_${s}`).join(',')];
for (let d = 0; d <= HORIZON; d++) csv.push([d, ...sigmas.map((s) => share(s, d).toFixed(3))].join(','));
writeFileSync(join(here, 'data/forecast-accuracy.csv'), csv.join('\n') + '\n');

const band = (s, a, b) => { let t = 0; for (let d = a; d <= b; d++) t += share(s, d); return t / (b - a + 1); };
const summary = sigmas.map((s) => ({
  sigma: s,
  week1: band(s, 0, 6), month1: band(s, 0, 30), month2: band(s, 31, 60), months34: band(s, 61, 120),
  periodRightMonth1: menstrualHit[s].near[1] / menstrualHit[s].near[0],
  periodRightLater: menstrualHit[s].far[1] / menstrualHit[s].far[0],
}));
const total = Object.values(truthShare).reduce((a, b) => a + b, 0);
const chance = Object.keys(truthShare).reduce((a, l) => a + (truthShare[l] / total) * ((saidShare[l] ?? 0) / total), 0);
summary.push({ sigma: 'chance', week1: chance, month1: chance, month2: chance, months34: chance, periodRightMonth1: truthShare.menstrual / total, periodRightLater: truthShare.menstrual / total });
writeFileSync(join(here, 'data/forecast-summary.json'), JSON.stringify(summary, null, 2) + '\n');
console.table(summary.map((r) => Object.fromEntries(Object.entries(r).map(([k, v]) => [k, k === 'sigma' ? v : `${Math.round(v * 100)}%`]))));

// The chart: share of days labelled right, by days ahead, one line per σ.
const W = 600, H = 420, left = 56, right = 20, top = 92, bottom = 50;
const x = (d) => left + (d / HORIZON) * (W - left - right);
const y = (v) => top + (1 - v) * (H - top - bottom);
const colour = { 2: '#6b6b6b', 4: '#eeffbb', 6: '#a1a1a1' };
const name = { 2: 'σ 2 days', 4: 'σ 4 (typical)', 6: 'σ 6 days' };
const lines = sigmas.map((s) => {
  const pts = hits[s].map((_, d) => `${x(d).toFixed(1)},${y(share(s, d)).toFixed(1)}`).join(' ');
  const i = sigmas.indexOf(s);
  return `<polyline points="${pts}" fill="none" stroke="${colour[s]}" stroke-width="${s === 4 ? 3 : 2}"/>
  <line x1="${left + i * 150}" x2="${left + i * 150 + 18}" y1="56" y2="56" stroke="${colour[s]}" stroke-width="3"/>
  <text x="${left + i * 150 + 24}" y="61" fill="${colour[s]}" font-size="15">${name[s]}</text>`;
}).join('');
const grid = [0.25, 0.5, 0.75, 1].map((v) => `<line x1="${left}" x2="${x(HORIZON)}" y1="${y(v)}" y2="${y(v)}" stroke="#262626"/>
  <text x="${left - 10}" y="${y(v) + 5}" text-anchor="end" fill="#6b6b6b" font-size="15">${v * 100}%</text>`).join('');
const xt = [0, 30, 60, 90, 120].map((d) => `<text x="${x(d)}" y="${H - 22}" text-anchor="middle" fill="#6b6b6b" font-size="15">${d}</text>`).join('');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" font-family="Onest, sans-serif">
  <rect width="100%" height="100%" fill="#0d0d0d"/>
  <text x="${left}" y="24" fill="#a1a1a1" font-size="15">days whose phase label is right (σ: how much cycles vary)</text>
  <rect x="${x(0)}" y="${top}" width="${x(30) - x(0)}" height="${H - top - bottom}" fill="#eeffbb" fill-opacity=".06"/>
  <line x1="${left}" x2="${x(HORIZON)}" y1="${y(chance)}" y2="${y(chance)}" stroke="#e8697c" stroke-dasharray="5 5"/>
  <text x="${x(HORIZON)}" y="${y(chance) + 20}" text-anchor="end" fill="#e8697c" font-size="15">a blind guess</text>
  ${grid}${lines}${xt}
  <text x="${x(60)}" y="${H - 4}" text-anchor="middle" fill="#6b6b6b" font-size="15">days ahead of today</text>
</svg>`;
const html = `<!doctype html><link href="https://fonts.googleapis.com/css2?family=Onest:wght@400;500&display=swap" rel="stylesheet">
<body style="margin:0;background:#0d0d0d"><div id="c" style="width:${W}px">${svg}</div><script>document.fonts.ready.then(() => document.body.dataset.ready = 1)</script></body>`;
const page = join(here, 'data/.chart.html');
writeFileSync(page, html);
const { files } = await capture(`file://${page}`, { selector: '#c', out: join(here, 'img'), width: W, scale: 2 });
execFileSync('mv', [files[0], join(here, 'img/forecast-accuracy.png')]);
execFileSync('rm', [page]);
console.log('→ data/forecast-accuracy.csv, data/forecast-summary.json, img/forecast-accuracy.png');
