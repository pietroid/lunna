import {
  CanActivate,
  ExecutionContext,
  INestApplication,
} from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import {
  ArtifactStore,
  MemoryArtifactStore,
} from '../artifacts/artifact.store';
import { ArtifactsAnswer } from '../artifacts/artifact.types';
import { ArtifactsController } from '../artifacts/artifacts.controller';
import { ArtifactsService } from '../artifacts/artifacts.service';
import { SessionGuard } from '../auth/session.guard';
import { CalendarService } from '../calendar/calendar.service';
import { CalendarStore, MemoryCalendarStore } from '../calendar/calendar.store';
import { Timeline, TimelineCard } from '../events/entities/event.entity';
import { EventLayoutService } from '../events/event-layout.service';
import { EventsController } from '../events/events.controller';
import { TasksController } from '../events/tasks.controller';
import { TimelineController } from '../events/timeline.controller';
import { TimelineService } from '../events/timeline.service';
import { MemoryTaskStore, TaskStore } from '../tasks/task.store';
import { DEFAULT_WORK_DAY } from '../time/work-hours';
import { formatDayIn, formatTimeIn } from '../time/zone';
import { RhythmController } from './rhythm.controller';
import { RhythmService, RhythmView } from './rhythm.service';
import { MemoryRhythmStore, RhythmStore } from './rhythm.store';

/**
 * Ciclo and Folgas end to end: the routes, and what they do to the day the
 * timeline lays out, over the memory stores and a frozen clock.
 *
 * Friday 30 October 2026, 10:00 in São Paulo. The weekend after it is off
 * by default.
 */
const ZONE = 'America/Sao_Paulo';
const NOW = new Date('2026-10-30T13:00:00Z');

class StubSessionGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    context.switchToHttp().getRequest<{ user: unknown }>().user = {
      id: 'test-user',
      email: 'test@example.com',
      name: 'Test',
      timeZone: ZONE,
      dayStart: DEFAULT_WORK_DAY.start,
      dayEnd: DEFAULT_WORK_DAY.end,
    };
    return true;
  }
}

beforeAll(() => {
  jest.useFakeTimers({
    now: NOW,
    doNotFake: [
      'cancelAnimationFrame',
      'cancelIdleCallback',
      'clearImmediate',
      'clearInterval',
      'clearTimeout',
      'hrtime',
      'nextTick',
      'performance',
      'queueMicrotask',
      'requestAnimationFrame',
      'requestIdleCallback',
      'setImmediate',
      'setInterval',
      'setTimeout',
    ],
  });
});

afterAll(() => {
  jest.useRealTimers();
});

/** "30-10-2026 09:00", where a card landed. */
function when(card: TimelineCard | undefined): string {
  if (card === undefined) return 'nowhere';
  const at = new Date(card.startTime);
  return `${formatDayIn(at, ZONE)} ${formatTimeIn(at, ZONE)}`;
}

