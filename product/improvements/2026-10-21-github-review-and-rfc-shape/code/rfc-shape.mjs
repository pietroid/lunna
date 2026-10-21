#!/usr/bin/env node
// How long each RFC is, and how much of it comes before the reader learns
// what to do. Run from the repo root:
//
//   node product/improvements/2026-10-21-github-review-and-rfc-shape/code/rfc-shape.mjs [extra.md…]
//
// Words are counted outside code fences. "To first action" is the words
// before the first heading that names recommendations (or the TL;DR's end
// in the new shape). Minutes at 200 words a minute, a phone's pace.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const dir = 'product/research';
const files = [
  ...readdirSync(dir).map((d) => join(dir, d, 'README.md')).filter(existsSync),
  ...process.argv.slice(2),
];

const words = (s) => s.split(/\s+/).filter(Boolean).length;
const rows = files.map((f) => {
  const lines = readFileSync(f, 'utf8').split('\n');
  let fence = false, total = 0, before = null, notes = 0, refs = 0, sections = 0;
  for (const line of lines) {
    if (/^\s*(```|~~~)/.test(line)) { fence = !fence; continue; }
    if (fence) continue;
    if (/^## /.test(line)) sections++;
    if (before === null && /^##+ .*(recommend|what to do|the change)/i.test(line)) before = total;
    if (/^> \*\*(Q|A|Learn|Decision|Note)\b/.test(line)) notes++;
    if (/^\s*(\d+\.|-) .*https?:\/\//.test(line)) refs++;
    total += words(line);
  }
  return { f: f.replace(/^product\/research\//, '').replace(/\/README\.md$/, ''), total, before: before ?? total, sections, refs, notes };
});

const min = (w) => (w / 200).toFixed(0);
console.log('| RFC | Words | Minutes | Words before what to do | Minutes | Sections | Links in lists | Notes |');
console.log('|---|---|---|---|---|---|---|---|');
for (const r of rows) console.log(`| ${r.f} | ${r.total} | ${min(r.total)} | ${r.before} | ${min(r.before)} | ${r.sections} | ${r.refs} | ${r.notes} |`);
