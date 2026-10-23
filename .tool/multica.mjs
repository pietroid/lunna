#!/usr/bin/env node
// Multica on the Mac, beside the GitHub queue: the commands of the setup in
// product/research/2026-10-21-multica-on-the-mac (the RFC), and the checks it
// left for the install.
//
//   .tool/multica steps                 the setup list, in order, with the host filled in
//   .tool/multica env [--dry-run]       write ~/multica/.env from its .env.example (step 2)
//   .tool/multica daemon [--dry-run]    configure and start the daemon as user multica (step 7, after a reboot)
//   .tool/multica check                 one ✓/✗ line per thing the setup needs, with the step that fixes it
//   .tool/multica score <issue> <github|multica> [--dry-run]   a row of the scorecard (Phase 1)
//   .tool/multica down [--yes]          tear it all down (Phase 2, if GitHub wins); prints unless --yes
//
// Nothing here holds a secret: the Gmail app password is typed, JWT_SECRET is
// made on the Mac, and both stay in ~/multica/.env.
import { execFileSync, spawnSync } from 'node:child_process';
import { chmodSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { homedir, userInfo } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const OPTIONS = new Set(['host', 'dir', 'email', 'example', 'asked', 'pr', 'comments', 'rounds']);
const flag = (name) => args.includes(`--${name}`);
const option = (name, fallback) => { const i = args.indexOf(`--${name}`); return i >= 0 && args[i + 1] ? args[i + 1] : fallback; };
const positional = args.filter((a, i) => !a.startsWith('--') && !(i > 0 && args[i - 1].startsWith('--') && OPTIONS.has(args[i - 1].slice(2))));

const HOST = option('host', 'multica.pietroteruya.dev');
const DIR = option('dir', join(homedir(), 'multica'));
const COMPOSE = ['compose', '-f', join(DIR, 'docker-compose.selfhost.yml')];
const TAG = 'v0.6.5';
const USER = 'multica';
const AGENT = 'lunna-mac';
const SCORECARD = join(root, 'product/research/2026-10-21-multica-on-the-mac/data/scorecard.md');
// What the queue and the Multica agent append to the GitHub comments they post as you.
const MARKS = ['<!-- lunna-queue -->', '<!-- multica -->'];

const sh = (cmd, a, opts = {}) =>
  execFileSync(cmd, a, { cwd: root, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], maxBuffer: 64 << 20, ...opts }).trim();
const trySh = (...a) => { try { return sh(...a); } catch { return null; } };
const ghJson = (a) => JSON.parse(sh('gh', a));
const me = () => userInfo().username;
const ok = (line) => console.log(`✓ ${line}`);
const bad = (line, fix) => { console.log(`✗ ${line}${fix ? `\n    → ${fix}` : ''}`); process.exitCode = 1; };
const info = (line) => console.log(`· ${line}`);

// The RFC's step 2, as KEY → value. Every other line of .env.example stays as it is.
function envValues(email) {
  const origin = `https://${HOST}`;
  return {
    MULTICA_IMAGE_TAG: TAG,
    DO_NOT_TRACK: '1',
    APP_ENV: '', // compose reads empty as production, which ignores the dev code below
    MULTICA_DEV_VERIFICATION_CODE: '', // a fixed code on a public URL is an open door
    FRONTEND_ORIGIN: origin,
    CORS_ALLOWED_ORIGINS: origin,
    MULTICA_PUBLIC_URL: origin,
    MULTICA_TRUSTED_PROXIES: '127.0.0.1/32',
    ALLOW_SIGNUP: 'false',
    ALLOWED_EMAILS: email,
    SMTP_HOST: 'smtp.gmail.com',
    SMTP_PORT: '587',
    SMTP_USERNAME: email,
    SMTP_FROM_EMAIL: email,
  };
}

const parseEnv = (text) => Object.fromEntries(text.split('\n').map((l) => l.match(/^([A-Z0-9_]+)=(.*)$/)).filter(Boolean).map((m) => [m[1], m[2]]));

