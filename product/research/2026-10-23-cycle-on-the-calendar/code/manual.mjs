// Does a typed period start forecast the next 30 days as well as six
// cycles read from Health? Same simulated people as forecast.mjs (mean
// cycle ~ N(28.7, 2.5), spread σ, luteal ~ N(12.4, 2.4) clipped 7–17),
// same forecast (next start = last start + length, ovulation 13 days
// before, 5 days of bleeding). Only the length changes:
//
//   health    the median of the last six cycles (the RFC's design)
//   typed     the person's own mean, rounded, typed once ("about 29 days")
//   typed ±2  the same, misremembered by N(0, 2) days
//   default   nothing typed: 28 days
//
// In every case the start of the current period is known: logged in
// Health, or typed into Lunna the day it came. Writes data/manual-vs-health.json.
//
//   node code/manual.mjs
import { writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const here = resolve(import.meta.dirname, '..');
const PEOPLE = 4000, BLEED = 5, WINDOW = 30;

let seed = 7;
const rand = () => ((seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296);
const normal = () => Math.sqrt(-2 * Math.log(rand() || 1e-9)) * Math.cos(2 * Math.PI * rand());
const clip = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const median = (xs) => { const s = [...xs].sort((a, b) => a - b); const m = s.length >> 1; return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };

function label(starts, luteal, day) {
  const i = starts.findLastIndex((s) => s <= day);
  const start = starts[i], next = starts[i + 1];
  if (day - start < BLEED) return 'menstrual';
  const ovulation = next - luteal[i];
  if (day >= ovulation - 5 && day <= ovulation) return 'fertile';
  return day > ovulation ? 'luteal' : 'follicular';
}

const ways = ['health', 'typed', 'typed ±2', 'default'];
const out = [];
for (const sigma of [2, 4, 6]) {
  const right = Object.fromEntries(ways.map((w) => [w, 0]));
  const startOff = Object.fromEntries(ways.map((w) => [w, 0]));
  for (let p = 0; p < PEOPLE; p++) {
    const mean = clip(28.7 + 2.5 * normal(), 22, 38);
    const cycles = Array.from({ length: 10 }, () => Math.round(clip(mean + sigma * normal(), 18, 50)));
    const luteal = cycles.map((c) => Math.min(Math.round(clip(12.4 + 2.4 * normal(), 7, 17)), c - BLEED - 1));
    const starts = [0];
    for (const c of cycles) starts.push(starts.at(-1) + c);
    const anchor = starts[6];
    const length = {
      health: median(cycles.slice(0, 6)),
      typed: Math.round(mean),
      'typed ±2': Math.round(mean + 2 * normal()),
      default: 28,
    };
    const today = anchor + Math.floor(rand() * Math.min(cycles[6], Math.round(length.health)));
    for (const w of ways) {
      const predicted = Array.from({ length: 4 }, (_, k) => Math.round(anchor + k * length[w]));
      const lut = predicted.map(() => 13);
      for (let d = 0; d <= WINDOW; d++) {
        if (label(starts, luteal, today + d) === label(predicted, lut, today + d)) right[w]++;
      }
      startOff[w] += Math.abs(predicted[1] - starts[7]);
    }
  }
  for (const w of ways) {
    out.push({ sigma, way: w, daysRight: right[w] / (PEOPLE * (WINDOW + 1)), nextStartOffDays: startOff[w] / PEOPLE });
  }
}
writeFileSync(join(here, 'data/manual-vs-health.json'), JSON.stringify(out, null, 2) + '\n');
console.table(out.map((r) => ({ ...r, daysRight: `${Math.round(r.daysRight * 100)}%`, nextStartOffDays: r.nextStartOffDays.toFixed(1) })));
