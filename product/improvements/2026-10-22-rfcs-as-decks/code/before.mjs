// The RFC page as it was before this change: the old annotate page (git's
// HEAD~ version of .tool/annotate.mjs) on the PostHog RFC, phone width, dark.
//   node code/before.mjs <path to old annotate.mjs> <out dir>
import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { capture } from '../../../../.tool/shot.mjs';

const [annotate, out] = process.argv.slice(2);
const rfc = resolve(import.meta.dirname, '../../../research/2026-10-21-posthog/README.md');
const server = spawn(process.execPath, [annotate, rfc, '4399'], { stdio: 'ignore' });
await new Promise((r) => setTimeout(r, 800));
try {
  const { files } = await capture('http://127.0.0.1:4399/', { selector: 'main', out, maxHeight: 1500, ready: "document.querySelectorAll('.block').length > 3" });
  console.log(files.join('\n'));
} finally {
  server.kill();
}
