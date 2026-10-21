#!/usr/bin/env node
// The mirror, dry run: what Multica should show for each issue the queue
// knows, and the `multica` commands that would make it so. Nothing is sent.
//
//   node code/mirror.mjs              (from the topic folder, or anywhere in the repo)
//
// It reads the queue's own state (.git/queue/issues/*.json), so it is the
// same function the queue would call on every tick: level-triggered, the
// whole desired state each time, never "what changed since last time".
import { execFileSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

// Multica's built-in statuses (docs: issues.mdx). One per queue state.
export function desired(st) {
  if (st.status === 'done') return 'done';
  if (st.waitUntil) return 'blocked'; // paused on the usage limit
  if (st.status === 'failed') return 'blocked';
  if (st.next || st.status === 'working') return st.runs?.length ? 'in_progress' : 'todo';
  if (st.status === 'waiting') return 'in_review'; // a gate: your turn
  return 'todo';
}

// The commands that bring Multica to `desired`, given what it shows now
// (`current`, from `multica issue list --metadata …`; null when there is no
// mirror yet).
export function commands(st, current) {
  const want = desired(st);
  const pr = st.pr ? ` · PR #${st.pr}` : '';
  if (!current) {
    return [
      `multica issue create --title ${JSON.stringify(`#${st.issue} ${st.title}`)} --status ${want} --project Queue --description-stdin   # body + links${pr}`,
      `multica issue metadata set <new-id> github_issue ${st.issue}`,
    ];
  }
  return current.status === want ? [] : [`multica issue status ${current.id} ${want}`];
}

const common = execFileSync('git', ['rev-parse', '--path-format=absolute', '--git-common-dir'], { encoding: 'utf8' }).trim();
const dir = join(common, 'queue', 'issues');
if (!existsSync(dir)) { console.log('no queue state here (.git/queue/issues)'); process.exit(0); }
const all = readdirSync(dir).filter((f) => f.endsWith('.json')).map((f) => JSON.parse(readFileSync(join(dir, f), 'utf8'))).sort((a, b) => a.issue - b.issue);

console.log('| Issue | Kind | Queue state | Gate | Runs | Multica status |');
console.log('|---|---|---|---|---|---|');
for (const st of all) {
  console.log(`| #${st.issue} | ${st.kind} | ${st.next ? `next: ${st.next.phase}` : st.status} | ${st.gate ?? '—'} | ${st.runs.length} | \`${desired(st)}\` |`);
}
console.log('\nFirst tick, nothing mirrored yet:\n');
for (const st of all) for (const c of commands(st, null)) console.log(c);
console.log('\nA later tick, where Multica already shows the right status: no commands.');
