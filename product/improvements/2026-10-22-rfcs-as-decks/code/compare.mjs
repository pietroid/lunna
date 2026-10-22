// img/before-after.png: the old page (img/before.png, from code/before.mjs)
// beside a slide of this report as the new page draws it (.tool/doc shot).
//   node code/compare.mjs <after slide png>
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { capture } from '../../../../.tool/shot.mjs';

const here = resolve(import.meta.dirname, '..');
const after = resolve(process.argv[2]);
const img = (file) => `data:image/png;base64,${readFileSync(file).toString('base64')}`;
const col = (label, src) => `<figure style="margin:0;width:340px">
  <figcaption style="font:500 15px Onest,sans-serif;color:#a1a1a1;margin:0 0 10px 4px">${label}</figcaption>
  <div style="height:640px;overflow:hidden;border-radius:14px"><img src="${src}" style="width:340px;display:block"></div></figure>`;
const page = join(here, 'data/.compare.html');
writeFileSync(page, `<!doctype html><link href="https://fonts.googleapis.com/css2?family=Onest:wght@500&display=swap" rel="stylesheet">
<body style="margin:0;background:#000"><div id="c" style="display:flex;gap:20px;padding:20px;width:740px">
${col('Before', img(join(here, 'img/before.png')))}${col('After', img(after))}</div>
<script>document.fonts.ready.then(() => document.body.dataset.ready = 1)</script></body>`);
const { files } = await capture(`file://${page}`, { selector: '#c', out: join(here, 'data/.shots'), width: 740, scale: 2 });
execFileSync('mv', [files[0], join(here, 'img/before-after.png')]);
rmSync(page);
rmSync(join(here, 'data/.shots'), { recursive: true });
console.log('img/before-after.png');
