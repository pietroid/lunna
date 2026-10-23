// A sketch (not the app) of Calendário's day headings carrying the cycle's
// phase and the weekend, at phone width in Lunna's tokens (app_colors.dart):
// img/sketch.png. The real screens come from /create once this is approved.
//
// Today is Friday 23 October 2026, day 2 of a 29-day cycle: the next period
// is due on 20 November (±3 days), ovulation 13 days before it (7 Nov), the
// fertile window the 5 days before that.
//
//   node code/sketch.mjs
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { capture } from '../../../../.tool/shot.mjs';

const here = resolve(import.meta.dirname, '..');
const c = {
  bg: '#FFFFFF', fill: '#F7F3F3', fillStrong: '#EEE7E8', ink: '#1C1517', ink2: '#6F6468',
  ink3: '#A89DA1', accent: '#E2394F', accentSoft: 'rgba(226,57,79,.14)', freeEdge: '#EEE7E8',
};

// One phase chip: the period in Lunna's red, the rest neutral; a forecast
// is drawn as an outline, a logged or certain day filled.
const chip = (text, { period = false, forecast = false } = {}) => {
  const ink = period ? c.accent : c.ink2;
  const style = forecast
    ? `border:1.5px dashed ${period ? c.accent : c.ink3};background:transparent`
    : `background:${period ? c.accentSoft : c.fillStrong}`;
  return `<span style="${style};color:${ink};border-radius:8px;padding:3px 9px;font-size:13px;font-weight:500;white-space:nowrap">${text}</span>`;
};
const heading = (label, chips, { weekend = false } = {}) => `
  <div style="display:flex;align-items:baseline;gap:8px;flex-wrap:wrap;margin:28px 0 8px">
    <span style="font-size:20px;font-weight:500;color:${weekend ? c.ink2 : c.ink}">${label}</span>
    ${weekend ? `<span style="font-size:13px;color:${c.ink3}">fim de semana</span>` : ''}
    <span style="flex:1"></span>${chips}
  </div>`;
const card = (title, hours) => `
  <div style="background:${c.fill};border-radius:14px;padding:12px 16px;margin:4px 0;display:flex;justify-content:space-between">
    <span style="font-size:16px;color:${c.ink}">${title}</span><span style="font-size:13px;color:${c.ink3}">${hours}</span></div>`;
const free = (hours) => `
  <div style="border:1px solid ${c.freeEdge};border-radius:14px;padding:12px 16px;margin:4px 0;color:${c.ink3};font-size:13px">+ &nbsp;${hours}</div>`;
const note = (text) => `<div style="font-size:12px;color:${c.ink3};margin:2px 2px 0">${text}</div>`;

const body = `
  ${heading('Ainda hoje', chip('Menstruação · dia 2', { period: true }))}
  ${card('Revisar proposta', '14:00 – 15:30')}
  ${free('15:35 – 22:00')}
  ${heading('Amanhã', chip('Menstruação · dia 3', { period: true }))}
  ${card('Aula de inglês', '09:00 – 10:00')}
  ${heading('Sábado, 31 de outubro', chip('Folicular'), { weekend: true })}
  ${free('07:00 – 22:00')}
  ${heading('Sexta-feira, 6 de novembro', chip('Fértil · previsto', { forecast: true }))}
  ${card('Entrega do relatório', '10:00 – 12:00')}
  ${heading('Sexta-feira, 20 de novembro', chip('Menstruação · prevista', { period: true, forecast: true }))}
  ${note('entre 17 e 23 de novembro')}
  ${free('07:00 – 22:00')}`;

const html = `<!doctype html><link href="https://fonts.googleapis.com/css2?family=Onest:wght@400;500&display=swap" rel="stylesheet">
<body style="margin:0;background:#0d0d0d"><div id="c" style="width:390px;background:${c.bg};font-family:Onest,sans-serif;padding:4px 20px 24px;box-sizing:border-box">${body}</div>
<script>document.fonts.ready.then(() => document.body.dataset.ready = 1)</script></body>`;
const page = join(here, 'data/.sketch.html');
writeFileSync(page, html);
const { files } = await capture(`file://${page}`, { selector: '#c', out: join(here, 'img'), width: 390, scale: 2 });
execFileSync('mv', [files[0], join(here, 'img/sketch.png')]);
execFileSync('rm', [page]);
console.log('→ img/sketch.png');