describe('the rhythm', () => {
  let app: INestApplication<App>;

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ConfigModule.forRoot({ ignoreEnvFile: true })],
      controllers: [
        TimelineController,
        EventsController,
        TasksController,
        ArtifactsController,
        RhythmController,
      ],
      providers: [
        TimelineService,
        EventLayoutService,
        CalendarService,
        ArtifactsService,
        RhythmService,
        { provide: CalendarStore, useClass: MemoryCalendarStore },
        { provide: TaskStore, useClass: MemoryTaskStore },
        { provide: ArtifactStore, useClass: MemoryArtifactStore },
        { provide: RhythmStore, useClass: MemoryRhythmStore },
      ],
    })
      .overrideGuard(SessionGuard)
      .useClass(StubSessionGuard)
      .compile();

    app = moduleRef.createNestApplication();
    await app.listen(0, '127.0.0.1');
  });

  afterEach(async () => {
    await app.close();
  });

  const http = () => request(app.getHttpServer());
  const rhythm = (r: { body: unknown }) => r.body as RhythmView;
  const timeline = async (days = 4) =>
    (await http().get(`/timeline?days=${days}`).expect(200)).body as Timeline;
  const task = (title: string, minutes: number) =>
    http().post('/tasks').send({ title, minutes, backlog: false }).expect(201);
  const card = (view: Timeline, title: string) =>
    view.cards.find((it) => it.title === title) ??
    view.tasks.find((it) => it.title === title);

  /** A delivery begun, due [deadline], with one task of [minutes] queued. */
  async function delivery(title: string, deadline: string, minutes: number) {
    const made = (
      await http()
        .post('/artifacts')
        .send({ title, deadline, minutes, value: 1000, started: true })
        .expect(201)
    ).body as ArtifactsAnswer;
    const id = made.artifacts.find((it) => it.title === title)!.id;
    await http()
      .post(`/artifacts/${id}/tasks`)
      .send({ title: `${title} · sessão`, minutes })
      .expect(201);
    const view = await timeline(8);
    const step = view.backlog.find((it) => it.title === `${title} · sessão`);
    if (step !== undefined) {
      await http()
        .post(`/tasks/${step.id}/move`)
        .send({ index: 99 })
        .expect(201);
    }
    return id;
  }

  it('answers the weekend off and no cycle for someone who set nothing', async () => {
    const view = rhythm(await http().get('/rhythm').expect(200));
    expect(view).toEqual({
      cycle: null,
      rest: { saturday: 'off', sunday: 'off', lightMinutes: 180 },
      daysOff: [],
    });
  });

  it('marks the weekend off in the timeline, and the queue goes to Monday', async () => {
    await task('Relatório', 600);
    await task('Revisão', 120);
    const view = await timeline();

    expect(view.days.map((it) => [it.day, it.kind, it.reason])).toEqual([
      ['2026-10-31', 'off', 'weekend'],
      ['2026-11-01', 'off', 'weekend'],
    ]);
    expect(when(card(view, 'Relatório'))).toBe('30-10-2026 10:00');
    expect(when(card(view, 'Revisão'))).toBe('02-11-2026 07:00');
  });

  it('puts one Saturday back to work, and takes it off again', async () => {
    await task('Relatório', 600);
    await task('Revisão', 120);
    const put = rhythm(
      await http()
        .post('/rhythm/days-off')
        .send({ day: '2026-10-31', kind: 'work' })
        .expect(201),
    );
    expect(put.daysOff).toMatchObject([{ day: '2026-10-31', kind: 'work' }]);
    expect(when(card(await timeline(), 'Revisão'))).toBe('31-10-2026 07:00');

    await http().delete(`/rhythm/days-off/${put.daysOff[0].id}`).expect(200);
    expect(when(card(await timeline(), 'Revisão'))).toBe('02-11-2026 07:00');
  });

  it('starts a period today: a light day, the loose task stays and the delivery’s moves on', async () => {
    await delivery('Mapa da Ana', '2026-11-10', 60);
    await task('Responder e-mails', 30);
    const started = rhythm(
      await http()
        .post('/rhythm/cycle/start')
        .send({ day: '2026-10-30' })
        .expect(201),
    );
    expect(started.cycle).toMatchObject({
      lastStart: '2026-10-30',
      length: 28,
      periodLength: 5,
      periodKind: 'light',
      predictedStart: '2026-11-27',
    });

    const view = await timeline();
    expect(view.days[0]).toEqual({
      day: '2026-10-30',
      kind: 'light',
      reason: 'period',
      budgetMinutes: 180,
      cycle: { day: 1, length: 28, phase: 'menstrual' },
    });
    expect(when(card(view, 'Responder e-mails'))).toBe('30-10-2026 10:00');
    // The period runs to Tuesday; Monday and Tuesday are light too.
    expect(when(card(await timeline(8), 'Mapa da Ana · sessão'))).toBe(
      '04-11-2026 07:00',
    );
  });

  it('stops a light day at its budget', async () => {
    await http().patch('/rhythm/rest').send({ lightMinutes: 60 }).expect(200);
    await http().post('/rhythm/cycle/start').send({ day: '2026-10-30' });
    await task('Um', 45);
    await task('Dois', 30);
    const view = await timeline();
    expect(when(card(view, 'Um'))).toBe('30-10-2026 10:00');
    expect(when(card(view, 'Dois'))).toBe('02-11-2026 07:00');
  });

  it('counts a delivery’s time on working days only', async () => {
    // Begun Friday at 10:00, due Monday: Friday's 12 hours left and
    // Monday's 15 are its working time; the weekend counts nothing.
    await delivery('Curso', '2026-11-02', 60);
    const answer = (await http().get('/artifacts').expect(200))
      .body as ArtifactsAnswer;
    const curso = answer.artifacts.find((it) => it.title === 'Curso')!;
    expect(curso.timeGone).toBe(0);

    jest.setSystemTime(new Date('2026-10-31T18:00:00Z'));
    try {
      const later = (await http().get('/artifacts').expect(200))
        .body as ArtifactsAnswer;
      const it = later.artifacts.find((a) => a.title === 'Curso')!;
      expect(it.timeGone).toBeCloseTo(12 / 27);
    } finally {
      jest.setSystemTime(NOW);
    }
  });

  it('corrects the next period, and goes back to the prediction', async () => {
    await http().post('/rhythm/cycle/start').send({ day: '2026-10-28' });
    const saved = (next: string | null) =>
      http().put('/rhythm/cycle').send({
        lastStart: '2026-10-28',
        length: 28,
        periodLength: 5,
        periodKind: 'light',
        nextStart: next,
      });
    expect(rhythm(await saved('2026-11-23').expect(200)).cycle).toMatchObject({
      nextStart: '2026-11-23',
      predictedStart: '2026-11-23',
    });
    const back = rhythm(await saved(null).expect(200)).cycle!;
    expect(back.nextStart).toBeUndefined();
    expect(back.predictedStart).toBe('2026-11-25');
  });

  it.each([
    ['a start ahead', 'post', '/rhythm/cycle/start', { day: '2026-11-02' }],
    ['a date that is not one', 'post', '/rhythm/cycle/start', { day: '30/10' }],
    [
      'a cycle too short',
      'put',
      '/rhythm/cycle',
      { lastStart: '2026-10-28', length: 15, periodLength: 5 },
    ],
    [
      'a next period already come',
      'put',
      '/rhythm/cycle',
      {
        lastStart: '2026-10-28',
        length: 28,
        periodLength: 5,
        nextStart: '2026-10-30',
      },
    ],
    ['a kind it does not know', 'patch', '/rhythm/rest', { saturday: 'meio' }],
    ['a light day past 8 h', 'patch', '/rhythm/rest', { lightMinutes: 600 }],
    ['a day off gone', 'post', '/rhythm/days-off', { day: '2026-10-29' }],
  ] as const)('refuses %s', async (_name, method, path, payload) => {
    await http()[method](path).send(payload).expect(400);
  });

  it('refuses to take away a date it never wrote', async () => {
    await http()
      .delete('/rhythm/days-off/00000000-0000-4000-8000-000000000000')
      .expect(404);
  });
});
