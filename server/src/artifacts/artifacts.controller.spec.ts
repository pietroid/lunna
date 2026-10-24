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
import { TasksController } from '../events/tasks.controller';
import { TimelineController } from '../events/timeline.controller';
import { TimelineService } from '../events/timeline.service';
import { MemoryTaskStore, TaskStore } from '../tasks/task.store';
import { DEFAULT_WORK_DAY } from '../time/work-hours';
import { MemoryArtifactStore, ArtifactStore } from './artifact.store';
import { ArtifactsAnswer, ArtifactView } from './artifact.types';
import { ArtifactsController } from './artifacts.controller';
import { ArtifactsService } from './artifacts.service';

/**
 * The artifacts end to end, with the day they let tasks out onto.
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

describe('ArtifactsController', () => {
  let app: INestApplication<App>;

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ConfigModule.forRoot({ ignoreEnvFile: true })],
      controllers: [TimelineController, TasksController, ArtifactsController],
      providers: [
        TimelineService,
        EventLayoutService,
        CalendarService,
        ArtifactsService,
        { provide: CalendarStore, useClass: MemoryCalendarStore },
        { provide: TaskStore, useClass: MemoryTaskStore },
        { provide: ArtifactStore, useClass: MemoryArtifactStore },
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

  function artifacts(response: { body: unknown }): ArtifactView[] {
    return (response.body as ArtifactsAnswer).artifacts;
  }

  async function timeline(): Promise<Timeline> {
    return (await http().get('/timeline').expect(200)).body as Timeline;
  }

  /** An artifact with [titles] written down in it, in the backlog. */
  async function artifactWith(...titles: string[]): Promise<ArtifactView> {
    let answer = await http()
      .post('/artifacts')
      .send({ title: 'Site do estúdio', deadline: '2026-03-24' })
      .expect(201);
    const id = artifacts(answer).at(-1)!.id;
    for (const title of titles) {
      answer = await http()
        .post(`/artifacts/${id}/tasks`)
        .send({ title, minutes: 30 })
        .expect(201);
    }
    return artifacts(answer).find((it) => it.id === id)!;
  }

  function taskOf(response: { body: unknown }, title: string) {
    return artifacts(response)
      .flatMap((it) => it.tasks)
      .find((it) => it.title === title)!;
  }

  it('writes an artifact down, with a deadline or without', async () => {
    await http().post('/artifacts').send({ title: 'Violão' }).expect(201);
    const answer = await http()
      .post('/artifacts')
      .send({ title: 'Mudança', deadline: '2026-04-10' })
      .expect(201);

    expect(
      artifacts(answer).map((it) => [it.title, it.deadline, it.doneAt]),
    ).toEqual([
      ['Violão', null, null],
      ['Mudança', '2026-04-10', null],
    ]);
  });

  it('refuses a deadline that is not a day, and an artifact with no name', async () => {
    await http()
      .post('/artifacts')
      .send({ title: 'X', deadline: '2026-02-30' })
      .expect(400);
    await http().post('/artifacts').send({ title: '  ' }).expect(400);
  });

  it('writes the task of an artifact at the end of the backlog', async () => {
    await http()
      .post('/tasks')
      .send({ title: 'Email', minutes: 30 })
      .expect(201);
    const artifact = await artifactWith('Textos da home');

    expect(artifact.tasks.map((it) => [it.title, it.place])).toEqual([
      ['Textos da home', 'backlog'],
    ]);
    expect((await timeline()).backlog.map((it) => it.title)).toEqual([
      'Email',
      'Textos da home',
    ]);
  });

  it('writes a task into an artifact from the day, and refuses a missing one', async () => {
    const artifact = await artifactWith();
    const at = new Date(NOW.getTime() + 5 * 3_600_000).toISOString();

    await http()
      .post('/tasks')
      .send({
        title: 'Textos da home',
        minutes: 30,
        backlog: false,
        notBefore: at,
        artifactId: artifact.id,
      })
      .expect(201);
    const refused = await http()
      .post('/tasks')
      .send({ title: 'Outra', minutes: 30, artifactId: 'no-such-artifact' })
      .expect(400);

    expect((refused.body as { message: string }).message).toContain('entrega');
    const task = taskOf(
      await http().get('/artifacts').expect(200),
      'Textos da home',
    );
    expect([task.place, hhmm(task.at!)]).toEqual(['scheduled', '15:00']);
  });

  it('follows its task wherever the day moves it, with its hour', async () => {
    await http()
      .post('/tasks')
      .send({ title: 'Email', minutes: 30, backlog: false })
      .expect(201);
    const artifact = await artifactWith('Textos da home');
    const id = artifact.tasks[0].id;

    await http()
      .post(`/tasks/${id}/move`)
      .send({ index: 1, backlog: false })
      .expect(201);

    const task = taskOf(
      await http().get('/artifacts').expect(200),
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
    const artifact = await artifactWith('Textos da home');
    const id = artifact.tasks[0].id;

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
      await http().get('/artifacts').expect(200),
      'Textos da home',
    );
    expect([task.place, task.notes, task.doneAt]).toEqual([
      'done',
      'Revisar',
      NOW.toISOString(),
    ]);
  });

  it('moves the deadline, takes it away, and marks the artifact done', async () => {
    const artifact = await artifactWith();

    let answer = await http()
      .patch(`/artifacts/${artifact.id}`)
      .send({ deadline: '2026-03-25', notes: 'Ideias' })
      .expect(200);
    expect([artifacts(answer)[0].deadline, artifacts(answer)[0].notes]).toEqual(
      ['2026-03-25', 'Ideias'],
    );

    answer = await http()
      .patch(`/artifacts/${artifact.id}`)
      .send({ deadline: null, done: true })
      .expect(200);
    expect(artifacts(answer)[0].deadline).toBeNull();
    expect(artifacts(answer)[0].doneAt).toBe(NOW.toISOString());
  });

  it('removes an artifact with what waits in the backlog, keeping the rest', async () => {
    const artifact = await artifactWith('Esperando', 'Na fila', 'Feita');
    const [, queued, done] = artifact.tasks.map((it) => it.id);
    await http()
      .post(`/tasks/${queued}/move`)
      .send({ index: 0, backlog: false })
      .expect(201);
    await http().post(`/tasks/${done}/done`).expect(201);

    const answer = await http().delete(`/artifacts/${artifact.id}`).expect(200);

    expect(artifacts(answer)).toEqual([]);
    const day = await timeline();
    expect(day.tasks.map((it) => it.title)).toEqual(['Na fila']);
    expect(day.backlog).toEqual([]);
  });

  it('answers 404 for an artifact that is not there', async () => {
    await http()
      .post('/artifacts/no-such-artifact/tasks')
      .send({ title: 'X', minutes: 30 })
      .expect(404);
  });

  describe('the catalogue, the goals and the schedule', () => {
    function answerOf(response: { body: unknown }): ArtifactsAnswer {
      return response.body as ArtifactsAnswer;
    }

    /** Writes a kind down on the shelf named [category]; answers its id. */
    async function kind(
      name: string,
      category: string,
      more: Record<string, unknown> = {},
    ): Promise<string> {
      const answer = answerOf(
        await http()
          .post('/catalog/types')
          .send({ name, category, minutes: 60, ...more })
          .expect(201),
      );
      return answer.catalog
        .flatMap((it) => it.types)
        .find((it) => it.name === name)!.id;
    }

    async function deliver(body: Record<string, unknown>): Promise<string> {
      const answer = answerOf(
        await http().post('/artifacts').send(body).expect(201),
      );
      return answer.artifacts.find((it) => it.title === body.title)!.id;
    }

    it('starts empty, and fills with kinds on shelves named or picked', async () => {
      let answer = answerOf(await http().get('/artifacts').expect(200));
      expect([answer.catalog, answer.goals, answer.topTypes]).toEqual([
        [],
        [],
        [],
      ]);

      await kind('Mapa astral', 'Atendimentos', {
        minutes: 90,
        price: 350,
        blockMinutes: 60,
      });
      await kind('Revolução solar', 'atendimentos');
      await kind('Reels', 'Conteúdo', { minutes: 45, price: null });
      answer = answerOf(await http().get('/artifacts').expect(200));
      const shelf = answer.catalog[0].id;
      answer = answerOf(
        await http()
          .post('/catalog/types')
          .send({ name: 'Sinastria', categoryId: shelf, minutes: 120 })
          .expect(201),
      );

      expect(
        answer.catalog.map((it) => [it.name, it.types.map((t) => t.name)]),
      ).toEqual([
        ['Atendimentos', ['Mapa astral', 'Revolução solar', 'Sinastria']],
        ['Conteúdo', ['Reels']],
      ]);
      expect(answer.catalog[0].types[0]).toMatchObject({
        minutes: 90,
        price: 350,
        blockMinutes: 60,
      });
      await http()
        .post('/catalog/types')
        .send({ name: 'X', minutes: 30, categoryId: shelf, category: 'Y' })
        .expect(400);
      await http()
        .post('/catalog/types')
        .send({ name: 'X', minutes: 30 })
        .expect(400);
    });

    it('writes a delivery of a kind with its time, value and blocks, at the top or the end', async () => {
      const mapa = await kind('Mapa astral', 'Atendimentos', {
        minutes: 90,
        price: 350,
        blockMinutes: 60,
      });
      await deliver({ title: 'Post avulso', minutes: 30 });
      await deliver({ title: 'Mapa · Ana', typeId: mapa, at: 'top' });
      await deliver({ title: 'Mapa · Bia', typeId: mapa, value: 400 });
      await deliver({ title: 'Mapa · Cris', typeId: mapa, blockMinutes: null });

      const answer = answerOf(await http().get('/artifacts').expect(200));
      expect(
        answer.artifacts.map((it) => [
          it.title,
          it.typeId,
          it.minutes,
          it.value,
          it.blockMinutes,
        ]),
      ).toEqual([
        ['Mapa · Ana', mapa, 90, 350, 60],
        ['Post avulso', null, 30, null, null],
        ['Mapa · Bia', mapa, 90, 400, 60],
        ['Mapa · Cris', mapa, 90, 350, null],
      ]);

      const refused = await http()
        .post('/artifacts')
        .send({ title: 'X', typeId: '00000000-0000-4000-8000-000000000000' })
        .expect(400);
      expect((refused.body as { message: string }).message).toContain('tipo');
    });

    it('drags a delivery to another place, and never a delivered one', async () => {
      const first = await deliver({ title: 'Primeira' });
      await deliver({ title: 'Segunda' });
      const third = await deliver({ title: 'Terceira' });

      let answer = answerOf(
        await http()
          .post(`/artifacts/${third}/move`)
          .send({ index: 0 })
          .expect(201),
      );
      expect(answer.artifacts.map((it) => it.title)).toEqual([
        'Terceira',
        'Primeira',
        'Segunda',
      ]);
      answer = answerOf(
        await http()
          .post(`/artifacts/${first}/move`)
          .send({ index: 9 })
          .expect(201),
      );
      expect(answer.artifacts.map((it) => it.title)).toEqual([
        'Terceira',
        'Segunda',
        'Primeira',
      ]);

      await http()
        .patch(`/artifacts/${first}`)
        .send({ done: true })
        .expect(200);
      await http()
        .post(`/artifacts/${first}/move`)
        .send({ index: 0 })
        .expect(400);
      await http()
        .post(`/artifacts/${third}/move`)
        .send({ index: -1 })
        .expect(400);
    });

    it('measures goals over this month and this week, and waits with one ahead', async () => {
      const mapa = await kind('Mapa astral', 'Atendimentos', { price: 350 });
      // Tuesday 10 March: the week began on Monday the 9th.
      await deliver({
        title: 'Mapa · Ana',
        typeId: mapa,
        deadline: '2026-03-13',
      });
      await deliver({
        title: 'Mapa · Bia',
        typeId: mapa,
        deadline: '2026-04-05',
      });
      const curso = await deliver({
        title: 'Curso',
        value: 1000,
        deadline: '2026-03-12',
      });
      await http()
        .patch(`/artifacts/${curso}`)
        .send({ done: true })
        .expect(200);

      await http()
        .post('/goals')
        .send({ kind: 'money', target: 8000, period: 'month' })
        .expect(201);
      await http()
        .post('/goals')
        .send({ kind: 'count', typeId: mapa, target: 2, period: 'week' })
        .expect(201);
      const answer = answerOf(
        await http()
          .post('/goals')
          .send({ kind: 'money', target: 9000, period: 'month', start: 'next' })
          .expect(201),
      );

      expect(
        answer.goals.map((it) => [
          it.kind,
          it.target,
          it.start,
          it.end,
          it.done,
          it.queued,
        ]),
      ).toEqual([
        ['money', 8000, '2026-03-01', '2026-04-01', 1000, 350],
        ['count', 2, '2026-03-09', '2026-03-16', 0, 1],
        ['money', 9000, '2026-04-01', '2026-05-01', 0, 350],
      ]);

      await http()
        .post('/goals')
        .send({ kind: 'count', target: 2, period: 'week' })
        .expect(400);
      const gone = answerOf(
        await http().delete(`/goals/${answer.goals[1].id}`).expect(200),
      );
      expect(gone.goals.map((it) => it.kind)).toEqual(['money', 'money']);
    });

    it('sets the time the month owes against the free hours left on the agenda', async () => {
      await deliver({ title: 'Mapa', minutes: 120, deadline: '2026-03-20' });
      await deliver({ title: 'Curso', minutes: 300, deadline: '2026-04-20' });
      await deliver({ title: 'Sem prazo', minutes: 60 });

      let answer = answerOf(await http().get('/artifacts').expect(200));
      // 10:00 to 22:00 today, then 21 whole working days of 15 hours.
      expect(answer.schedule).toEqual({
        needMinutes: 120,
        freeMinutes: 12 * 60 + 21 * 15 * 60,
        until: '2026-03-31',
      });

      await http()
        .post('/tasks')
        .send({ title: 'Reunião', minutes: 30, backlog: false })
        .expect(201);
      answer = answerOf(await http().get('/artifacts').expect(200));
      expect(answer.schedule.freeMinutes).toBe(12 * 60 + 21 * 15 * 60 - 30);
    });

    it('names the kinds used most, all time, the catalogue breaking ties', async () => {
      const [a, b, c, d] = [
        await kind('A', 'Uma'),
        await kind('B', 'Uma'),
        await kind('C', 'Outra'),
        await kind('D', 'Outra'),
      ];
      await deliver({ title: 'd1', typeId: d });
      await deliver({ title: 'd2', typeId: d });
      await deliver({ title: 'c1', typeId: c });
      const b1 = await deliver({ title: 'b1', typeId: b });
      await http().patch(`/artifacts/${b1}`).send({ done: true }).expect(200);

      const answer = answerOf(await http().get('/artifacts').expect(200));
      expect(answer.topTypes).toEqual([d, b, c]);
      expect(answer.topTypes).not.toContain(a);
    });
  });
});
