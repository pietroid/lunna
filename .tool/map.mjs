// The code map: one line per source file with what it declares (Dart
// classes, Nest controllers and their routes, exported TS symbols), grouped by
// package or module. The /create plan reads it once to pin a piece's scope,
// instead of a dozen greps.
//
//   .tool/map                    every file (~25k characters)
//   .tool/map home task card     only files whose path or names match any word
//   .tool/map --files <words>    paths only
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const pathsOnly = args.includes('--files');
const words = args.filter((a) => !a.startsWith('--')).map((w) => w.toLowerCase());

const SKIP = /(^|\/)(gen|generated|build|node_modules|\.dart_tool|test|drizzle)(\/|$)|\.(g|freezed)\.dart$|\.spec\.ts$|\.d\.ts$/;
function* walk(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (SKIP.test(relative(root, p))) continue;
    if (statSync(p).isDirectory()) yield* walk(p);
    else if (/\.(dart|ts)$/.test(name)) yield p;
  }
}

const roots = ['app/lib', ...readdirSync(join(root, 'app/packages')).map((p) => `app/packages/${p}/lib`), 'server/src']
  .filter((r) => { try { return statSync(join(root, r)).isDirectory(); } catch { return false; } });

function names(file, text) {
  if (file.endsWith('.dart')) {
    return [...text.matchAll(/^(?:abstract |final |sealed |base |interface |mixin )*(?:class|mixin|enum|extension(?: type)?) ([A-Z]\w*)/gm)].map((m) => m[1])
      .concat([...text.matchAll(/^(?:Future<[^>]*>|void|Widget|[A-Z]\w*(?:<[^>]*>)?) ([a-z]\w+)\(/gm)].map((m) => `${m[1]}()`));
  }
  const out = [];
  const base = text.match(/@Controller\(['"`]([^'"`]*)/)?.[1];
  for (const m of text.matchAll(/@(Get|Post|Patch|Put|Delete)\((?:['"`]([^'"`]*))?/g)) out.push(`${m[1].toUpperCase()} /${[base, m[2]].filter(Boolean).join('/')}`);
  for (const m of text.matchAll(/^export (?:abstract |default |declare )*(?:class|interface|type|function|const|enum) (\w+)/gm)) out.push(m[1]);
  return out;
}

let shown = 0, chars = 0;
for (const r of roots) {
  const lines = [];
  for (const f of walk(join(root, r))) {
    const rel = relative(join(root, r), f);
    const n = names(f, readFileSync(f, 'utf8'));
    const hay = `${relative(root, f)} ${n.join(' ')}`.toLowerCase();
    if (words.length && !words.some((w) => hay.includes(w))) continue;
    lines.push(pathsOnly || !n.length ? `  ${rel}` : `  ${rel}: ${[...new Set(n)].join(', ')}`);
  }
  if (!lines.length) continue;
  const block = `${r}/\n${lines.join('\n')}`;
  console.log(block);
  shown += lines.length; chars += block.length;
}
if (!shown) console.log(`no file matches ${words.join(' ')}`);
else if (words.length) console.error(`${shown} files, ${chars} characters`);
