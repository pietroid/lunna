/**
 * What the phone says on a day the person does not open the app.
 *
 * Runs the real `NotificationsService.plan` on a hand-built day (the shape
 * `TimelineService.day` returns), at the moments the phone would sync:
 * once in the morning when the app is opened, then once when the iOS
 * background refresh (asked every 6 h, never guaranteed) wakes it.
 *
 *   cd server && npx tsx ../product/research/2026-10-24-mvp-autonomy/code/silent-day.ts
 *
 * Writes ../data/silent-day.json.
 */
import { writeFileSync } from 'fs';
import { join } from 'path';
import { CalendarEvent } from '../../../../server/src/calendar/calendar.types';
import { Day, TimelineService } from '../../../../server/src/events/timeline.service';
import { NotificationsService } from '../../../../server/src/notifications/notifications.service';
import { Task } from '../../../../server/src/tasks/task.types';
import { DEFAULT_WORK_DAY, Interval } from '../../../../server/src/time/work-hours';

const ZONE = 'America/Sao_Paulo';
/** "HH:MM" on Monday 26/10/2026 in São Paulo (UTC-3). */
const at = (hhmm: string) => new Date(`2026-10-26T${hhmm}:00.000-03:00`);
const hhmm = (iso: string) => iso.slice(11, 16);

function task(id: string, title: string, minutes: number): Task {
  return { id, title, notes: '', minutes, position: 0, backlog: false };
}

const tasks = [
  task('a', 'Mapa astral da Júlia', 60),
  task('b', 'Responder clientes', 45),
  task('c', 'Editar vídeo', 60),
  task('d', 'Revisar tese', 90),
  task('e', 'Mercado', 30),
];
const lunch: CalendarEvent = {
  id: 'lunch',
  title: 'Almoço',
  startTime: at('12:00').toISOString(),
  endTime: at('13:00').toISOString(),
  managed: true,
  fixed: true,
  notes: '',
};

/**
 * The day as the layout leaves it at [now] when nothing was begun: the
 * first task waits at the current minute (`awaitingStart`) and the queue
 * packs after it, 5 minutes apart, around the lunch.
 */
function dayAt(now: Date): Day {
  const placed = new Map<string, Interval>();
  let cursor = new Date(Math.max(now.getTime(), at('09:00').getTime()));
  for (const it of tasks) {
    let end = new Date(cursor.getTime() + it.minutes * 60_000);
    if (cursor < at('13:05') && end > at('11:55')) {
      cursor = at('13:05');
      end = new Date(cursor.getTime() + it.minutes * 60_000);
    }
    placed.set(it.id, { start: cursor, end });
    cursor = new Date(end.getTime() + 5 * 60_000);
  }
  return {
    now,
    zone: ZONE,
    workDay: DEFAULT_WORK_DAY,
    until: at('23:59'),
    events: [lunch],
    tasks,
    backlog: [],
    live: new Map(),
    placed,
    routines: new Map(),
    artifacts: new Map(),
  };
}

async function planAt(now: Date) {
  const timeline = {
    day: () => Promise.resolve(dayAt(now)),
    zone: () => ZONE,
  } as unknown as TimelineService;
  const plan = await new NotificationsService(timeline).plan({ id: 'u' }, 1, now);
  return plan.items
    .filter((it) => it.fireAt.startsWith('2026-10-26'))
    .map((it) => ({ at: hhmm(it.fireAt), kind: it.kind, title: it.title, body: it.body }));
}

async function main() {
  const syncs = ['08:30', '14:30'];
  const out: Record<string, unknown> = {};
  for (const s of syncs) out[`sync ${s}`] = await planAt(at(s));

  // What actually reaches the lock screen: each sync replaces the queue, so
  // an item fires only if it is still planned at the last sync before it.
  const fired: { at: string; kind: string; title: string; asks: boolean }[] = [];
  const plans = await Promise.all(syncs.map((s) => planAt(at(s))));
  plans.forEach((items, i) => {
    const from = syncs[i];
    const to = syncs[i + 1] ?? '24:00';
    for (const it of items) {
      if (it.at > from && it.at <= to) {
        fired.push({ at: it.at, kind: it.kind, title: it.title, asks: it.kind === 'confirmStart' });
      }
    }
  });
  out.fired = fired;
  out.summary = {
    tasksPlanned: tasks.length,
    remindersFired: fired.length,
    aboutATask: fired.filter((it) => it.kind === 'confirmStart').length,
    answerableWithoutOpening: 0,
    tasksStillWaitingAt22: tasks.length,
  };
  writeFileSync(join(__dirname, '../data/silent-day.json'), JSON.stringify(out, null, 2) + '\n');
  console.log(JSON.stringify(out, null, 2));
}

void main();
