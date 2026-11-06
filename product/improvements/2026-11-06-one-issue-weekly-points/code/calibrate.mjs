// API-equivalent USD per 1 % of the weekly window, from the queue's own runs:
// each run's priced tokens against /usage's "Current week" before and after.
//   node calibrate.mjs [<.git/queue/issues>]
import { readFileSync, readdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const dir = process.argv[2] ?? `${execFileSync('git', ['rev-parse', '--path-format=absolute', '--git-common-dir'], { encoding: 'utf8' }).trim()}/queue/issues`;
const runs = readdirSync(dir).flatMap((f) => JSON.parse(readFileSync(`${dir}/${f}`, 'utf8')).runs ?? []);
const ok = runs.filter((r) => r.before?.week != null && r.after?.week != null && r.after.week >= r.before.week);
const end = (r) => new Date(r.started).getTime() + r.ms;
const alone = ok.filter((r) => r.usd > 1 && !runs.some((o) => o !== r && new Date(o.started) < end(r) && end(o) > new Date(r.started)));
for (const [name, set] of [['all runs', ok], ['runs > $1 with nothing alongside', alone]]) {
  const usd = set.reduce((s, r) => s + r.usd, 0), wk = set.reduce((s, r) => s + r.after.week - r.before.week, 0);
  console.log(`${name.padEnd(34)} ${String(set.length).padStart(4)} runs  $${usd.toFixed(0).padStart(4)}  +${wk} % of the week  → $${(usd / wk).toFixed(2)} per 1 %`);
}
