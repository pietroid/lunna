// Checks .tool/review.html's logic (its <script id="core">) on a real PR:
// drafts on whole blocks and on selected text land on the right lines, every
// line is in the PR's diff, and threads sit under their blocks. With --post
// it sends the drafts as a PENDING review (seen by nobody but its author,
// never read by the queue), reads back where GitHub put each comment, and
// deletes it.
//
//   node product/improvements/2026-10-21-github-review-and-rfc-shape/code/review-page.mjs <pr> <path> [--post]
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const [pr, path] = process.argv.slice(2);
const post = process.argv.includes('--post');
const repo = 'pietroid/lunna';
const gh = (args, input) => execFileSync('gh', args, { encoding: 'utf8', input });
const api = (url) => JSON.parse(gh(['api', url]));

const html = readFileSync(new URL('../../../../.tool/review.html', import.meta.url), 'utf8');
const core = html.match(/<script id="core">([\s\S]*?)<\/script>/)[1];
const { blocksOf, linesFor, reviewOf, fallbackOf, threadsOf, bodyOf } =
  new Function(`${core}; return { blocksOf, linesFor, reviewOf, fallbackOf, threadsOf, bodyOf };`)();

let ok = true;
const check = (name, pass, detail = '') => {
  ok &&= pass;
  console.log(`${pass ? '✓' : '✗'} ${name}${detail ? `  ${detail}` : ''}`);
};

const sha = api(`repos/${repo}/pulls/${pr}`).head.sha;
const text = gh(['api', `repos/${repo}/contents/${path}?ref=${sha}`, '-H', 'Accept: application/vnd.github.raw']);
const lines = text.split('\n');
const blocks = blocksOf(text);

// The lines GitHub lets a comment sit on: the new side of the file's hunks.
const patch = api(`repos/${repo}/pulls/${pr}/files?per_page=100`).find((f) => f.filename === path)?.patch ?? '';
const inDiff = new Set();
let at = 0;
for (const l of patch.split('\n')) {
  const h = l.match(/^@@ -\d+(?:,\d+)? \+(\d+)/);
  if (h) at = Number(h[1]);
  else if (!l.startsWith('-')) inDiff.add(at++);
}
check(`${path} at ${sha.slice(0, 7)}`, blocks.length > 0, `${lines.length} lines, ${blocks.length} blocks, ${inDiff.size} in the diff`);

// Text as a reader selects it on the page (rendered: no ** or backticks),
// and the line of the Markdown that holds it.
const want = (needle) => lines.findIndex((l) => l.includes(needle)) + 1;
const picks = [
  { quote: 'Line comments need nothing new to host, work in the GitHub app', needle: 'Line comments need nothing new to host' },
  { quote: 'RFCs are shorter, and come in layers: In one minute (under 200 words)', needle: '**RFCs are shorter, and come in layers:**' },
  { quote: 'Measured by the queue: see the pull request.', needle: 'Measured by the queue' },
  { quote: 'Queue: what it reads', needle: '| Queue: what it reads' },
  { quote: '29 of the 31 notes on the RFCs are Q', needle: '29 of the 31 notes' },
];
const drafts = [];
for (const p of picks) {
  const line = want(p.needle);
  if (!line) continue;
  const b = blocks.findIndex((b) => line >= b.start && line <= b.end);
  const d = { block: b, kind: 'Q', text: 'check', quote: p.quote, ...linesFor(blocks[b], p.quote) };
  check(`selection “${p.quote.slice(0, 32)}…”`, d.start === line && d.end === line && inDiff.has(line), `line ${d.start}, want ${line}`);
  drafts.push(d);
}
for (const b of [0, blocks.findIndex((b) => b.text.startsWith('|')), blocks.length - 1].filter((i) => i >= 0)) {
  const d = { block: b, kind: 'Learn', text: `check block ${b}`, quote: '', ...linesFor(blocks[b], '') };
  const all = Array.from({ length: d.end - d.start + 1 }, (_, i) => d.start + i).every((l) => inDiff.has(l));
  check(`block ${b} whole`, d.start === blocks[b].start && d.end === blocks[b].end && all, `lines ${d.start}–${d.end}`);
  drafts.push(d);
}

const review = reviewOf(drafts, path, sha);
check('one review, one comment per draft', review.event === 'COMMENT' && review.comments.length === drafts.length);
check('a draft reads as the queue expects', bodyOf(drafts[0]).startsWith('Q: check\n\n> '), JSON.stringify(bodyOf(drafts[0])));
check('the fallback names file and line', fallbackOf(drafts.slice(0, 1), path).startsWith(`On \`${path}\` line ${drafts[0].start}:`));

const threads = threadsOf([
  { id: 1, path, line: drafts[0].start },
  { id: 2, path, in_reply_to_id: 1, line: drafts[0].start },
  { id: 3, path, line: null, original_line: blocks.at(-1).start },
  { id: 4, path: 'other.md', line: 1 },
], path, blocks);
check('threads under their blocks', threads.length === 2 && threads[0].block === drafts[0].block && threads[0].comments.length === 2 && threads[1].outdated && threads[1].block === blocks.length - 1);

if (post) {
  const { event, ...pending } = review;
  const r = JSON.parse(gh(['api', '-X', 'POST', `repos/${repo}/pulls/${pr}/reviews`, '--input', '-'], JSON.stringify(pending)));
  try {
    const placed = api(`repos/${repo}/pulls/${pr}/reviews/${r.id}/comments`);
    check(`GitHub took the review (pending, id ${r.id})`, r.state === 'PENDING' && placed.length === drafts.length, `${placed.length} comments`);
    // This endpoint answers in the old shape: a comment's place is its
    // position in the diff, which for a file new in the PR is its line.
    console.log(`  fields: ${Object.keys(placed[0]).join(' ')}`);
    for (const c of placed) {
      const d = drafts.find((d) => bodyOf(d) === c.body);
      const line = c.line ?? c.original_line ?? c.position;
      check(`  on line ${line}`, !!d && line === d.end, d ? `draft ${d.start}–${d.end}` : 'no draft');
    }
  } finally {
    gh(['api', '-X', 'DELETE', `repos/${repo}/pulls/${pr}/reviews/${r.id}`]);
    console.log(`  deleted pending review ${r.id}`);
  }
}
process.exit(ok ? 0 : 1);
