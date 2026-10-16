import {
  CanActivate,
  ExecutionContext,
  INestApplication,
} from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { SessionGuard } from '../auth/session.guard';
import { CalendarService } from '../calendar/calendar.service';
import { CalendarStore, MemoryCalendarStore } from '../calendar/calendar.store';
import { Timeline } from '../events/entities/event.entity';
import { EventLayoutService } from '../events/event-layout.service';
import { PauseTickerService } from '../events/pause-ticker.service';
import { TasksController } from '../events/tasks.controller';
import { TimelineController } from '../events/timeline.controller';
import { TimelineService } from '../events/timeline.service';
import { MemoryTaskStore, TaskStore } from '../tasks/task.store';
import { DEFAULT_WORK_DAY } from '../time/work-hours';
import { MemoryProjectStore, ProjectStore } from './project.store';
import { ProjectsAnswer, ProjectView } from './project.types';
import { ProjectsController } from './projects.controller';
import { ProjectsService } from './projects.service';

/**
 * The projects end to end, with the day they let tasks out onto.
 *
 * The zone is pinned for the whole run by `jest.global-setup.js`, and only
 * `Date` is frozen, at ten in the morning there, as in
 * `events.controller.spec.ts`.
 */
const ZONE = 'America/Sao_Paulo';
const NOW = new Date('2026-03-10T13:00:00Z');

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

afterEach(() => {
  jest.setSystemTime(NOW);
});

function hhmm(iso: string): string {
  const at = new Date(iso);
  return `${String(at.getHours()).padStart(2, '0')}:${String(at.getMinutes()).padStart(2, '0')}`;
}