// Sets each key on its own line (KEY=…) where the file has one, else at the end.
function setEnv(text, values) {
  const left = new Map(Object.entries(values));
  const lines = text.split('\n').map((l) => {
    const m = l.match(/^([A-Z0-9_]+)=/);
    if (!m || !left.has(m[1])) return l;
    const line = `${m[1]}=${left.get(m[1])}`;
    left.delete(m[1]);
    return line;
  });
  if (left.size) lines.push('', '# Set by .tool/multica env', ...[...left].map(([k, v]) => `${k}=${v}`), '');
  return lines.join('\n');
}

async function askHidden(prompt) {
  if (!process.stdin.isTTY) return (readFileSync(0, 'utf8').split('\n')[0] ?? '').trim();
  process.stdout.write(prompt);
  process.stdin.setRawMode(true);
  process.stdin.resume();
  let typed = '';
  for await (const chunk of process.stdin) {
    for (const ch of chunk.toString('utf8')) {
      if (ch === '\r' || ch === '\n') { process.stdin.setRawMode(false); process.stdin.pause(); process.stdout.write('\n'); return typed.replace(/\s+/g, ''); }
      if (ch === '\u0003') { process.stdout.write('\n'); process.exit(130); }
      if (ch === '\u007f') typed = typed.slice(0, -1); else typed += ch;
    }
  }
  return typed.replace(/\s+/g, '');
}

async function env() {
  const example = option('example', join(DIR, '.env.example'));
  const target = join(DIR, '.env');
  if (!existsSync(example)) return bad(`no ${example}`, `step 2: git clone https://github.com/multica-ai/multica.git ${DIR}`);
  const email = option('email', trySh('git', ['config', 'user.email']));
  if (!email) return bad('no email', 'pass --email you@gmail.com (it signs in, receives the codes and sends them)');
  const exampleText = readFileSync(example, 'utf8');
  const had = existsSync(target) ? readFileSync(target, 'utf8') : null;
  const old = had ? parseEnv(had) : {};
  const values = envValues(email);
  // JWT_SECRET signs every session: one already there is never replaced.
  values.JWT_SECRET = old.JWT_SECRET || randomBytes(32).toString('hex');
  const missing = Object.keys(values).filter((k) => !new RegExp(`^#? ?${k}=`, 'm').test(exampleText));
  let password = old.SMTP_PASSWORD;
  if (!password && !flag('dry-run')) password = await askHidden('Gmail app password (Google Account → Security → App passwords): ');
  values.SMTP_PASSWORD = password ?? '';
  const text = setEnv(had ?? exampleText, values);
  if (flag('dry-run')) {
    const shown = { ...values, JWT_SECRET: old.JWT_SECRET ? '(kept)' : '(new, 64 hex)', SMTP_PASSWORD: password ? '(kept)' : '(asked when run)' };
    console.log(`${target} would get, on top of ${had ? 'what it has' : '.env.example'}:`);
    for (const [k, v] of Object.entries(shown)) console.log(`  ${k}=${v}`);
  } else {
    writeFileSync(target, text, { mode: 0o600 });
    chmodSync(target, 0o600);
    ok(`${target} written (0600), ${had ? 'its JWT_SECRET kept' : 'a new JWT_SECRET'}${old.JWT_SECRET ? '' : ': keep a copy, a moved server needs the same one'}`);
    if (!password) bad('no SMTP_PASSWORD: the codes only reach the backend log', 'run .tool/multica env again on a terminal');
  }
  if (missing.length) info(`not in this version's .env.example, appended at the end: ${missing.join(', ')}`);
  info(`then: docker ${COMPOSE.join(' ')} up -d`);
}

// As user multica: from your account each command goes through sudo -iu multica.
function asAgent(cmd) {
  return me() === USER ? ['sh', ['-lc', cmd]] : ['sudo', ['-iu', USER, 'sh', '-lc', cmd]];
}

