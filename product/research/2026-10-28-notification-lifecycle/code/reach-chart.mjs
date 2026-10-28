// How many days the phone's 60 queued reminders cover, by fixed blocks a day.
//
//   node product/research/2026-10-28-notification-lifecycle/code/reach-chart.mjs
//
// Reads data/plan-count.csv (from plan-count.ts) and writes img/reach.svg
// (then: Chrome --headless=new --force-device-scale-factor=2 --window-size=780,520
// --screenshot=img/reach.png file://.../img/reach.svg).
import * as fs from 'node:fs';
import * as path from 'node:path';

const here = path.dirname(new URL(import.meta.url).pathname);
const root = path.join(here, '..');

const [head, ...lines] = fs
  .readFileSync(path.join(root, 'data', 'plan-count.csv'), 'utf8')
  .trim()
  .split('\n');
const cols = head.split(',');
const rows = lines.map((l) =>
  Object.fromEntries(l.split(',').map((v, i) => [cols[i], Number(v)])),
);

const W = 780;
const H = 520;
const left = 64;
const right = 200;
const top = 70;
const bottom = 70;
const x = (n) => left + (n / 6) * (W - left - right);
const y = (d) => top + (1 - d / 7) * (H - top - bottom);

const bg = '#000000';
const ink = '#F5F5F5';
const ink2 = '#A1A1A1';
const grid = '#2B2B2B';
const lime = '#EEFFBB';

const series = [
  { key: 'today_reach_days', label: 'Today', colour: ink2, dash: 'none' },
  { key: 'proposed_reach_days', label: 'Every ask queued', colour: ink, dash: '10 8' },
  { key: 'trimmed_reach_days', label: 'Re-asks for 24 h', colour: lime, dash: 'none' },
];

const gridLines = [0, 1, 2, 3, 4, 5, 6, 7]
  .map(
    (d) => `
  <line x1="${left}" y1="${y(d)}" x2="${W - right}" y2="${y(d)}" stroke="${grid}" stroke-width="1"/>
  <text x="${left - 12}" y="${y(d) + 6}" fill="${ink2}" font-size="16" text-anchor="end">${d}</text>`,
  )
  .join('');

const ticks = rows
  .map(
    (r) =>
      `<text x="${x(r.blocks_per_day)}" y="${H - bottom + 28}" fill="${ink2}" font-size="16" text-anchor="middle">${r.blocks_per_day}</text>`,
  )
  .join('');

const paths = series
  .map((s) => {
    const pts = rows.map((r) => `${x(r.blocks_per_day)},${y(r[s.key])}`).join(' ');
    const last = rows[rows.length - 1];
    const dots = rows
      .map(
        (r) =>
          `<circle cx="${x(r.blocks_per_day)}" cy="${y(r[s.key])}" r="5" fill="${s.colour}" stroke="${bg}" stroke-width="2"/>`,
      )
      .join('');
    return `
  <polyline points="${pts}" fill="none" stroke="${s.colour}" stroke-width="3" stroke-dasharray="${s.dash}"/>
  ${dots}
  <text x="${x(6) + 14}" y="${y(last[s.key]) + 6}" fill="${ink}" font-size="17">${s.label}</text>`;
  })
  .join('');

// The typical day: breakfast, lunch and dinner.
const three = rows.find((r) => r.blocks_per_day === 3);
const marker = `
  <line x1="${x(3)}" y1="${top}" x2="${x(3)}" y2="${H - bottom}" stroke="${ink2}" stroke-dasharray="4 6" stroke-width="2"/>
  <text x="${x(3) + 14}" y="${top + 50}" fill="${ink2}" font-size="15">3 meals a day</text>
  <text x="${x(3) - 10}" y="${y(three.proposed_reach_days) + 22}" fill="${ink}" font-size="17" font-weight="600" text-anchor="end">${three.proposed_reach_days.toFixed(1)} d</text>
  <text x="${x(3) + 10}" y="${y(three.trimmed_reach_days) - 12}" fill="${lime}" font-size="17" font-weight="600">${three.trimmed_reach_days.toFixed(1)} d</text>`;

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="Arial">
  <rect width="${W}" height="${H}" fill="${bg}"/>
  <text x="${left - 40}" y="38" fill="${ink2}" font-size="18">Days the 60 queued reminders cover (plan: 7)</text>
  ${gridLines}
  ${ticks}
  <text x="${(left + W - right) / 2}" y="${H - 18}" fill="${ink2}" font-size="16" text-anchor="middle">fixed blocks a day</text>
  ${marker}
  ${paths}
</svg>
`;
fs.writeFileSync(path.join(root, 'img', 'reach.svg'), svg);
console.log('img/reach.svg');
