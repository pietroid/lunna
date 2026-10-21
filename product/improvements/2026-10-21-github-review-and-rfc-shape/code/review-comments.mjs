#!/usr/bin/env node
// Checks how the queue reads a review: fixtures shaped like GitHub's REST
// answers (pulls/{pr}/comments, pulls/{pr}/reviews), then one real read of
// an open PR. Run from the repo root:
//
//   node product/improvements/2026-10-21-github-review-and-rfc-shape/code/review-comments.mjs [pr] [issue]
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { answers, approves, feedback, lineComment } from '../../../../.tool/queue.mjs';

const doc = 'product/research/2026-10-20-shorebird-mobile-deploy/README.md';
const hunk = '@@ -0,0 +1,12 @@\n+# Instant deploys on the phone with Shorebird\n+\n+## Thesis\n+\n+**Ship every push to `main` to the phones as a Shorebird patch,**';
const ok = (name, fn) => { fn(); console.log(`✓ ${name}`); };

// A single-line comment, a reply in its thread, a two-line comment, a file comment.
const one = lineComment({ id: 11, path: doc, line: 5, start_line: null, diff_hunk: hunk, body: ' Q: why patches and not releases? ', created_at: '2026-10-21T10:00:00Z' });
const reply = lineComment({ id: 12, in_reply_to_id: 11, path: doc, line: 5, diff_hunk: hunk, body: 'and on iOS?', created_at: '2026-10-21T10:01:00Z' });
const two = lineComment({ id: 13, path: doc, line: 5, start_line: 4, diff_hunk: hunk, body: 'Learn: explain this', created_at: '2026-10-21T10:02:00Z' });
const file = lineComment({ id: 14, path: doc, subject_type: 'file', line: null, diff_hunk: hunk, body: 'too long', created_at: '2026-10-21T10:03:00Z' });
const outdated = lineComment({ id: 15, path: doc, line: null, original_line: 5, diff_hunk: hunk, body: 'still?', created_at: '2026-10-21T10:04:00Z' });

ok('a line comment quotes its line and is its own thread', () => {
  assert.deepEqual([one.thread, one.line, one.lines], [11, 5, ['**Ship every push to `main` to the phones as a Shorebird patch,**']]);
  assert.equal(one.body, 'Q: why patches and not releases?');
});
ok('a reply goes to the thread it answers', () => assert.equal(reply.thread, 11));
ok('a comment on lines 4–5 quotes both', () => assert.equal(two.lines.length, 2));
ok('a comment on the whole file quotes nothing', () => assert.deepEqual([file.lines, file.line], [[], null]));
ok('an outdated comment keeps its original line', () => assert.equal(outdated.line, 5));

ok('feedback names file, line and thread, and quotes the line', () => {
  const text = feedback([{ kind: 'comment', body: 'Looks good, two things:' }, one, file]);
  assert.match(text, /^Looks good, two things:/);
  assert.match(text, /On `product\/research\/2026-10-20-shorebird-mobile-deploy\/README.md` line 5 \(thread 11\), about:\n> \*\*Ship every push/);
  assert.match(text, /line 5 \(thread 11\), about:[\s\S]*\n\nQ: why patches and not releases\?/);
  assert.match(text, /README.md` \(thread 14\):\n\ntoo long/);
});

ok('"approve" alone approves, on the issue or as a review', () => {
  assert.equal(approves([{ kind: 'comment', body: 'approve' }]), true);
  assert.equal(approves([{ kind: 'review', body: 'lgtm' }]), true);
});
ok('a line comment is never an approval', () => {
  assert.equal(approves([{ kind: 'comment', body: 'approve' }, one]), false);
  assert.equal(approves([{ ...one, body: 'ok' }]), false);
});

// The real endpoints, read only.
const repo = JSON.parse(execFileSync('gh', ['repo', 'view', '--json', 'nameWithOwner'], { encoding: 'utf8' })).nameWithOwner;
const owner = execFileSync('gh', ['api', 'user', '--jq', '.login'], { encoding: 'utf8' }).trim();
const [pr, issue] = process.argv.slice(2).map(Number);
if (pr) {
  const said = answers({ repo, owner }, { issue, pr, gateAt: '2000-01-01T00:00:00Z' });
  console.log(`✓ read ${repo} #${issue} + PR #${pr} as ${owner}: ${said.length} answers (${['comment', 'review', 'line'].map((k) => `${said.filter((c) => c.kind === k).length} ${k}`).join(', ')})`);
  for (const c of said) console.log(`  ${c.at} ${c.kind} ${c.body.split('\n')[0].slice(0, 80)}`);
}