function daemon() {
  const cmds = [
    'multica config set server_url http://localhost:8080',
    `multica config set app_url https://${HOST}`,
    'MULTICA_DAEMON_MAX_CONCURRENT_TASKS=1 multica daemon start',
    'multica daemon status',
  ];
  for (const c of cmds) {
    const [bin, a] = asAgent(c);
    if (flag('dry-run')) { console.log(`  ${bin} ${a.map((x) => (/\s/.test(x) ? `'${x}'` : x)).join(' ')}`); continue; }
    const r = spawnSync(bin, a, { stdio: 'inherit' });
    if (r.status !== 0) return bad(c, r.error?.code === 'ENOENT' ? `${bin} not found` : `step 6–7: is user ${USER} there, with multica installed and logged in (multica login --token)?`);
  }
  if (!flag('dry-run')) info('the daemon is in the background; close this shell and run .tool/multica check to see it stayed');
}

async function probe(url, opts = {}) {
  try {
    const res = await fetch(url, { redirect: 'manual', signal: AbortSignal.timeout(8000), ...opts });
    return { status: res.status, type: res.headers.get('content-type') ?? '', body: await res.text() };
  } catch (e) {
    return { status: 0, body: '', error: e.cause?.code ?? e.name };
  }
}
const said = (r) => (r.status ? `${r.status}` : r.error);

