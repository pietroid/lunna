// The queue's budget gate, as a prototype: may an unattended job start now?
// Reads the subscription's windows from `claude -p "/usage"` (a local
// command: no model call, no tokens) and applies the pacing rule in the RFC.
//   node code/budget.mjs [--session 80] [--reserve 15]
import { execFileSync } from 'node:child_process';

const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? +process.argv[i + 1] : d; };
const SESSION_MAX = arg('--session', 80); // stop starting jobs past this % of the 5-hour window
const RESERVE = arg('--reserve', 15);     // weekly points kept for you, whatever the pacing says

const out = JSON.parse(execFileSync('claude', ['-p', '/usage', '--output-format', 'json'], { encoding: 'utf8' }));
const pct = (label) => +(out.result.match(new RegExp(`${label}: (\\d+)% used`))?.[1] ?? NaN);
const session = pct('Current session');
const week = pct('Current week \\(all models\\)');
const weekReset = out.result.match(/Current week[^\n]*resets ([^\n(]+)/)?.[1]?.trim();

// Pacing: by now the week may have used its elapsed share, less the reserve.
// The reset is printed for people ("Oct 18 at 9:59am", in the machine's
// zone); a stream-json run gives it as epoch seconds in `rate_limit_event`.
const [, mon, day, h, m, ap] = weekReset.match(/(\w+) (\d+) at (\d+)(?::(\d+))?(am|pm)/);
const resetAt = new Date(`${mon} ${day} ${new Date().getFullYear()}`);
resetAt.setHours((+h % 12) + (ap === 'pm' ? 12 : 0), +(m ?? 0));
if (resetAt < Date.now() - 864e5) resetAt.setFullYear(resetAt.getFullYear() + 1); // Dec → Jan
const elapsed = 1 - Math.max(0, resetAt - Date.now()) / (7 * 864e5);
const weekAllowed = Math.max(0, 100 * elapsed - RESERVE);

const go = session < SESSION_MAX && week < weekAllowed;
console.log(JSON.stringify({ session, week, weekReset, elapsed: +elapsed.toFixed(2), weekAllowed: +weekAllowed.toFixed(1), go }));
process.exit(go ? 0 : 1);
