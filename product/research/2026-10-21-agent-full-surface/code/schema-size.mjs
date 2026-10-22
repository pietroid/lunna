// How big is what the model is given, and how does it grow with new verbs?
//
// Loads SYSTEM_PROMPT and TOOLS from server/src/agent/agent.prompt.ts (Node
// strips the types), measures them, and projects the `answer` schema with
// the gesture kinds and arguments this RFC adds. Tokens are estimated as
// characters / 4, which is close for English JSON; a real tokenizer differs
// by a few percent.
//
//   node code/schema-size.mjs        (from this folder, Node >= 23.6)

import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const here = fileURLToPath(new URL('..', import.meta.url));
const source = readFileSync(
  join(here, '../../../server/src/agent/agent.prompt.ts'),
  'utf8',
).replace(/^import .*$/m, '');
const file = join(mkdtempSync(join(tmpdir(), 'schema-')), 'prompt.ts');
writeFileSync(file, source);
const { SYSTEM_PROMPT, TOOLS } = await import(file);

const tokens = (value) =>
  Math.round((typeof value === 'string' ? value : JSON.stringify(value)).length / 4);

const answer = TOOLS.find((it) => it.function.name === 'answer');
const item = answer.function.parameters.properties.blocks.items;
const change = item.properties.changes.items;
const props = Object.keys(change.properties);
const perProp = tokens(change.properties) / props.length;
// CHANGES is written into the schema twice: the plan's and each choice's.
const copies = JSON.stringify(answer).split('"enum":["place"').length - 1;

// What this RFC adds to a change, beyond today's arguments (§4–§6).
const NEW_KINDS = [
  'new_artifact', 'edit_artifact', 'deliver', 'remove_artifact', 'move_artifact',
  'new_kind', 'new_goal', 'remove_goal',
  'edit', 'done', 'remove', 'start', 'snooze', 'pause', 'resume', 'extend',
  'edit_event', 'done_event', 'remove_event', 'pause_event', 'extend_event',
  'new_routine', 'edit_routine', 'remove_routine', 'day_off', 'work_day',
];
const NEW_ARGS = [
  'title', 'kind', 'deadline', 'value', 'blocks', 'open', 'as', 'artifact',
  'name', 'shelf', 'price', 'amount', 'period', 'rule', 'start', 'end',
];

const kindsNow = change.properties.do.enum.length;
const rows = [
  ['system prompt', tokens(SYSTEM_PROMPT)],
  ['4 tools', tokens(TOOLS)],
  ['  of which answer', tokens(answer)],
  ['  one change item (copies: ' + copies + ')', tokens(change)],
];
const grown =
  tokens(answer) +
  copies * (NEW_ARGS.length * perProp + NEW_KINDS.length * 3);

console.log(`gesture kinds today: ${kindsNow}, arguments: ${props.length}`);
for (const [name, n] of rows) console.log(`${name.padEnd(52)} ~${n} tokens`);
console.log(
  `answer with ${kindsNow + NEW_KINDS.length} kinds, ${props.length + NEW_ARGS.length} arguments (flat)`.padEnd(52) +
    ` ~${Math.round(grown)} tokens`,
);
console.log(
  `whole prefix, grown`.padEnd(52) +
    ` ~${Math.round(tokens(SYSTEM_PROMPT) + tokens(TOOLS) - tokens(answer) + grown)} tokens`,
);
