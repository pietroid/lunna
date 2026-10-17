#!/usr/bin/env node
// The way into the Markdown under product/: list it, open one in the
// annotate page, or print only the notes left on it.
//
//   .tool/doc ls [words]            docs, newest first, with open questions
//   .tool/doc open [file|words]     serve it with annotate.mjs and open the browser
//   .tool/doc notes [file|words]    the notes alone, with line and heading
//         [--open]                  only questions nobody answered yet
//
// A doc is named by its path, or by words that all appear in its path
// ("agent reliab"); a folder's README.md wins over the files beside it,
// then the newest match. No name means the newest doc.
import { spawn, execFileSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import { createServer } from 'node:net';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const docsDir = join(root, 'product');
const NOTE = /^> \*\*(Q|A|Learn|Decision|Note)\b[^:]*:\*\* ?(.*)$/;

function docs() {
  const found = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith('.md')) found.push({ path, mtime: statSync(path).mtimeMs });
    }
  };
  if (existsSync(docsDir)) walk(docsDir);
  return found.sort((a, b) => b.mtime - a.mtime);
}

function pick(args) {
  const name = args.filter((a) => !a.startsWith('--'));
  const direct = name.length === 1 && resolve(name[0]);
  if (direct && existsSync(direct) && statSync(direct).isFile()) return direct;
  const words = name.map((w) => w.toLowerCase());
  const hits = docs().filter(({ path }) => words.every((w) => relative(root, path).toLowerCase().includes(w)));
  const hit = hits.find(({ path }) => path.endsWith('/README.md')) ?? hits[0];
  if (!hit) fail(`no doc under product/ matches "${name.join(' ')}"`);
  return hit.path;
}

// Every note in the file, with the heading it sits under. A question is
// answered when an `A` note follows it before anything else does.
function notesOf(file) {
  const lines = readFileSync(file, 'utf8').split('\n');
  const notes = [];
  const trail = [];
  let fence = false;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^\s*(```|~~~)/.test(line)) fence = !fence;
    if (fence) continue;
    const heading = line.match(/^(#{1,6})\s+(.*)/);
    if (heading) {
      trail.length = heading[1].length - 1;
      trail[heading[1].length - 1] = heading[2].trim();
      continue;
    }
    const note = line.match(NOTE);
    if (!note) continue;
    const body = [note[2]];
    while (lines[i + 1]?.startsWith('>') && !NOTE.test(lines[i + 1])) body.push(lines[++i].replace(/^> ?/, ''));
    notes.push({ line: i + 2 - body.length, kind: note[1], text: body.join('\n'), under: trail.filter(Boolean).slice(1).join(' › ') });
  }
  notes.forEach((n, k) => {
    if (n.kind !== 'Q') return;
    let j = k + 1;
    while (notes[j] && notes[j].kind !== 'A' && notes[j].kind !== 'Q') j++;
    n.answered = notes[j]?.kind === 'A';
  });
  return notes;
}

function ls(args) {
  const words = args.map((w) => w.toLowerCase());
  for (const { path, mtime } of docs()) {
    const rel = relative(root, path);
    if (!words.every((w) => rel.toLowerCase().includes(w))) continue;
    const open = notesOf(path).filter((n) => n.kind === 'Q' && !n.answered).length;
    const day = new Date(mtime).toLocaleDateString('sv-SE');
    console.log(`${day}  ${rel}${open ? `  (${open} open Q)` : ''}`);
  }
}

function notes(args) {
  const file = pick(args);
  const onlyOpen = args.includes('--open');
  const list = notesOf(file).filter((n) => !onlyOpen || (n.kind === 'Q' && !n.answered));
  console.log(shown(file));
  if (!list.length) return console.log(onlyOpen ? '  no open questions' : '  no notes');
  for (const n of list) {
    const flag = n.kind === 'Q' ? (n.answered ? ' (answered)' : ' (open)') : '';
    console.log(`\nL${n.line} ${n.kind}${flag}${n.under ? ` · ${n.under}` : ''}`);
    console.log(n.text.replace(/^/gm, '  '));
  }
}

// One server per file: a running one is reused, its port kept in the temp dir.
async function open(args) {
  const file = pick(args);
  const state = join(tmpdir(), 'lunna-doc');
  mkdirSync(state, { recursive: true });
  const portFile = join(state, createHash('sha1').update(file).digest('hex').slice(0, 12));
  let port = existsSync(portFile) ? Number(readFileSync(portFile, 'utf8')) : 0;
  if (!port || !(await serves(port, file))) {
    port = await freePort();
    const child = spawn(process.execPath, [join(here, 'annotate.mjs'), file, String(port)], {
      detached: true,
      stdio: 'ignore',
    });
    child.unref();
    writeFileSync(portFile, String(port));
    for (let i = 0; i < 40 && !(await serves(port, file)); i++) await new Promise((r) => setTimeout(r, 100));
  }
  const url = `http://localhost:${port}`;
  console.log(`${shown(file)} → ${url}`);
  if (!args.includes('--no-browser')) execFileSync(process.platform === 'darwin' ? 'open' : 'xdg-open', [url]);
}

async function serves(port, file) {
  try {
    const res = await fetch(`http://127.0.0.1:${port}/doc`, { signal: AbortSignal.timeout(500) });
    return (await res.json()).path === file;
  } catch {
    return false;
  }
}

function freePort() {
  return new Promise((done) => {
    const probe = createServer().listen(0, '127.0.0.1', () => {
      const { port } = probe.address();
      probe.close(() => done(port));
    });
  });
}

function shown(path) {
  const rel = relative(root, path);
  return rel.startsWith('..') ? path : rel;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

const [command, ...args] = process.argv.slice(2);
const commands = { ls, open, notes };
if (!commands[command]) fail('usage: .tool/doc ls [words] | open [file|words] [--no-browser] | notes [file|words] [--open]');
await commands[command](args);
