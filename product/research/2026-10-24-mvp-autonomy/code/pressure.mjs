// Which delivery is really in trouble: the app's lag against a pressure
// measured in free hours.
//
//   node product/research/2026-10-24-mvp-autonomy/code/pressure.mjs
//
// lag is what Entregas sorts by today (app/packages/artifacts/lib/src/view/
// pace_bars.dart:168, models.dart:280): the share of calendar time gone
// since the delivery was made, less the share of its work done.
//
// pressure is the proposal: the work still owed by each deadline (its own
// and every delivery due before it: earliest deadline first) over the free
// working minutes left before that deadline. Over 100% cannot be done.
//
// Writes data/pressure.csv and img/pressure.svg (then: magick -density 192
// img/pressure.svg img/pressure.png). Every assumption is a constant below.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');

/** Monday 26/10/2026. */
const TODAY = '2026-10-26';
/** Free working hours a weekday has after fixed blocks and routines; none on weekends. */
const FREE_WEEKDAY_MIN = 4 * 60;

const deliveries = [
  { title: 'Mapa astral da Júlia', created: '2026-10-22', due: '2026-10-28', minutes: 3 * 60, done: 0 },
  { title: 'Site da Ana', created: '2026-10-01', due: '2026-11-06', minutes: 30 * 60, done: 10 * 60 },
  { title: 'Tese', created: '2026-10-01', due: '2026-11-30', minutes: 20 * 60, done: 12 * 60 },
];

const day = (s) => new Date(`${s}T12:00:00Z`);
const days = (a, b) => Math.round((day(b) - day(a)) / 86_400_000);

/** Free minutes from today to the end of [due], counting the due day. */
function freeUntil(due) {
  let free = 0;
  for (let d = day(TODAY); d <= day(due); d = new Date(d.getTime() + 86_400_000)) {
    const wd = d.getUTCDay();
    if (wd !== 0 && wd !== 6) free += FREE_WEEKDAY_MIN;
  }
  return free;
}

function lagOf(it) {
  const gone = Math.min(1, Math.max(0, days(it.created, TODAY) / days(it.created, it.due)));
  return gone - it.done / it.minutes;
}

const byDue = [...deliveries].sort((a, b) => a.due.localeCompare(b.due));
let owedSoFar = 0;
const rows = byDue.map((it) => {
  owedSoFar += it.minutes - it.done;
  return {
    title: it.title,
    due: it.due,
    owedHours: (it.minutes - it.done) / 60,
    freeHours: freeUntil(it.due) / 60,
    lag: lagOf(it),
    pressure: owedSoFar / freeUntil(it.due),
  };
});

fs.writeFileSync(
  path.join(root, 'data', 'pressure.csv'),
  'title,due,owed_h,free_h_until_due,lag_today,pressure_proposed\n' +
    rows
      .map((r) => [r.title, r.due, r.owedHours, r.freeHours, r.lag.toFixed(2), r.pressure.toFixed(2)].join(','))
      .join('\n') +
    '\n',
);
console.table(rows);

// The chart: for each delivery, today's lag (grey) and the pressure (lime).
const W = 780;
const H = 520;
const left = 40;
const top = 96;
const barH = 34;
const group = 128;
const x = (v) => left + Math.max(0, v) * (W - left - 150);
const bg = '#000000';
const ink = '#F5F5F5';
const ink2 = '#A1A1A1';
const lime = '#EEFFBB';
const fill = '#4A4A4A';
const pct = (v) => `${Math.round(v * 100)}%`;

const bars = rows
  .map((r, i) => {
    const y = top + 30 + i * group;
    return `
  <text x="${left}" y="${y - 10}" fill="${ink}" font-size="21">${r.title} · ${r.due.slice(8, 10)}/${r.due.slice(5, 7)}</text>
  <rect x="${left}" y="${y}" width="${Math.max(4, x(r.lag) - left)}" height="${barH}" rx="6" fill="${fill}"/>
  <text x="${Math.max(left + 4, x(r.lag)) + 10}" y="${y + 25}" fill="${ink2}" font-size="19">lag ${pct(r.lag)}</text>
  <rect x="${left}" y="${y + barH + 6}" width="${x(r.pressure) - left}" height="${barH}" rx="6" fill="${lime}"/>
  <text x="${x(r.pressure) + 10}" y="${y + barH + 31}" fill="${lime}" font-size="19" font-weight="600">${pct(r.pressure)} of free hours</text>`;
  })
  .join('');

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="Arial">
  <rect width="${W}" height="${H}" fill="${bg}"/>
  <text x="${left}" y="40" fill="${ink}" font-size="22" font-weight="600">Most behind is not most at risk</text>
  <text x="${left}" y="70" fill="${ink2}" font-size="18">grey: lag Entregas sorts by · lime: work owed ÷ free hours to the deadline</text>
  ${bars}
</svg>
`;
fs.writeFileSync(path.join(root, 'img', 'pressure.svg'), svg);