async function check() {
  // The stack (step 2).
  const ps = trySh('docker', [...COMPOSE, 'ps', '--format', 'json']);
  if (ps === null) bad('docker compose: no stack', existsSync(DIR) ? `step 2: docker ${COMPOSE.join(' ')} up -d (is OrbStack open?)` : `steps 1–2: OrbStack, then clone Multica into ${DIR}`);
  else {
    const rows = ps.split('\n').filter(Boolean).flatMap((l) => { const j = JSON.parse(l); return Array.isArray(j) ? j : [j]; });
    const up = rows.filter((c) => c.State === 'running').map((c) => c.Service);
    const down = ['postgres', 'backend', 'frontend'].filter((s) => !up.includes(s));
    if (down.length) bad(`containers not running: ${down.join(', ')}`, `step 2: docker ${COMPOSE.join(' ')} up -d`); else ok(`containers up: ${up.join(', ')}`);
  }

  // The .env (step 2): the lock on the door.
  const envPath = join(DIR, '.env');
  if (!existsSync(envPath)) bad(`no ${envPath}`, '.tool/multica env');
  else {
    const e = parseEnv(readFileSync(envPath, 'utf8'));
    const wrong = [
      !e.JWT_SECRET && 'JWT_SECRET empty',
      e.ALLOW_SIGNUP !== 'false' && 'ALLOW_SIGNUP is not false',
      !e.ALLOWED_EMAILS && 'ALLOWED_EMAILS empty',
      e.MULTICA_DEV_VERIFICATION_CODE && 'MULTICA_DEV_VERIFICATION_CODE set',
      e.APP_ENV && e.APP_ENV !== 'production' && `APP_ENV=${e.APP_ENV}`,
      !e.SMTP_PASSWORD && 'SMTP_PASSWORD empty (codes only in the log)',
      e.MULTICA_IMAGE_TAG !== TAG && `MULTICA_IMAGE_TAG=${e.MULTICA_IMAGE_TAG ?? '(unset)'}, not ${TAG}`,
      e.CORS_ALLOWED_ORIGINS !== `https://${HOST}` && 'CORS_ALLOWED_ORIGINS is not the public origin (the websocket gets 403)',
    ].filter(Boolean);
    if (wrong.length) bad(`.env: ${wrong.join('; ')}`, '.tool/multica env, then docker compose up -d'); else ok(`.env: sign-up off, only ${e.ALLOWED_EMAILS}, codes by ${e.SMTP_HOST}, ${TAG}`);
  }

  // The two halves on the Mac.
  const health = await probe('http://localhost:8080/healthz');
  if (health.status === 200 && /"status"\s*:\s*"ok"/.test(health.body)) ok('backend answers localhost:8080/healthz');
  else bad(`backend localhost:8080/healthz: ${said(health)} ${health.body.slice(0, 80)}`, 'step 2: docker compose logs backend');
  const web = await probe('http://localhost:3000/');
  if (web.status >= 200 && web.status < 400) ok('web app answers localhost:3000'); else bad(`web app localhost:3000: ${said(web)}`, 'step 2: docker compose logs frontend');

  // Through the tunnel (step 3). A bare /ws reaching the Go backend says it
  // wants a workspace; one that fell to Next is its 404 page.
  if (trySh('pgrep', ['-x', 'cloudflared'])) ok('cloudflared is running'); else bad('cloudflared is not running', 'step 3: sudo cloudflared service install <token>');
  const pub = await probe(`https://${HOST}/`);
  if (pub.status >= 200 && pub.status < 400 && /html/.test(pub.type)) ok(`https://${HOST}/ is the web app`); else bad(`https://${HOST}/: ${said(pub)}`, 'step 3: the hostname with an empty path → http://localhost:3000');
  const ws = await probe(`https://${HOST}/ws`);
  if (/workspace_id or workspace_slug/.test(ws.body)) ok(`https://${HOST}/ws reaches the backend`);
  else bad(`https://${HOST}/ws: ${said(ws)}${ws.status ? `, ${/html/.test(ws.type) ? 'the web app answered' : ws.body.slice(0, 60)}` : ''}`, 'step 3: the row with path ^/ws(/.*)?$ → http://localhost:8080, above the other one');

  // The daemon (step 7): as multica, never as you, and alive with no shell of its user open.
  const procs = (user) => (trySh('ps', ['-U', user, '-o', 'pid=,rss=,command=']) ?? '').split('\n').filter(Boolean);
  const isDaemon = (l) => /\bmultica\b.*\bdaemon\b/.test(l) && !/\b(status|stop|logs)\b/.test(l);
  const daemons = procs(USER).filter(isDaemon);
  const shells = procs(USER).filter((l) => /^\s*\d+\s+\d+\s+-?(zsh|bash|sh|login)\b/.test(l));
  if (!daemons.length) bad(`no daemon running as ${USER}`, `step 7 (or after a reboot): .tool/multica daemon`);
  else if (shells.length) ok(`daemon runs as ${USER}, but a shell of ${USER} is open: close it and check again to see it stays`);
  else ok(`daemon runs as ${USER} with no shell of it open`);
  const mine = procs(me()).filter(isDaemon);
  if (me() !== USER && mine.length) bad(`a daemon runs as ${me()}: its runs can read your keys and files`, 'multica daemon stop, as you');

  // What it costs in memory on the Air.
  const stats = trySh('docker', ['stats', '--no-stream', '--format', '{{.Name}}\t{{.MemUsage}}']);
  const rss = daemons.reduce((n, l) => n + Number(l.trim().split(/\s+/)[1] || 0), 0);
  if (stats) info(`memory: ${stats.split('\n').map((l) => l.replace(/\t/, ' ').replace(/ \/ .*/, '')).join(', ')}; daemon ${(rss / 1024).toFixed(0)} MiB`);

  // Who has an account, and who asked for a code (the backend log, two weeks).
  if (ps !== null && existsSync(envPath)) {
    const e = parseEnv(readFileSync(envPath, 'utf8'));
    const allowed = (e.ALLOWED_EMAILS ?? '').toLowerCase().split(',').map((s) => s.trim()).filter(Boolean);
    const sender = [e.SMTP_USERNAME, e.SMTP_FROM_EMAIL].map((s) => (s ?? '').toLowerCase());
    const users = trySh('docker', [...COMPOSE, 'exec', '-T', 'postgres', 'psql', '-U', 'multica', '-d', 'multica', '-tAc', 'select email from "user"']);
    if (users === null) bad('could not read the user table', 'docker compose logs postgres');
    else {
      const others = users.split('\n').map((s) => s.trim().toLowerCase()).filter((s) => s && !allowed.includes(s));
      if (others.length) bad(`accounts that are not you: ${others.join(', ')}`, 'look at how they got in, then delete them'); else ok(`accounts: only ${allowed.join(', ')}`);
    }
    const log = trySh('docker', [...COMPOSE, 'logs', 'backend', '--since', '336h', '--no-log-prefix']) ?? '';
    const asked = [...new Set((log.match(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g) ?? []).map((s) => s.toLowerCase()))].filter((s) => !allowed.includes(s) && !sender.includes(s));
    if (asked.length) bad(`other addresses in the backend log: ${asked.join(', ')}`, `docker ${COMPOSE.join(' ')} logs backend | grep -i <address>`); else ok('backend log, two weeks: no address but yours');
  }
}

