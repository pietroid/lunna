/**
 * How far ahead does the phone's queue of 60 reminders reach, today and
 * under the proposed lifecycle?
 *
 * Builds a week in São Paulo (now: Monday 26/10/2026, 07:30) with N fixed
 * blocks a day (breakfast, lunch, dinner, then more), a queue of tasks
 * filling the rest of each working day, and asks the real
 * NotificationsService for a 7-day plan. Then counts what the proposal
 * would add for the same week:
 *
 *   start   3 asks per block (at its hour, +10, +20)
 *   end     3 asks per block (at its end, +10, +20)
 *   heads   1 "X em 15 minutos" per fixed block with something right before
 *   next    the next task's 3 start asks
 *   daily   morning and evening, unchanged
 *
 * and a trimmed variant: the re-asks only for the next 24 hours.
 *
 * and how many days the 60 soonest cover (NotificationScheduler.maxQueued).
 *
 *   cd server && NODE_PATH=$PWD/node_modules npx tsx ../product/research/2026-10-28-notification-lifecycle/code/plan-count.ts
 *
 * Writes data/plan-count.csv next to this folder.
 */
import * as fs from 'fs';
import * as path from 'path';
import type { CalendarEvent } from '../../../../server/src/calendar/calendar.types';
import type { Day, TimelineService } from '../../../../server/src/events/timeline.service';
import { NotificationsService } from '../../../../server/src/notifications/notifications.service';
import { DEFAULT_WORK_DAY } from '../../../../server/src/time/work-hours';
import { addDaysIn, atMinuteIn } from '../../../../server/src/time/zone';

const ZONE = 'America/Sao_Paulo';
const NOW = new Date('2026-10-26T10:30:00.000Z'); // 07:30 in São Paulo
const HORIZON = 7;
const MAX_QUEUED = 60;
const ASKS = 3;
const MIN = 60_000;

/** Fixed blocks of a day, in the order they are added: [start, minutes]. */
const BLOCKS: [string, number, number][] = [
  ['Café', 8 * 60, 30],
  ['Almoço', 12 * 60, 60],
  ['Jantar', 19 * 60 + 30, 45],
  ['Academia', 7 * 60, 60],
  ['Reunião', 15 * 60, 30],
  ['Leitura', 21 * 60, 30],
];

function weekOf(perDay: number): CalendarEvent[] {
  const events: CalendarEvent[] = [];
  for (let d = 0; d <= HORIZON; d++) {
    const day = addDaysIn(NOW, d, ZONE);
    for (const [title, at, minutes] of BLOCKS.slice(0, perDay)) {
      const start = atMinuteIn(day, at, ZONE);
      events.push({
        id: `${title}-${d}`,
        title,
        startTime: start.toISOString(),
        endTime: new Date(start.getTime() + minutes * MIN).toISOString(),
        managed: true,
        fixed: true,
        notes: '',
      });
    }
  }
  return events;
}

async function todayPlan(events: CalendarEvent[]) {
  // The next task: the queue's first, at 08:35 (or 07:35 with no blocks).
  const start = new Date(NOW.getTime() + 65 * MIN);
  const day: Day = {
    now: NOW,
    zone: ZONE,
    workDay: DEFAULT_WORK_DAY,
    until: addDaysIn(NOW, HORIZON + 1, ZONE),
    events,
    tasks: [{ id: 't1', title: 'Relatório', notes: '', minutes: 45, position: 0, backlog: false }],
    backlog: [],
    live: new Map(),
    placed: new Map([['t1', { start, end: new Date(start.getTime() + 45 * MIN) }]]),
    routines: new Map(),
    artifacts: new Map(),
  } as unknown as Day;
  const timeline = { day: async () => day, zone: () => ZONE } as unknown as TimelineService;
  return (await new NotificationsService(timeline).plan({ id: 'u' } as never, HORIZON, NOW)).items;
}

/** The proposal's reminders for the same week, as fire instants. */
function proposed(events: CalendarEvent[], daily: Date[], fullFor = HORIZON): Date[] {
  const until = addDaysIn(NOW, HORIZON, ZONE).getTime();
  const out: Date[] = [...daily];
  const next = NOW.getTime() + 65 * MIN;
  for (let i = 0; i < ASKS; i++) out.push(new Date(next + i * 10 * MIN));
  for (const event of events) {
    const start = Date.parse(event.startTime);
    const end = Date.parse(event.endTime);
    // The queue fills the working day, so every block but the day's first
    // has something running right before it.
    const sameDay = events.filter((o) => o.id.split('-')[1] === event.id.split('-')[1]);
    const first = sameDay.every((o) => Date.parse(o.startTime) >= start);
    if (!first) out.push(new Date(start - 15 * MIN));
    // Past [fullFor] days only the first ask of each is queued; the
    // re-asks are added by a later sync, once the block is that close.
    const asks = start - NOW.getTime() < fullFor * 86_400_000 ? ASKS : 1;
    for (let i = 0; i < asks; i++) {
      out.push(new Date(start + i * 10 * MIN));
      out.push(new Date(end + i * 10 * MIN));
    }
  }
  return out
    .filter((at) => at.getTime() > NOW.getTime() && at.getTime() <= until)
    .sort((a, b) => a.getTime() - b.getTime());
}

/** Days from now the 60 soonest reach, or the whole horizon. */
function reach(fires: Date[]): number {
  if (fires.length <= MAX_QUEUED) return HORIZON;
  return (fires[MAX_QUEUED - 1].getTime() - NOW.getTime()) / 86_400_000;
}

async function main() {
  const rows = ['blocks_per_day,today_items,today_reach_days,proposed_items,proposed_reach_days,trimmed_items,trimmed_reach_days'];
  for (let n = 0; n <= BLOCKS.length; n++) {
    const events = weekOf(n);
    const items = await todayPlan(events);
    const daily = items
      .filter((it) => it.kind === 'morning' || it.kind === 'evening')
      .map((it) => new Date(it.fireAt));
    const today = items.map((it) => new Date(it.fireAt));
    const next = proposed(events, daily);
    const trimmed = proposed(events, daily, 1);
    rows.push(
      [
        n,
        today.length,
        reach(today).toFixed(2),
        next.length,
        reach(next).toFixed(2),
        trimmed.length,
        reach(trimmed).toFixed(2),
      ].join(','),
    );
  }
  const out = path.join(__dirname, '..', 'data', 'plan-count.csv');
  fs.writeFileSync(out, rows.join('\n') + '\n');
  console.log(rows.join('\n'));
}

void main();
