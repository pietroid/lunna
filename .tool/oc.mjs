#!/usr/bin/env node
// .tool/oc <brief.md> [--minutes 9] [--model provider/model]
//
// Hands the heavy code writing of a /build to opencode, in this checkout, and
// says in one line whether it worked. Anything but `ok` exits 2: the caller
// (Claude) builds the piece itself from where the tree now is. It never hangs:
// `opencode run` auto-rejects permission asks (and stops), and the run is
// killed at --minutes (default 9, so it fits in one Bash call).
//
// Writes next to the brief: report.md (opencode's last words), oc.json (the
// verdict) and oc.log (the raw events; don't read it, it is the expensive part).

import { spawn, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync, createWriteStream } from 'node:fs';
import { dirname, resolve } from 'node:path';

const args = process.argv.slice(2);
const opt = (name, dflt) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args.splice(i, 2)[1] : dflt;
};
const minutes = Number(opt('minutes', 9));
const model = opt('model', process.env.OC_MODEL || 'opencode/deepseek-v4-pro');
const brief = args[0] && resolve(args[0]);
if (!brief || !existsSync(brief)) {
  console.error('usage: .tool/oc <brief.md> [--minutes 9] [--model provider/model]');
  process.exit(1);
}
const out = dirname(brief);
const root = execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();

// What the tree looks like now, so only opencode's changes are reported.
const snapshot = () => {
  const files = execFileSync('git', ['status', '--porcelain', '-uall'], { cwd: root, encoding: 'utf8' })
    .split('\n').filter(Boolean).map((l) => l.slice(3).replace(/^.* -> /, ''));
  return new Map(files.map((f) => {
    const p = resolve(root, f);
    return [f, existsSync(p) ? createHash('sha1').update(readFileSync(p)).digest('hex') : 'gone'];
  }));
};
const before = snapshot();

const prompt = [
  'Implement the attached brief in this repository. AGENTS.md is the spec of the project.',
  'Change only what the brief lists; nothing from its Not doing; no refactors, no docs.',
  "Run only its Done-when checks, and stop as soon as they pass. Don't commit.",
  'End with a short report: files changed, what you skipped, what you are unsure of, which checks pass.',
].join(' ');

const verdict = (outcome, extra = {}) => {
  const after = snapshot();
  const changed = [...after].filter(([f, h]) => before.get(f) !== h && !resolve(root, f).startsWith(out + '/')).map(([f]) => f);
  const v = { outcome: outcome === 'ok' && !changed.length ? 'no_changes' : outcome, model, changed, ...extra };
  writeFileSync(resolve(out, 'oc.json'), JSON.stringify(v, null, 2) + '\n');
  const ok = v.outcome === 'ok';
  console.log(`${ok ? '✓' : '✗'} opencode: ${v.outcome}${v.detail ? ` (${v.detail})` : ''}, ${changed.length} file(s) changed${v.tokens ? `, ${v.tokens} tokens` : ''}`);
  for (const f of changed) console.log(`  ${f}`);
  if (existsSync(resolve(out, 'report.md'))) console.log(`  report: ${resolve(out, 'report.md')}`);
  if (!ok) console.log('→ fall back: build the piece yourself, from the tree as it is now (keep what compiles, revert the rest).');
  process.exit(ok ? 0 : 2);
};

const which = spawn('sh', ['-c', 'command -v opencode'], { stdio: 'ignore' });
which.on('exit', (code) => (code === 0 ? run() : verdict('missing', { detail: 'opencode is not on PATH' })));

function run() {
  const log = createWriteStream(resolve(out, 'oc.log'));
  const child = spawn('opencode', ['run', '--format', 'json', '-m', model, '--title', 'oc', '-f', brief, '--', prompt], {
    cwd: root, detached: true, stdio: ['ignore', 'pipe', 'pipe'],
  });
  const errors = [];
  const rejected = [];
  const text = [];
  let tokens = 0;
  let buf = '';
  let timedOut = false;
  let lastErr = '';

  child.stdout.on('data', (d) => {
    log.write(d);
    buf += d;
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i);
      buf = buf.slice(i + 1);
      let e;
      try { e = JSON.parse(line); } catch { continue; }
      if (e.type === 'error') errors.push(e.error?.data?.message || e.error?.name || 'error');
      if (e.type === 'step_finish') tokens += e.part?.tokens?.total || 0;
      if (e.type === 'text' && e.part?.text) text.push(e.part.text);
      const err = e.part?.state?.status === 'error' ? String(e.part.state.error || '') : '';
      if (/rejected permission/i.test(err)) rejected.push(`${e.part.tool}: ${JSON.stringify(e.part.state.input).slice(0, 120)}`);
    }
  });
  child.stderr.on('data', (d) => {
    log.write(d);
    const lines = String(d).replace(/\x1b\[[0-9;]*m/g, '').split('\n').map((l) => l.trim()).filter(Boolean);
    if (lines.length) lastErr = lines.at(-1);
    for (const m of String(d).matchAll(/permission requested: (.*?); auto-rejecting/g)) rejected.push(m[1]);
  });

  const killAll = (sig) => { try { process.kill(-child.pid, sig); } catch {} };
  const timer = setTimeout(() => {
    timedOut = true;
    killAll('SIGTERM');
    setTimeout(() => killAll('SIGKILL'), 5000).unref();
  }, minutes * 60_000);

  child.on('exit', (code) => {
    clearTimeout(timer);
    log.end();
    if (text.length) writeFileSync(resolve(out, 'report.md'), text.join('\n\n') + '\n');
    const all = errors.join(' | ');
    const base = { tokens, errors, rejected: [...new Set(rejected)] };
    if (timedOut) return verdict('timeout', { ...base, detail: `killed after ${minutes} min` });
    if (/rate.?limit|429|quota|credit|insufficient|billing|usage limit|exceeded|too many requests/i.test(all))
      return verdict('limit', { ...base, detail: all.slice(0, 200) });
    if (base.rejected.length) return verdict('permission', { ...base, detail: base.rejected[0] });
    if (errors.length || code !== 0) return verdict('error', { ...base, detail: (all || lastErr || `exit ${code}`).slice(0, 200) });
    return verdict('ok', base);
  });
}
