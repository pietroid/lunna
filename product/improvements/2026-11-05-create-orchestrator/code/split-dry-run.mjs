#!/usr/bin/env node
// Runs the queue's split phase (/create, Sonnet, low effort, lean session)
// on an ask, in this checkout, without GitHub: prints the pieces and what
// the run cost. Usage: node split-dry-run.mjs <ask.txt> [log.jsonl] [pieces.txt reply]
// With pieces.txt (the parent's list) and a reply, runs the answer to a reply
// on the parent instead: start / backlog / drop and any new pieces.
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { SCHEMA, rules, prompt, RUN, LEAN, denies } from '../../../../.tool/queue.mjs';

const [askFile, logFile = '/tmp/split-dry-run.jsonl', piecesFile, reply] = process.argv.slice(2);
const [title, ...rest] = readFileSync(askFile, 'utf8').split('\n');
const st = { issue: 0, kind: 'create', title, body: rest.join('\n').trim(), url: '(dry run)', worktree: process.cwd(), branch: '(none)', pieceText: piecesFile && readFileSync(piecesFile, 'utf8').trim() };

// The reply words the queue reads as "no".
for (const [said, want] of [['no', true], ['Não.', true], ['backlog', true], ['depois', true], ['no, but change the icon', false], ['approve', false]]) {
  const got = denies([{ kind: 'comment', body: said }]);
  console.log(`${got === want ? '✓' : '✗'} denies("${said}") = ${got}`);
}

const [model, effort] = RUN['create:split'];
const args = ['-p', prompt(st, 'split', reply ?? null), '--output-format', 'stream-json', '--verbose', '--permission-mode', 'auto',
  '--max-turns', '60', '--json-schema', SCHEMA, '--append-system-prompt', rules(st), '--model', model, '--effort', effort, ...LEAN];
const run = spawnSync('claude', args, { encoding: 'utf8', env: { ...process.env, LUNNA_QUEUE: '1' }, maxBuffer: 256 << 20 });
writeFileSync(logFile, run.stdout);
const events = run.stdout.split('\n').filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return {}; } });
const init = events.find((e) => e.type === 'system' && e.subtype === 'init');
const result = events.find((e) => e.type === 'result');
const first = events.find((e) => e.type === 'assistant')?.message?.usage ?? {};
const out = result?.structured_output;
console.log(`model ${init?.model} · tools ${init?.tools?.length} · skills ${init?.skills?.length} · first turn ${(first.input_tokens ?? 0) + (first.cache_read_input_tokens ?? 0) + (first.cache_creation_input_tokens ?? 0)} tokens`);
console.log(`${result?.num_turns} turns · $${result?.total_cost_usd?.toFixed(3)} · ${Math.round((result?.duration_ms ?? 0) / 1000)} s · ${result?.is_error ? '✗ error' : '✓ ok'}`);
if (!out) { console.log('✗ no structured output:', (result?.result ?? run.stderr).slice(-500)); process.exit(1); }
console.log(`\n${out.summary}\n`);
if (reply) console.log(`reply "${reply}" → start ${JSON.stringify(out.start ?? [])} · backlog ${JSON.stringify(out.backlog ?? [])} · drop ${JSON.stringify(out.drop ?? [])} · new ${(out.children ?? []).length}`);
console.log('| # | Kind | Piece | Estimate | Impact | After |\n|---|---|---|---|---|---|');
(out.children ?? []).forEach((c, i) => console.log(`| ${i} | ${c.kind} | ${c.title} | ${c.estimate} | ${c.impact} | ${c.after ?? ''} |`));
for (const c of out.children ?? []) console.log(`\n**${c.title}**\n${c.body}`);