describe('ProjectsController', () => {
  let app: INestApplication<App>;

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ConfigModule.forRoot({ ignoreEnvFile: true })],
      controllers: [TimelineController, TasksController, ProjectsController],
      providers: [
        TimelineService,
        EventLayoutService,
        PauseTickerService,
        CalendarService,
        ProjectsService,
        { provide: CalendarStore, useClass: MemoryCalendarStore },
        { provide: TaskStore, useClass: MemoryTaskStore },
        { provide: ProjectStore, useClass: MemoryProjectStore },
      ],
    })
      .overrideGuard(SessionGuard)
      .useClass(StubSessionGuard)
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  const http = () => request(app.getHttpServer());

  function projects(response: { body: unknown }): ProjectView[] {
    return (response.body as ProjectsAnswer).projects;
  }

  async function timeline(): Promise<Timeline> {
    return (await http().get('/timeline').expect(200)).body as Timeline;
  }

  /** A project with [titles] written down in it, all parked. */
  async function projectWith(...titles: string[]): Promise<ProjectView> {
    let answer = await http()
      .post('/projects')
      .send({ title: 'Site do estúdio', deadline: '2026-03-24' })
      .expect(201);
    const id = projects(answer).at(-1)!.id;
    for (const title of titles) {
      answer = await http()
        .post(`/projects/${id}/tasks`)
        .send({ title, minutes: 30 })
        .expect(201);
    }
    return projects(answer).find((it) => it.id === id)!;
  }

  function place(project: ProjectView, title: string, body: object) {
    const task = project.tasks.find((it) => it.title === title)!;
    return http()
      .post(`/projects/${project.id}/tasks/${task.id}/place`)
      .send(body);
  }

  function taskOf(response: { body: unknown }, title: string) {
    return projects(response)
      .flatMap((it) => it.tasks)
      .find((it) => it.title === title)!;
  }

  it('writes a project down, with a deadline or without', async () => {
    await http().post('/projects').send({ title: 'Violão' }).expect(201);
    const answer = await http()
      .post('/projects')
      .send({ title: 'Mudança', deadline: '2026-04-10' })
      .expect(201);

    expect(
      projects(answer).map((it) => [it.title, it.deadline, it.doneAt]),
    ).toEqual([
      ['Violão', null, null],
      ['Mudança', '2026-04-10', null],
    ]);
  });

  it('refuses a deadline that is not a day, and a project with no name', async () => {
    await http()
      .post('/projects')
      .send({ title: 'X', deadline: '2026-02-30' })
      .expect(400);
    await http().post('/projects').send({ title: '  ' }).expect(400);
  });

  it('keeps a new task in the project, out of the day', async () => {
    const project = await projectWith('Textos da home');

    expect(project.tasks.map((it) => [it.title, it.place])).toEqual([
      ['Textos da home', 'project'],
    ]);
    const day = await timeline();
    expect(day.tasks).toEqual([]);
    expect(day.backlog).toEqual([]);
  });

  it('lets a task out into the backlog', async () => {
    const project = await projectWith('Textos da home');

    const answer = await place(project, 'Textos da home', {
      place: 'backlog',
    }).expect(201);

    expect(taskOf(answer, 'Textos da home').place).toBe('backlog');
    expect((await timeline()).backlog.map((it) => it.title)).toEqual([
      'Textos da home',
    ]);
  });

  it('lets a task out into the queue, with the hour the day gives it', async () => {
    await http()
      .post('/tasks')
      .send({ title: 'Email', minutes: 30, backlog: false })
      .expect(201);
    const project = await projectWith('Textos da home');

    const answer = await place(project, 'Textos da home', {
      place: 'queue',
    }).expect(201);

    const task = taskOf(answer, 'Textos da home');
    const day = await timeline();
    expect(day.tasks.map((it) => it.title)).toEqual([
      'Email',
      'Textos da home',
    ]);
    expect(task.place).toBe('queue');
    expect(task.at).toBe(day.tasks[1].startTime);
  });

  it('gives a task an hour of its own', async () => {
    const project = await projectWith('Textos da home');
    const at = new Date(NOW.getTime() + 5 * 3_600_000).toISOString();

    const answer = await place(project, 'Textos da home', {
      place: 'scheduled',
      at,
    }).expect(201);

    const task = taskOf(answer, 'Textos da home');
    expect(task.place).toBe('scheduled');
    expect(hhmm(task.at!)).toBe('15:00');
    expect((await timeline()).tasks.map((it) => hhmm(it.startTime))).toEqual([
      '15:00',
    ]);
  });

  it('refuses an hour that is not one', async () => {
    const project = await projectWith('Textos da home');
    await place(project, 'Textos da home', { place: 'scheduled' }).expect(400);
    await place(project, 'Textos da home', { place: 'later' }).expect(400);
  });

  it('takes a task off the day and back into the project', async () => {
    const project = await projectWith('Textos da home');
    await place(project, 'Textos da home', { place: 'queue' }).expect(201);

    const answer = await place(project, 'Textos da home', {
      place: 'project',
    }).expect(201);

    expect(taskOf(answer, 'Textos da home').place).toBe('project');
    expect((await timeline()).tasks).toEqual([]);
  });

  it('will not take back a task that has begun', async () => {
    const project = await projectWith('Textos da home');
    await place(project, 'Textos da home', { place: 'queue' }).expect(201);
    const id = project.tasks[0].id;
    await http().post(`/tasks/${id}/start`).expect(201);

    const refused = await place(project, 'Textos da home', {
      place: 'project',
    }).expect(400);

    expect((refused.body as { message: string }).message).toContain(
      'já começou',
    );
  });

  it('ticks off a parked task, and takes it back', async () => {
    const project = await projectWith('Textos da home');

    let answer = await place(project, 'Textos da home', {
      place: 'done',
    }).expect(201);
    expect(taskOf(answer, 'Textos da home').place).toBe('done');

    answer = await place(project, 'Textos da home', {
      place: 'project',
    }).expect(201);
    expect(taskOf(answer, 'Textos da home').place).toBe('project');
  });

  it('ticks off a task on the day through the day', async () => {
    const project = await projectWith('Textos da home');
    await place(project, 'Textos da home', { place: 'queue' }).expect(201);

    const answer = await place(project, 'Textos da home', {
      place: 'done',
    }).expect(201);

    expect(taskOf(answer, 'Textos da home').place).toBe('done');
    expect((await timeline()).tasks).toEqual([]);
  });

  it('orders the parked tasks by where they are dropped', async () => {
    const project = await projectWith('A', 'B', 'C');

    const answer = await place(project, 'C', {
      place: 'project',
      index: 0,
    }).expect(201);

    expect(projects(answer)[0].tasks.map((it) => it.title)).toEqual([
      'C',
      'A',
      'B',
    ]);
  });

  it('moves the deadline, takes it away, and marks the project done', async () => {
    const project = await projectWith();

    let answer = await http()
      .patch(`/projects/${project.id}`)
      .send({ deadline: '2026-03-25', notes: 'Ideias' })
      .expect(200);
    expect([projects(answer)[0].deadline, projects(answer)[0].notes]).toEqual([
      '2026-03-25',
      'Ideias',
    ]);

    answer = await http()
      .patch(`/projects/${project.id}`)
      .send({ deadline: null, done: true })
      .expect(200);
    expect(projects(answer)[0].deadline).toBeNull();
    expect(projects(answer)[0].doneAt).toBe(NOW.toISOString());
  });

  it('removes a project, keeping what was let out onto the day', async () => {
    const project = await projectWith('Parked', 'Out');
    await place(project, 'Out', { place: 'queue' }).expect(201);

    const answer = await http().delete(`/projects/${project.id}`).expect(200);

    expect(projects(answer)).toEqual([]);
    expect((await timeline()).tasks.map((it) => it.title)).toEqual(['Out']);
  });

  it('answers 404 for a task of another project', async () => {
    const first = await projectWith('Textos da home');
    const second = await projectWith();
    await http()
      .post(`/projects/${second.id}/tasks/${first.tasks[0].id}/place`)
      .send({ place: 'queue' })
      .expect(404);
  });
});