function steps() {
  const o = `https://${HOST}`;
  console.log(`Multica on the Mac, the setup list (RFC: product/research/2026-10-21-multica-on-the-mac).
you$ is your account; multica$ is the agent's (sudo -iu ${USER}).

 1. you$ brew install --cask orbstack && brew install cloudflared      (open OrbStack once)
 2. you$ git clone https://github.com/multica-ai/multica.git ${DIR} && cd ${DIR} && git checkout ${TAG}
    you$ .tool/multica env                                               (from the lunna repo; asks the Gmail app password)
    you$ docker ${COMPOSE.join(' ')} up -d
 3. Cloudflare → Zero Trust → Networks → Tunnels → Create, Cloudflared, name it "mac"
    you$ sudo cloudflared service install <token>
    Public hostnames, in this order:  ${HOST}  path ^/ws(/.*)?$ → http://localhost:8080
                                      ${HOST}  (no path)        → http://localhost:3000
 4. ${o}: sign in with the code, create the workspace and a project "Lunna",
    Settings → API Token: a token for the daemon (mul_…)
 5. you$ sudo sysadminctl -addUser ${USER} -fullName "Multica agent" -password '<pick one>'
 6. multica$ curl -fsSL https://claude.ai/install.sh | bash             (then claude, /login)
    multica$ gh auth login && gh auth setup-git                          (a fine-grained token: pietroid/lunna, Contents + Pull requests)
    multica$ git config --global user.name "Multica agent"; git config --global user.email "<your noreply address>"
    multica$ flutter and npm on PATH
 7. multica$ brew install multica-ai/tap/multica && multica login --token
    you$ .tool/multica daemon                                            (again after every reboot)
 8. ${o} → Settings → Runtimes: the Mac, as ${USER}
    Settings → Code: https://github.com/pietroid/lunna.git, added to project Lunna
    Settings → Agents: "${AGENT}" on the Mac's runtime, Claude Code, concurrency 1,
    instructions: .tool/multica-agent.md, below its ---
 9. you$ cd ${DIR} && pnpm install
    you$ printf 'EXPO_PUBLIC_API_URL=${o}\\nEXPO_PUBLIC_WEB_URL=${o}\\n' > apps/mobile/.env.production.local
    you$ EXPO_BUNDLE_IDENTIFIER_PROD=dev.pietroteruya.multica pnpm ios:mobile:device:prod:release
    (Xcode signed in, Developer Mode on; again every 7 days)
10. you$ .tool/multica check
    Then a Multica issue assigned to ${AGENT}, answered from the phone. GitHub issues stay with the queue.`);
}

