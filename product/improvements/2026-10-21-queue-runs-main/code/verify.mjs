// Runs the queue's new pieces on real inputs, from the repo root:
//   node product/improvements/2026-10-21-queue-runs-main/code/verify.mjs
// 1. prBody for issue #14's real state (.git/queue/issues/14.json), against
//    the length of the body the old queue wrote on its PR (#16).
// 2. syncRunner in a scratch dir: a detached worktree at origin/main, moved
//    again on a second call; isRunner false from here. Removed after.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { prBody, reviewUrl, syncRunner, isRunner, runnerDir } from '../../../../.tool/queue.mjs';

const sh = (c, a) => execFileSync(c, a, { encoding: 'utf8' }).trim();
const ok = (b, m) => console.log(`${b ? '✓' : '✗'} ${m}`);
const common = sh('git', ['rev-parse', '--path-format=absolute', '--git-common-dir']);
const cfg = JSON.parse(readFileSync(join(common, 'queue/config.json'), 'utf8'));
const st = JSON.parse(readFileSync(join(common, 'queue/issues/14.json'), 'utf8'));
st.worktree = process.cwd();

const page = reviewUrl(cfg, st);
const body = prBody(cfg, st, sh('git', ['rev-parse', 'HEAD']), '**RFC ready**, waiting for your reply on #14.');
const old = JSON.parse(sh('gh', ['pr', 'view', String(st.pr), '-R', cfg.repo, '--json', 'body'])).body;
ok(page?.startsWith('https://') && page.includes(`pr=${st.pr}`), `review link: ${page}`);
ok(body.includes(page), 'the body links the page');
ok(body.length < 3000, `body ${body.length} chars (the old queue wrote ${old.length} on #${st.pr})`);
console.log('\n----- body -----\n' + body + '\n----------------\n');

const scratch = mkdtempSync(join(tmpdir(), 'runner-'));
const c2 = { ...cfg, worktrees: scratch };
try {
  const dir = syncRunner(c2);
  const head = sh('git', ['-C', dir, 'rev-parse', 'HEAD']);
  ok(head === sh('git', ['rev-parse', 'origin/main']), `runner created at origin/main (${head.slice(0, 7)})`);
  ok(sh('git', ['-C', dir, 'branch', '--show-current']) === '', 'runner is detached');
  sh('git', ['-C', dir, 'checkout', '-q', '--detach', 'HEAD~1']);
  syncRunner(c2);
  ok(sh('git', ['-C', dir, 'rev-parse', 'HEAD']) === head, 'a second sync moves it back to the tip');
  ok(!isRunner(c2) && runnerDir(c2) === dir, 'isRunner is false from this worktree');
} finally {
  execFileSync('git', ['worktree', 'remove', '--force', join(scratch, '.runner')]);
  rmSync(scratch, { recursive: true, force: true });
}
