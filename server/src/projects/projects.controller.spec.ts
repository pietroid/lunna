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
    // Bound to loopback, once. Left to supertest, each request listens on `::`,
    // which macOS will share with a port another program holds on 127.0.0.1,
    // and the request (sent to 127.0.0.1) reaches that program instead.
    await app.listen(0, '127.0.0.1');
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

  /** A project with [titles] written down in it, in the backlog. */
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

  it('writes the task of a project at the end of the backlog', async () => {
    await http()
      .post('/tasks')
      .send({ title: 'Email', minutes: 30 })
      .expect(201);
    const project = await projectWith('Textos da home');

    expect(project.tasks.map((it) => [it.title, it.place])).toEqual([
      ['Textos da home', 'backlog'],
    ]);
    expect((await timeline()).backlog.map((it) => it.title)).toEqual([
      'Email',
      'Textos da home',
    ]);
  });

  it('writes a task into a project from the day, and refuses a missing one', async () => {
    const project = await projectWith();
    const at = new Date(NOW.getTime() + 5 * 3_600_000).toISOString();

    await http()
      .post('/tasks')
      .send({
        title: 'Textos da home',
        minutes: 30,
        backlog: false,
        notBefore: at,
        projectId: project.id,
      })
      .expect(201);
    const refused = await http()
      .post('/tasks')
      .send({ title: 'Outra', minutes: 30, projectId: 'no-such-project' })
      .expect(400);

    expect((refused.body as { message: string }).message).toContain('projeto');
    const task = taskOf(
      await http().get('/projects').expect(200),
      'Textos da home',
    );
    expect([task.place, hhmm(task.at!)]).toEqual(['scheduled', '15:00']);
  });

  it('follows its task wherever the day moves it, with its hour', async () => {
    await http()
      .post('/tasks')
      .send({ title: 'Email', minutes: 30, backlog: false })
      .expect(201);
    const project = await projectWith('Textos da home');
    const id = project.tasks[0].id;

    await http()
      .post(`/tasks/${id}/move`)
      .send({ index: 1, backlog: false })
      .expect(201);

    const task = taskOf(
      await http().get('/projects').expect(200),
      'Textos da home',
    );
    const day = await timeline();
    expect(day.tasks.map((it) => it.title)).toEqual([
      'Email',
      'Textos da home',
    ]);
    expect(task.place).toBe('queue');
    expect(task.at).toBe(day.tasks[1].startTime);
  });

  it('keeps a finished task, whose notes still change', async () => {
    const project = await projectWith('Textos da home');
    const id = project.tasks[0].id;

    await http().post(`/tasks/${id}/done`).expect(201);
    await http().patch(`/tasks/${id}`).send({ notes: 'Revisar' }).expect(200);
    const refused = await http()
      .patch(`/tasks/${id}`)
      .send({ workMinutes: 45 })
      .expect(400);

    expect((refused.body as { message: string }).message).toContain(
      'já foi feita',
    );
    const task = taskOf(
      await http().get('/projects').expect(200),
      'Textos da home',
    );
    expect([task.place, task.notes, task.doneAt]).toEqual([
      'done',
      'Revisar',
      NOW.toISOString(),
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

  it('removes a project with what waits in the backlog, keeping the rest', async () => {
    const project = await projectWith('Esperando', 'Na fila', 'Feita');
    const [, queued, done] = project.tasks.map((it) => it.id);
    await http()
      .post(`/tasks/${queued}/move`)
      .send({ index: 0, backlog: false })
      .expect(201);
    await http().post(`/tasks/${done}/done`).expect(201);

    const answer = await http().delete(`/projects/${project.id}`).expect(200);

    expect(projects(answer)).toEqual([]);
    const day = await timeline();
    expect(day.tasks.map((it) => it.title)).toEqual(['Na fila']);
    expect(day.backlog).toEqual([]);
  });

  it('answers 404 for a project that is not there', async () => {
    await http()
      .post('/projects/no-such-project/tasks')
      .send({ title: 'X', minutes: 30 })
      .expect(404);
  });
});
