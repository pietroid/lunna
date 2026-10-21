// Drives .tool/review.html in headless Chrome as a 390×844 phone, on a real
// PR, and saves what it shows: the page, a selection with its button, the
// composer, a draft ready to send, and how an answered thread looks. Sends
// nothing. Node ≥ 22 (WebSocket), Chrome at its usual macOS path.
//
//   node product/improvements/2026-10-21-github-review-and-rfc-shape/code/review-shots.mjs <pr> <path> <out-dir>
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [pr, path, out] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const html = readFileSync(new URL('../../../../.tool/review.html', import.meta.url));
const server = createServer((_, res) => res.writeHead(200, { 'content-type': 'text/html' }).end(html)).listen(8765);
const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  ['--headless=new', '--remote-debugging-port=9333', `--user-data-dir=${mkdtempSync(join(tmpdir(), 'review-'))}`, 'about:blank'], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let target;
for (let i = 0; i < 50 && !target; i++) {
  await sleep(200);
  target = await fetch('http://127.0.0.1:9333/json/new?about:blank', { method: 'PUT' }).then((r) => r.json()).catch(() => null);
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let seq = 0;
const waiting = new Map();
ws.onmessage = (m) => { const d = JSON.parse(m.data); waiting.get(d.id)?.(d); };
const cdp = (method, params = {}) => new Promise((resolve, reject) => {
  const id = ++seq;
  waiting.set(id, (d) => (d.error ? reject(new Error(d.error.message)) : resolve(d.result)));
  ws.send(JSON.stringify({ id, method, params }));
});
const run = async (expression) => (await cdp('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })).result.value;
const shot = async (name) => {
  const { data } = await cdp('Page.captureScreenshot', { format: 'png' });
  writeFileSync(join(out, name), Buffer.from(data, 'base64'));
  console.log(`✓ ${join(out, name)}`);
};

try {
  await cdp('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
  await cdp('Page.navigate', { url: `http://localhost:8765/review.html?repo=pietroid/lunna&pr=${pr}&path=${encodeURI(path)}` });
  for (let i = 0; i < 40 && !(await run('document.querySelectorAll(".block").length')); i++) await sleep(250);
  await sleep(1500); // the font and the pictures
  console.log(`  ${await run('document.querySelectorAll(".block").length')} blocks, ${await run('document.querySelectorAll(".block img").length')} pictures, title “${await run('document.title')}”`);
  await shot('review-1-page.png');

  // Select a sentence of a list item, as a long press would.
  const quote = 'Line comments need nothing new to host';
  console.log('  ' + await run(`(() => {
    const walker = document.createTreeWalker(document.getElementById('doc'), NodeFilter.SHOW_TEXT);
    let n; while ((n = walker.nextNode()) && !n.data.includes(${JSON.stringify(quote)}));
    if (!n) return 'not found';
    const at = n.data.indexOf(${JSON.stringify(quote)});
    const r = document.createRange(); r.setStart(n, at); r.setEnd(n, at + ${quote.length});
    getSelection().removeAllRanges(); getSelection().addRange(r);
    n.parentElement.scrollIntoView({ block: 'center' });
    return 'selected in block ' + n.parentElement.closest('.block').dataset.i;
  })()`));
  await sleep(300);
  console.log(`  selection button ${await run('document.getElementById("quote").hidden') ? 'hidden ✗' : 'shown ✓'}`);
  await shot('review-2-selection.png');

  await run(`document.getElementById('quote').click()`);
  await run(`(() => { const a = document.querySelector('.composer textarea'); a.value = 'Why does hosting a copy make mapping comments hard? Show a real case.'; a.dispatchEvent(new Event('input')); })()`);
  await run(`[...document.querySelectorAll('.kinds .pill')].find((b) => b.textContent === 'Learn').click()`);
  await run(`(() => { const a = document.querySelector('.composer textarea'); a.value = 'Why does hosting a copy make mapping comments hard? Show a real case.'; a.dispatchEvent(new Event('input')); document.querySelector('.composer').scrollIntoView({ block: 'center' }); })()`);
  await shot('review-3-composer.png');

  await run(`[...document.querySelectorAll('.composer .pill')].find((b) => b.textContent === 'Add').click()`);
  console.log(`  draft: ${await run('JSON.stringify(drafts.map(({ kind, start, end }) => ({ kind, start, end })))')}, button “${await run('document.getElementById("send").textContent')}”`);
  console.log(`  review it would send: ${await run('JSON.stringify(reviewOf(drafts, path, head.sha).comments)')}`);
  await run(`document.querySelector('.draft').scrollIntoView({ block: 'center' })`);
  await shot('review-4-draft.png');

  // How an answer reads: a thread as GitHub returns it (made up here).
  await run(`(() => {
    const d = drafts[0];
    threads = threadsOf([
      { id: 1, path, line: d.end, user: { login: 'pietroid' }, created_at: new Date().toISOString(), body: 'Learn: why is mapping hard? Show a real case.\\n\\n> ' + d.quote },
      { id: 2, in_reply_to_id: 1, path, line: d.end, user: { login: 'pietroid' }, created_at: new Date().toISOString(), body: 'A copy on another site keeps its own text: once the RFC changes, a comment there points at a sentence that may be gone. A line comment stays on the PR\\'s file, and GitHub moves it or marks it outdated.' },
    ], path, blocks);
    drafts = []; render();
    document.querySelector('.thread').scrollIntoView({ block: 'center' });
  })()`);
  await shot('review-5-thread.png');
} finally {
  ws.close();
  chrome.kill();
  server.close();
}