// Phase 1: one row per issue. GitHub fills the hours and your comments on it;
// a Multica issue's own comments live in Multica and are added by hand.
function score() {
  const [issue, queue] = positional.slice(1);
  if (!issue || !['github', 'multica'].includes(queue)) return bad('usage: .tool/multica score <issue> <github|multica> [--pr N] [--asked ISO] [--comments N] [--rounds N] [--dry-run]');
  const repo = ghJson(['repo', 'view', '--json', 'nameWithOwner,owner']);
  const owner = repo.owner.login;
  let pr = option('pr');
  if (!pr) {
    const prs = ghJson(['pr', 'list', '-R', repo.nameWithOwner, '--state', 'all', '--limit', '200', '--json', 'number,headRefName']);
    const hit = queue === 'github'
      ? prs.find((p) => p.headRefName.startsWith(`queue/${issue}-`))
      : prs.find((p) => p.headRefName.startsWith('agent/') && p.headRefName.toLowerCase().includes(issue.toLowerCase()));
    if (!hit) return bad(`no PR for ${queue} issue ${issue}`, 'pass --pr N');
    pr = String(hit.number);
  }
  let asked = option('asked');
  if (!asked && queue === 'github') asked = ghJson(['issue', 'view', issue, '-R', repo.nameWithOwner, '--json', 'createdAt']).createdAt;
  if (!asked) { const j = trySh('multica', ['issue', 'get', issue, '--output', 'json']); asked = j && (JSON.parse(j).created_at ?? JSON.parse(j).createdAt); }
  if (!asked) return bad(`when was ${issue} asked?`, 'pass --asked 2026-10-23T09:00 (the multica CLI is not on this PATH)');

  // Ready for review is when the work is handed over: the queue's PR is a
  // draft from its design gate on, Multica's opens at the end.
  const view = ghJson(['pr', 'view', pr, '-R', repo.nameWithOwner, '--json', 'createdAt,isDraft,mergedAt']);
  const timeline = ghJson(['api', '--paginate', '--slurp', `repos/${repo.nameWithOwner}/issues/${pr}/timeline`]).flat();
  const readyEvent = timeline.find((e) => e.event === 'ready_for_review');
  const ready = readyEvent?.created_at ?? (view.isDraft ? null : view.createdAt);
  const hours = ready ? ((Date.parse(ready) - Date.parse(asked)) / 3600e3).toFixed(1) : '(draft)';

  const yours = (c) => c.user?.login === owner && !MARKS.some((m) => (c.body ?? '').includes(m));
  const talk = [...(queue === 'github' ? [issue] : []), pr].flatMap((n) => ghJson(['api', '--paginate', '--slurp', `repos/${repo.nameWithOwner}/issues/${n}/comments`]).flat()).filter(yours);
  const lines = ghJson(['api', '--paginate', '--slurp', `repos/${repo.nameWithOwner}/pulls/${pr}/comments`]).flat().filter(yours);
  const reviews = ghJson(['api', '--paginate', '--slurp', `repos/${repo.nameWithOwner}/pulls/${pr}/reviews`]).flat().filter((r) => yours(r) && (r.body || lines.some((l) => l.pull_request_review_id === r.id)));
  const comments = talk.length + lines.length + reviews.filter((r) => r.body).length + Number(option('comments', 0));
  const rounds = talk.length + reviews.length + Number(option('rounds', 0));

  const label = queue === 'github' ? `#${issue} → #${pr}` : `${issue} → #${pr}`;
  const row = `| ${label} | ${queue} | ${hours} | ${comments} | ${rounds} | ${view.mergedAt ? '' : '(open)'} |  |`;
  if (flag('dry-run')) return console.log(row);
  const text = readFileSync(SCORECARD, 'utf8').split('\n');
  const last = text.findLastIndex((l) => l.startsWith('|'));
  text.splice(last + 1, 0, row);
  writeFileSync(SCORECARD, text.join('\n'));
  ok(`${row}\n  added to ${SCORECARD.slice(root.length + 1)}: fill "Merged as is?" and "Went wrong"`);
}

function down() {
  const run = [
    ['sudo', ['-iu', USER, 'sh', '-lc', 'multica daemon stop']],
    ['docker', [...COMPOSE, 'down']],
    ['sudo', ['cloudflared', 'service', 'uninstall']],
    ['sudo', ['sysadminctl', '-deleteUser', USER]],
  ];
  const by = 'by hand: Cloudflare → Tunnels → delete "mac" (and its two hostnames); the app off the iPhone; the Postgres volume stays until docker volume rm';
  if (!flag('yes')) {
    console.log('Phase 2, if GitHub wins. Would run, in order:');
    for (const [b, a] of run) console.log(`  ${b} ${a.map((x) => (/\s/.test(x) ? `'${x}'` : x)).join(' ')}`);
    return console.log(`then ${by}\nRun again with --yes to do it.`);
  }
  for (const [b, a] of run) {
    const r = spawnSync(b, a, { stdio: 'inherit' });
    if (r.status !== 0) return bad(`${b} ${a.join(' ')}`, 'fix it and run down --yes again (each step is safe to repeat)');
  }
  ok(`down. Left ${by}`);
}

const commands = { steps, env, daemon, check, score, down };
const name = positional[0];
if (!commands[name]) {
  console.log(readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n').slice(1).filter((l, i, a) => a.slice(0, i + 1).every((x) => x.startsWith('//'))).map((l) => l.replace(/^\/\/ ?/, '')).join('\n'));
  process.exitCode = name && name !== 'help' && !flag('help') ? 1 : 0;
} else await commands[name]();
