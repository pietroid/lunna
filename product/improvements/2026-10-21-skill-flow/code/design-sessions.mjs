#!/usr/bin/env node
// What each /create design session cost, from the delivery READMEs: the
// first **Total** row after a "Design session" heading or line.
//   node code/design-sessions.mjs            (from this folder, or the repo root)
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const dir = join(root, 'product/delivery');
const rows = [];
for (const d of readdirSync(dir).sort()) {
  const f = join(dir, d, 'README.md');
  if (!existsSync(f)) continue;
  const lines = readFileSync(f, 'utf8').split('\n');
  const at = lines.findIndex((l) => /design session/i.test(l) && !/build session/i.test(l) && /^(#+ |\*\*)?design session/i.test(l.trim()));
  if (at < 0) continue;
  const total = lines.slice(at, at + 20).find((l) => /\*\*Total\*\*/.test(l));
  if (!total) continue;
  const min = total.match(/\*\*(\d+) min\*\*/)?.[1];
  const usd = total.match(/\*\*\$([\d.]+)\*\*/)?.[1];
  const tin = total.match(/\*\*([\d.]+M)\*\*/)?.[1];
  if (min && usd) rows.push({ d, min: +min, usd: +usd, tin });
}
const median = (xs) => { const s = [...xs].sort((a, b) => a - b); const m = s.length >> 1; return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };
console.log('| Delivery | Design session | Tokens in | USD |\n|---|---|---|---|');
for (const r of rows) console.log(`| ${r.d} | ${r.min} min | ${r.tin ?? '—'} | $${r.usd.toFixed(2)} |`);
console.log(`| **Median of ${rows.length}** | **${median(rows.map((r) => r.min))} min** | | **$${median(rows.map((r) => r.usd)).toFixed(2)}** |`);
