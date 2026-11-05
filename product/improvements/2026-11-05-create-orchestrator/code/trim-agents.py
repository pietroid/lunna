#!/usr/bin/env python3
"""Moves sections of AGENTS.md, verbatim, into product/spec/ and leaves a
pointer in their place. Each section's own text (up to the next heading of
any level) moves; its subsections stay. Usage, from the repo root:
  python3 product/improvements/2026-11-05-create-orchestrator/code/trim-agents.py <pointers.json>
"""
import json, os, re, sys

pointers = json.load(open(sys.argv[1]))
lines = open('AGENTS.md').read().split('\n')
heads = [i for i, l in enumerate(lines) if l.startswith('#') and not l.startswith('#!')]
# Code blocks hold "# Server"-style comments: ignore headings inside fences.
fence, real = False, []
for i, l in enumerate(lines):
    if l.startswith('```'): fence = not fence
    elif i in heads and not fence: real.append(i)

out, moved, i = [], {}, 0
while i < len(lines):
    if i in real and lines[i] in pointers:
        nxt = next((j for j in real if j > i), len(lines))
        body = '\n'.join(lines[i + 1:nxt]).strip('\n')
        p = pointers[lines[i]]
        moved[lines[i]] = (p, body)
        out += [lines[i], '', p['pointer'], '']
        i = nxt
        continue
    out.append(lines[i]); i += 1

missing = set(pointers) - set(moved)
if missing: sys.exit(f'not found: {missing}')
before = sum(len(l) + 1 for l in lines)
open('AGENTS.md', 'w').write('\n'.join(out))
for head, (p, body) in moved.items():
    path, new = p['to'], not os.path.exists(p['to'])
    # Links in AGENTS.md are relative to the root; the spec lives two levels down.
    def rel(m):
        t = m.group(1)
        return '](' + ('./' + t[13:] if t.startswith('product/spec/') else '../' + t[8:] if t.startswith('product/') else '../../' + t)
    body = re.sub(r'\]\(\./([^)]+)', rel, body)
    with open(path, 'a') as f:
        f.write(('' if new else '\n\n') + p['title'] + '\n\n' + body + '\n')
    print(f"{'new ' if new else '+   '}{path}  ({len(body)} chars from {head})")
print(f'AGENTS.md: {before} → {sum(len(l) + 1 for l in out)} chars')
