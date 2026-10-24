// What a month of Neon compute costs, today and after each change.
//
//   node product/research/2026-10-23-neon-compute/code/estimate.mjs
//
// Writes data/estimate.csv and img/cu-hours.svg (then: magick -density 192 -font
// /System/Library/Fonts/Supplemental/Arial.ttf img/cu-hours.svg img/cu-hours.png). Every assumption is a constant below.
import * as fs from 'node:fs';
import * as path from 'node:path';

const here = path.dirname(new URL(import.meta.url).pathname);
const root = path.join(here, '..');

const CU = 0.25; // the smallest compute; Neon bills CU × hours awake
const PRICE = 0.106; // $ per CU-hour on Launch (neon.com/pricing, 2026-10)
const FREE = 100; // CU-hours per project per month on Free
const DAYS = 30;
const TAIL_H = 5 / 60; // Neon stays up 5 minutes after the last query

// Measured on the console: 100.17 CU-hours in 19 days.
const measured = (100.17 / 19) * DAYS;

// Assumed use: two people, ten openings a day each, three minutes each.
const PEOPLE = 2;
const OPENINGS = 10;
const OPEN_H = 3 / 60;
// The phone's background refresh: every 6 hours (background_refresh.dart).
const REFRESHES = 4;
// A browser tab left open through the working day (07:00 to 22:00).
const TAB_H = 15;

const use = PEOPLE * OPENINGS * (OPEN_H + TAIL_H); // ≤, sessions overlap
const background = PEOPLE * REFRESHES * TAIL_H;

const rows = [
  ['Today (measured)', measured],
  ['Tick only when due, a web tab left open', CU * (TAB_H + TAIL_H) * DAYS],
  ['Tick only when due, hidden tabs stop polling', CU * (use + background) * DAYS],
].map(([name, hours]) => ({
  name,
  hours: Math.round(hours * 10) / 10,
  launch: Math.round(hours * PRICE * 100) / 100,
  free: hours <= FREE ? 'fits' : 'over',
}));

fs.writeFileSync(
  path.join(root, 'data', 'estimate.csv'),
  'scenario,cu_hours_per_month,launch_usd,free_plan\n' +
    rows.map((r) => `${r.name},${r.hours},${r.launch},${r.free}`).join('\n') +
    '\n',
);
console.table(rows);

// The chart: one bar per scenario, the Free allowance as a line.
const chart = rows;
const labels = [
  'Today, measured',
  'Fix the tick only (web tab open)',
  'Fix the tick + pause hidden tabs',
];
const W = 780;
const H = 420;
const left = 40;
const top = 70;
const barH = 56;
const gap = 54;
const max = 210;
const x = (v) => left + (v / max) * (W - left - 60);
const bg = '#000000';
const ink = '#F5F5F5';
const ink2 = '#A1A1A1';
const lime = '#EEFFBB';
const fill = '#2B2B2B';

const bars = chart
  .map((r, i) => {
    const y = top + 20 + i * (barH + gap);
    const colour = i === chart.length - 1 ? lime : fill;
    return `
  <text x="${left}" y="${y - 12}" fill="${ink}" font-size="20">${labels[i]}</text>
  <rect x="${left}" y="${y}" width="${x(r.hours) - left}" height="${barH}" rx="8" fill="${colour}"/>
  <text x="${x(r.hours) + 10}" y="${y + 36}" fill="${ink}" font-size="20" font-weight="600">${Math.round(r.hours)} h · $${r.launch.toFixed(2)}</text>`;
  })
  .join('');

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="Arial">
  <rect width="${W}" height="${H}" fill="${bg}"/>
  <text x="${left}" y="38" fill="${ink2}" font-size="18">CU-hours a month, and the price on Launch</text>
  ${bars}
  <line x1="${x(FREE)}" y1="${top}" x2="${x(FREE)}" y2="${H - 30}" stroke="${lime}" stroke-dasharray="10 8" stroke-width="3"/>
  <text x="${x(FREE) + 8}" y="${H - 14}" fill="${lime}" font-size="18">Free plan: 100 h</text>
</svg>
`;
fs.writeFileSync(path.join(root, 'img', 'cu-hours.svg'), svg);
