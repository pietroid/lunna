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
import { EventsController } from '../events/events.controller';
import { TasksController } from '../events/tasks.controller';
import { PauseTickerService } from '../events/pause-ticker.service';
import { TimelineController } from '../events/timeline.controller';
import { TimelineService } from '../events/timeline.service';
import {
  MemoryArtifactStore,
  ArtifactStore,
} from '../artifacts/artifact.store';
import { MemoryTaskStore, TaskStore } from '../tasks/task.store';
import { DEFAULT_WORK_DAY } from '../time/work-hours';
import { AgentController } from './agent.controller';
import { AgentReply, AgentService } from './agent.service';
import {
  Conversation,
  ConversationStore,
  MemoryConversationStore,
} from './conversation.store';
import {
  ChatMessage,
  ModelOutcome,
  ModelUnavailableError,
  OpenRouterClient,
} from './openrouter.client';

const ZONE = 'America/Sao_Paulo';
/** Tuesday 10 March 2026, ten in the morning in São Paulo. */
const NOW = new Date('2026-03-10T13:00:00Z');
const TOMORROW = '2026-03-11';

const USER = {
  id: 'test-user',
  email: 'test@example.com',
  name: 'Test',
  timeZone: ZONE,
  dayStart: DEFAULT_WORK_DAY.start,
  dayEnd: DEFAULT_WORK_DAY.end,
};

class StubSessionGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    context.switchToHttp().getRequest<{ user: unknown }>().user = USER;
    return true;
  }
}

type Step = (messages: ChatMessage[]) => ModelOutcome;

/** A model that says what the test scripted, one step per call. */
class ScriptedModel {
  configured = true;
  model = 'scripted';
  steps: Step[] = [];
  seen: ChatMessage[][] = [];

  generate(messages: ChatMessage[]): Promise<ModelOutcome> {
    this.seen.push([...messages]);
    const step = this.steps.shift();
    if (step === undefined) throw new Error('The model was not scripted');

    return Promise.resolve(step(messages));
  }
}

function call(name: string, args: object): ModelOutcome {
  return {
    kind: 'tool_calls',
    toolCalls: [
      {
        id: `call-${name}`,
        type: 'function',
        function: { name, arguments: JSON.stringify(args) },
      },
    ],
  };
}

/** The model's answer with one plan block, as `propose_plan` used to take it. */
function propose(args: {
  data?: object;
  changes: object[];
  reply?: string;
}): ModelOutcome {
  return call('answer', {
    ...(args.reply === undefined ? {} : { caption: args.reply }),
    blocks: [{ type: 'plan', data: args.data, changes: args.changes }],
  });
}

function say(content: string): Step {
  return () => ({ kind: 'final', content });
}

/** The ref the board gave the card titled [title], in what the model read. */
function refOf(messages: ChatMessage[], title: string): string {
  const read = messages.map((it) => it.content).join('\n');
  const found = new RegExp(`\\b([teb]\\d+) · ${title} ·`).exec(read);
  if (found === null) throw new Error(`No ref for "${title}"`);
  return found[1];
}

/** What the last tool answered, as the model reads it. */
function lastTool(messages: ChatMessage[]): Record<string, unknown> {
  const tool = [...messages].reverse().find((it) => it.role === 'tool');
  return JSON.parse(tool?.content ?? '{}') as Record<string, unknown>;
}

/** The components of a turn's surface, in order, each with its data. */
function drawn(
  reply: AgentReply,
): { component: string; [key: string]: unknown }[] {
  const components = reply.ui.flatMap((it) =>
    'updateComponents' in it ? it.updateComponents.components : [],
  ) as { id: string; component: string; children?: string[] }[];
  const data = (
    reply.ui.find((it) => 'updateDataModel' in it) as {
      updateDataModel: { value: Record<string, unknown> };
    }
  ).updateDataModel.value;
  const root = components.find((it) => it.id === 'root')!;

  return root.children!.map((id) => {
    const it = components.find((c) => c.id === id)!;
    return { ...it, data: data[id], items: data[`${id}items`] };
  });
}

/** The ref of the artifact titled [title], in what the model read. */
function artifactRef(messages: ChatMessage[], title: string): string {
  const read = messages.map((it) => it.content).join('\n');
  const found = new RegExp(`\\b(p\\d+) · ${title} ·`).exec(read);
  if (found === null) throw new Error(`No artifact "${title}"`);
  return found[1];
}

beforeAll(() => {
  jest.useFakeTimers({
    now: NOW,
    doNotFake: [
      'clearImmediate',
      'clearInterval',
      'clearTimeout',
      'hrtime',
      'nextTick',
      'performance',
      'queueMicrotask',
      'setImmediate',
      'setInterval',
      'setTimeout',
    ],
  });
});

afterAll(() => {
  jest.useRealTimers();
});

describe('the agent', () => {
  let app: INestApplication<App>;
  let model: ScriptedModel;

  beforeEach(async () => {
    model = new ScriptedModel();
    const moduleRef = await Test.createTestingModule({
      imports: [ConfigModule.forRoot({ ignoreEnvFile: true })],
      controllers: [
        AgentController,
        TimelineController,
        TasksController,
        EventsController,
      ],
      providers: [
        AgentService,
        TimelineService,
        EventLayoutService,
        PauseTickerService,
        CalendarService,
        { provide: OpenRouterClient, useValue: model },
        { provide: CalendarStore, useClass: MemoryCalendarStore },
        { provide: TaskStore, useClass: MemoryTaskStore },
        { provide: ArtifactStore, useClass: MemoryArtifactStore },
        { provide: ConversationStore, useClass: MemoryConversationStore },
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

  const post = (path: string, payload?: object) =>
    request(app.getHttpServer()).post(path).send(payload);

  const day = async (): Promise<Timeline> =>
    (await request(app.getHttpServer()).get('/timeline?days=3'))
      .body as Timeline;

  const ask = (text: string) =>
    post('/agent/turn', { messages: [{ role: 'user', text }] });

  const task = (title: string, minutes: number, backlog = false) =>
    post('/tasks', { title, minutes, backlog });

  const event = (title: string, start: string, minutes = 60) =>
    post('/events', {
      title,
      durationMinutes: minutes,
      startTime: new Date(start).toISOString(),
    });

  /** Scripts the plan in the mockup: two hours of study, e-mails after. */
  function scriptStudyPlan(): void {
    model.steps = [
      (messages) =>
        propose({
          data: { what: 'estudo', when: 'amanhã de manhã', minutes: 120 },
          changes: [
            {
              do: 'at_hour',
              new: { title: 'Estudo: Flutter', minutes: 120 },
              day: 'amanhã',
              time: '08:00',
            },
            {
              do: 'at_hour',
              ref: refOf(messages, 'Responder e-mails'),
              day: TOMORROW,
              time: '10:05',
            },
          ],
          reply: 'Fica assim amanhã: estudo às 08:00 e e-mails depois.',
        }),
    ];
  }

  it('proposes a plan and changes nothing until it is applied', async () => {
    await task('Responder e-mails', 30, true);
    scriptStudyPlan();

    const turn = await ask('Encaixa 2h de estudo amanhã de manhã');
    const reply = turn.body as AgentReply;

    expect(turn.status).toBe(201);
    expect(reply.reply).toContain('Fica assim');
    expect(reply.steps).toEqual([
      'Amanhã é qua 11/03',
      'Achei Responder e-mails · tarefa · Depois eu priorizo',
    ]);
    expect(reply.plan?.changes.map((it) => it.kind)).toEqual([
      'add_task',
      'move_task',
    ]);
    // Nothing pushed: the plan is the answer, in one call.
    expect(model.seen).toHaveLength(1);

    const before = await day();
    expect(before.tasks.map((it) => it.title)).not.toContain('Estudo: Flutter');
    expect(before.backlog.map((it) => it.title)).toEqual(['Responder e-mails']);
  });

  it('applies a plan whole, and undoes it whole', async () => {
    await task('Responder e-mails', 30, true);
    scriptStudyPlan();
    const plan = ((await ask('Encaixa 2h de estudo')).body as AgentReply).plan!;

    const applied = await post(`/agent/plans/${plan.id}/apply?days=3`);
    const after = applied.body as Timeline & { touched: string[] };

    expect(applied.status).toBe(201);
    expect(after.touched).toHaveLength(2);
    expect(after.backlog).toEqual([]);
    const study = after.tasks.find((it) => it.title === 'Estudo: Flutter');
    expect(study?.startTime).toBe(
      new Date(`${TOMORROW}T08:00:00-03:00`).toISOString(),
    );
    const emails = after.tasks.find((it) => it.title === 'Responder e-mails');
    expect(emails?.startTime).toBe(
      new Date(`${TOMORROW}T10:05:00-03:00`).toISOString(),
    );
    // The card showed what applying made.
    expect(plan.changes.map((it) => it.at)).toEqual([
      study?.startTime,
      emails?.startTime,
    ]);

    const twice = await post(`/agent/plans/${plan.id}/apply`);
    expect(twice.status).toBe(409);
    expect((twice.body as { kind: string }).kind).toBe('refused');

    const undone = (await post(`/agent/plans/${plan.id}/undo?days=3`))
      .body as Timeline;
    expect(undone.tasks.map((it) => it.title)).toEqual([]);
    expect(undone.backlog.map((it) => it.title)).toEqual(['Responder e-mails']);

    expect((await post(`/agent/plans/${plan.id}/undo`)).status).toBe(404);

    // Undone, it is a proposal again.
    const again = (await post(`/agent/plans/${plan.id}/apply?days=3`))
      .body as Timeline;
    expect(again.tasks.map((it) => it.title)).toEqual([
      'Estudo: Flutter',
      'Responder e-mails',
    ]);
  });

  it('puts a task between two others as a place in the queue, as a drag does', async () => {
    await task('Ler artigo', 30);
    await task('Responder e-mails', 30);
    model.steps = [
      (messages) =>
        propose({
          data: { what: 'revisar proposta', relation: 'entre' },
          changes: [
            {
              do: 'place',
              new: { title: 'Revisar proposta', minutes: 45 },
              after: refOf(messages, 'Ler artigo'),
              before: refOf(messages, 'Responder e-mails'),
            },
          ],
          reply: 'Fica entre os dois.',
        }),
    ];

    const reply = (await ask('Revisar proposta entre o artigo e os e-mails'))
      .body as AgentReply;
    const change = reply.plan!.changes[0];
    expect(change.kind).toBe('add_task');
    expect(change.place).toEqual({
      after: 'Ler artigo',
      before: 'Responder e-mails',
    });
    expect(change.at).toBe(new Date('2026-03-10T10:35:00-03:00').toISOString());
    // What it pushes is on the card, which asks: one call.
    expect(reply.reply).toBe('Fica entre os dois.');
    expect(reply.plan!.pushed.map((it) => [it.title, it.at])).toEqual([
      [
        'Responder e-mails',
        new Date('2026-03-10T11:25:00-03:00').toISOString(),
      ],
    ]);
    expect(model.seen).toHaveLength(1);

    const after = (await post(`/agent/plans/${reply.plan!.id}/apply?days=3`))
      .body as Timeline;
    expect(after.tasks.map((it) => [it.title, it.notBefore])).toEqual([
      ['Ler artigo', undefined],
      ['Revisar proposta', undefined],
      ['Responder e-mails', undefined],
    ]);
  });

  it('moves a fixed block to another day by its ref, naming the day', async () => {
    await event('Dentista', '2026-03-10T16:00:00-03:00');
    model.steps = [
      (messages) =>
        propose({
          data: { what: 'dentista', when: 'amanhã às 9' },
          changes: [
            {
              do: 'at_hour',
              ref: refOf(messages, 'Dentista'),
              day: 'amanhã',
              time: '09:00',
            },
          ],
          reply: 'Passei o Dentista para amanhã às 09:00.',
        }),
    ];

    const reply = (await ask('Passa o dentista pra amanhã às 9'))
      .body as AgentReply;

    expect(reply.steps).toEqual([
      'Achei Dentista · bloco fixo · hoje 16:00',
      'Amanhã é qua 11/03',
    ]);
    expect(reply.plan?.changes[0]).toMatchObject({
      kind: 'move_event',
      at: new Date(`${TOMORROW}T09:00:00-03:00`).toISOString(),
      before: new Date('2026-03-10T16:00:00-03:00').toISOString(),
    });
    expect(model.seen).toHaveLength(1);
  });

  it('asks once when something new is named like a card already there', async () => {
    await event('Dentista', '2026-03-10T16:00:00-03:00');
    model.steps = [
      () =>
        propose({
          data: { what: 'dentista', when: 'amanhã às 9' },
          changes: [
            {
              do: 'at_hour',
              new: { title: 'dentista', minutes: 60, fixed: true },
              day: 'amanhã',
              time: '09:00',
            },
          ],
          reply: 'Marquei.',
        }),
    ];

    const reply = (await ask('Marca dentista amanhã às 9')).body as AgentReply;

    expect(model.seen).toHaveLength(1);
    expect(reply.plan).toBeUndefined();
    expect(reply.reply).toBe(
      'Você já tem Dentista hoje às 16:00. É esse que vai para amanhã às 09:00, ou é outro compromisso?',
    );
    expect(reply.steps).toContain(
      'Já existe Dentista · bloco fixo · hoje 16:00',
    );
    expect(reply.options.map((it) => it.label)).toEqual([
      'Mover o de hoje',
      'É outro, marcar mais um',
    ]);

    const [move, other] = reply.options;
    const after = (await post(`/agent/plans/${move.plan.id}/apply?days=3`))
      .body as Timeline;
    expect(
      after.cards
        .filter((it) => it.title === 'Dentista')
        .map((it) => it.startTime),
    ).toEqual([new Date(`${TOMORROW}T09:00:00-03:00`).toISOString()]);

    // One answer is taken: the other is not made as well.
    const both = await post(`/agent/plans/${other.plan.id}/apply`);
    expect(both.status).toBe(409);
  });

  it('proposes an hour for something new with no hour said, and offers the backlog', async () => {
    model.steps = [
      () =>
        propose({
          data: { what: 'treinar' },
          changes: [{ do: 'first_free', new: { title: 'Treinar' } }],
          reply: 'Que tal agora às 10:00? Está livre.',
        }),
    ];

    const reply = (await ask('Preciso treinar')).body as AgentReply;

    expect(reply.plan?.changes[0]).toMatchObject({
      kind: 'add_task',
      minutes: 30,
      at: NOW.toISOString(),
    });
    expect(reply.plan?.assumed).toEqual([
      { kind: 'minutes', minutes: 30 },
      { kind: 'today' },
    ]);
    expect(reply.options.map((it) => it.label)).toEqual(['Deixar para depois']);
    expect(reply.options[0].plan.changes[0].kind).toBe('to_backlog');

    const after = (
      await post(`/agent/plans/${reply.options[0].plan.id}/apply?days=3`)
    ).body as Timeline;
    expect(after.backlog.map((it) => it.title)).toEqual(['Treinar']);
    expect(after.tasks).toEqual([]);
    expect((await post(`/agent/plans/${reply.plan!.id}/apply`)).status).toBe(
      409,
    );
  });

  it('hands a bad proposal back to the model instead of filing it', async () => {
    model.steps = [
      () =>
        propose({
          data: {},
          changes: [{ do: 'at_hour', ref: 't9', day: 'amanhã', time: '09:00' }],
          reply: 'Feito.',
        }),
      (messages) => {
        expect(lastTool(messages).error).toContain('No card "t9"');
        return { kind: 'final', content: 'Não achei essa tarefa.' };
      },
    ];

    const reply = (await ask('Move a tarefa X')).body as AgentReply;

    expect(reply.reply).toBe('Não achei essa tarefa.');
    expect(reply.plan).toBeUndefined();
  });

  it('refuses an hour in the past', async () => {
    model.steps = [
      () =>
        propose({
          data: {},
          changes: [
            {
              do: 'at_hour',
              new: { title: 'Ontem', minutes: 30 },
              day: 'hoje',
              time: '09:00',
            },
          ],
          reply: 'Feito.',
        }),
      (messages) => {
        expect(lastTool(messages).error).toContain('already passed');
        return { kind: 'final', content: 'Esse horário já passou.' };
      },
    ];

    expect(((await ask('Hoje às 9')).body as AgentReply).plan).toBeUndefined();
  });

  it('refuses a task at an hour an event keeps, so the model asks', async () => {
    await event('Reunião', '2026-03-10T15:00:00-03:00');
    model.steps = [
      () =>
        propose({
          data: {},
          changes: [
            {
              do: 'at_hour',
              new: { title: 'Ligar pro banco', minutes: 30 },
              day: 'hoje',
              time: '15:00',
            },
          ],
          reply: 'Feito.',
        }),
      (messages) => {
        expect(lastTool(messages).error).toContain('"Reunião"');
        expect(lastTool(messages).error).toContain('never pushed');
        return { kind: 'final', content: 'Às 15:00 tem a Reunião.' };
      },
    ];

    expect(
      ((await ask('Banco às 15h')).body as AgentReply).plan,
    ).toBeUndefined();
  });

  it('refuses a fixed block on top of another, so the model asks', async () => {
    await event('Reunião', '2026-03-10T15:00:00-03:00');
    model.steps = [
      () =>
        propose({
          data: {},
          changes: [
            {
              do: 'at_hour',
              new: { title: 'Ligar pro banco', minutes: 30, fixed: true },
              day: 'hoje',
              time: '15:00',
            },
          ],
          reply: 'Feito.',
        }),
      (messages) => {
        expect(lastTool(messages).error).toContain('two things at once');
        return {
          kind: 'final',
          content: 'Às 15:00 tem a Reunião. Outro horário?',
        };
      },
    ];

    expect(
      ((await ask('Banco às 15h')).body as AgentReply).plan,
    ).toBeUndefined();
  });

  it('shows what a plan pushes later, as the queue would', async () => {
    await task('Revisar proposta', 60);
    await task('Responder e-mails', 30);
    model.steps = [
      () =>
        propose({
          data: { what: 'dentista', when: '10:30' },
          changes: [
            {
              do: 'at_hour',
              new: { title: 'Dentista', minutes: 60, fixed: true },
              day: 'hoje',
              time: '10:30',
            },
          ],
          reply: 'Dentista às 10:30.',
        }),
      (messages) => {
        expect(lastTool(messages).pushed).toEqual([
          { title: 'Revisar proposta', from: 'hoje 10:00', to: 'hoje 11:35' },
          { title: 'Responder e-mails', from: 'hoje 11:05', to: 'hoje 12:40' },
        ]);
        return {
          kind: 'final',
          content: 'Quer que eu coloque o Dentista às 10:30 e mova o resto?',
        };
      },
    ];

    const plan = ((await ask('Dentista às 10:30')).body as AgentReply).plan!;
    expect(plan.pushed.map((it) => it.title)).toEqual([
      'Revisar proposta',
      'Responder e-mails',
    ]);

    // Applied, the day is what the plan showed.
    const after = (await post(`/agent/plans/${plan.id}/apply?days=3`))
      .body as Timeline;
    expect(after.tasks.map((it) => [it.title, it.startTime])).toEqual([
      ['Revisar proposta', plan.pushed[0].at],
      ['Responder e-mails', plan.pushed[1].at],
    ]);
  });

  it('says what kind of failure it was, with the trace', async () => {
    model.steps = [
      () => {
        throw new ModelUnavailableError('down', 502);
      },
    ];
    const down = await ask('Oi');
    expect(down.status).toBe(503);
    expect(down.body).toMatchObject({ kind: 'model_down' });
    expect((down.body as { traceId: string }).traceId).toMatch(/\w+/);

    // The day changed under a plan: Aplicar says so, and makes nothing.
    await task('Responder e-mails', 30);
    scriptStudyPlanFor('Responder e-mails');
    const plan = ((await ask('Move os e-mails')).body as AgentReply).plan!;
    const emails = (await day()).tasks[0];
    await request(app.getHttpServer()).delete(`/tasks/${emails.id}`);

    const drift = await post(`/agent/plans/${plan.id}/apply`);
    expect(drift.status).toBe(409);
    expect(drift.body).toMatchObject({ kind: 'drift' });
  });

  /** A plan that gives [title] an hour tomorrow. */
  function scriptStudyPlanFor(title: string): void {
    model.steps = [
      (messages) =>
        propose({
          data: {},
          changes: [
            {
              do: 'at_hour',
              ref: refOf(messages, title),
              day: 'amanhã',
              time: '09:00',
            },
          ],
          reply: 'Amanhã às 09:00.',
        }),
    ];
  }

  it('tells the model when it is, which day is which, and what the screen shows', async () => {
    model.steps = [say('Oi!')];

    await post('/agent/turn', {
      messages: [{ role: 'user', text: 'Oi' }],
      day: TOMORROW,
    });

    const context = model.seen[0][model.seen[0].length - 1].content;
    expect(context).toContain('Now: Tue 2026-03-10 10:00 (America/Sao_Paulo)');
    expect(context).toContain('- amanhã = Wed 2026-03-11');
    expect(context).toContain(`showing ${TOMORROW}`);
    expect(context).toMatch(/Request: Oi$/);
  });

  it('tells the model which task the person is on, with its notes', async () => {
    const id = ((await task('Escrever relatório', 60)).body as Timeline)
      .tasks[0].id;
    await request(app.getHttpServer())
      .patch(`/tasks/${id}`)
      .send({ notes: 'Começar pelos números.\n\nMandar até sexta.' });
    model.steps = [say('Certo.')];

    const turn = await post('/agent/turn', {
      messages: [{ role: 'user', text: 'Quanto tempo isso leva?' }],
      about: { taskId: id },
    });

    expect(turn.status).toBe(201);
    const context = model.seen[0][model.seen[0].length - 1].content;
    expect(context).toMatch(
      /The person is on this task’s page:\n {2}t1 · Escrever relatório · task/,
    );
    expect(context).toContain(
      '    Começar pelos números.\n    \n    Mandar até sexta.',
    );
    expect(context).toMatch(/Request: Quanto tempo isso leva\?$/);
  });

  it('tells the model which artifact the person is on, with its tasks', async () => {
    const artifacts = app.get(ArtifactStore);
    const tasks = app.get(TaskStore);
    const artifact = await artifacts.insert(USER, {
      title: 'Mudança',
      deadline: '2026-04-01',
    });
    await artifacts.update(USER, { ...artifact, notes: 'Caixas no sábado.' });
    const id = ((await task('Orçar frete', 30, true)).body as Timeline)
      .backlog[0].id;
    await tasks.update(USER, {
      ...(await tasks.get(USER, id))!,
      artifactId: artifact.id,
    });
    model.steps = [say('Certo.')];

    await post('/agent/turn', {
      messages: [{ role: 'user', text: 'O que falta?' }],
      about: { artifactId: artifact.id },
    });

    const context = model.seen[0][model.seen[0].length - 1].content;
    expect(context).toContain(
      'The person is on this artifact’s page:\n  p1 · artifact “Mudança”, due 2026-04-01\n  Notes:\n    Caixas no sábado.\n  Its tasks:\n    b1 · Orçar frete · backlog task · 30 min · artifact Mudança',
    );
    // From anywhere, the board's index names it.
    expect(context).toContain(
      'Artifacts (read_cards with an artifact ref reads its notes and every task):\n  p1 · Mudança · due 01/04 · 1 open tasks, 0 with an hour',
    );
  });

  it('refuses a subject that is not there, or is not one', async () => {
    const missing = await post('/agent/turn', {
      messages: [{ role: 'user', text: 'Oi' }],
      about: { taskId: '00000000-0000-4000-8000-000000000000' },
    });
    expect(missing.status).toBe(404);
    expect(missing.body).toMatchObject({
      kind: 'refused',
      message: 'Não encontrei essa tarefa.',
    });

    for (const about of [
      { taskId: 'nope' },
      { taskId: '00000000-0000-4000-8000-000000000000', artifactId: 'x' },
      'tarefa',
    ]) {
      const bad = await post('/agent/turn', {
        messages: [{ role: 'user', text: 'Oi' }],
        about,
      });
      expect(bad.status).toBe(400);
    }
    expect(model.seen).toHaveLength(0);
  });

  it('reads other days by the word the person used', async () => {
    await event('Reunião de pauta', '2026-03-13T14:00:00-03:00');
    model.steps = [
      () => call('read_timeline', { day: 'sexta' }),
      (messages) => {
        const read = lastTool(messages).day as string;
        expect(read).toContain('2026-03-13');
        expect(read).toMatch(
          /e1 · Reunião de pauta · fixed event · sex 13\/03 14:00–15:00/,
        );
        return { kind: 'final', content: 'Sexta tem a reunião às 14:00.' };
      },
    ];

    const reply = (await ask('O que tem sexta?')).body as AgentReply;
    expect(reply.steps).toEqual(['Olhei sex 13/03']);
  });

  it('suggests fitting the first backlog task into today', async () => {
    await post('/tasks', { title: 'Relatório mensal', minutes: 90 });

    const response = await request(app.getHttpServer()).get(
      '/agent/suggestion',
    );
    const { suggestion } = response.body as {
      suggestion: { text: string; plan: AgentReply['plan'] };
    };

    expect(suggestion.text).toContain('Relatório mensal');
    expect(suggestion.text).toContain('10:00');
    expect(suggestion.plan?.changes[0].kind).toBe('move_task');

    // Asked again, it is the same offer, not a second one.
    const again = await request(app.getHttpServer()).get('/agent/suggestion');
    expect(
      (again.body as { suggestion: { plan: { id: string } } }).suggestion.plan
        .id,
    ).toBe(suggestion.plan?.id);

    const applied = (await post(`/agent/plans/${suggestion.plan?.id}/apply`))
      .body as Timeline;
    expect(applied.backlog).toEqual([]);
    expect(applied.tasks.map((it) => it.title)).toEqual(['Relatório mensal']);
  });

  it('has nothing to suggest with an empty backlog', async () => {
    const response = await request(app.getHttpServer()).get(
      '/agent/suggestion',
    );

    expect(response.body).toEqual({ suggestion: null });
  });

  it('refuses a conversation that does not end with the user', async () => {
    const response = await post('/agent/turn', {
      messages: [{ role: 'assistant', text: 'Oi' }],
    });

    expect(response.status).toBe(400);
  });

  const history = async (): Promise<Conversation[]> =>
    (
      (await request(app.getHttpServer()).get('/agent/conversations')).body as {
        conversations: Conversation[];
      }
    ).conversations;

  it('writes each turn into its conversation, and tells the model only that one', async () => {
    model.steps = [say('Oi! Como posso ajudar?')];
    const first = (await ask('Oi')).body as AgentReply;
    expect(first.conversationId).toMatch(/^[0-9a-f-]{36}$/);

    jest.setSystemTime(new Date(NOW.getTime() + 10_000));
    model.steps = [say('Às 18:30.')];
    await post('/agent/turn', {
      conversationId: first.conversationId,
      messages: [
        { role: 'user', text: 'Oi' },
        { role: 'assistant', text: 'Oi! Como posso ajudar?' },
        { role: 'user', text: 'Que horas é a academia?', voice: 4.2 },
      ],
    });

    jest.setSystemTime(new Date(NOW.getTime() + 60_000));
    model.steps = [say('Claro.')];
    const other = (await ask('Outra coisa')).body as AgentReply;
    jest.setSystemTime(NOW);
    expect(other.conversationId).not.toBe(first.conversationId);

    // A new conversation starts with nothing of the old one.
    const told = model.seen[model.seen.length - 1].filter(
      (it) => it.role !== 'system',
    );
    expect(told).toHaveLength(1);
    expect(told[0].content).toMatch(/Request: Outra coisa$/);

    const past = await history();
    expect(past.map((it) => it.messages.length)).toEqual([2, 4]);
    expect(past[1].id).toBe(first.conversationId);
    expect(past[1].messages.map((it) => it.text)).toEqual([
      'Oi',
      'Oi! Como posso ajudar?',
      'Que horas é a academia?',
      'Às 18:30.',
    ]);
    expect(past[1].messages[2].voiceSeconds).toBe(4);
  });

  it('pages the history back from an instant', async () => {
    model.steps = [say('Um.')];
    await ask('Primeira');
    jest.setSystemTime(new Date(NOW.getTime() + 60_000));
    model.steps = [say('Dois.')];
    await ask('Segunda');
    jest.setSystemTime(NOW);

    const page = (
      await request(app.getHttpServer()).get(
        `/agent/conversations?limit=1&before=${new Date(NOW.getTime() + 30_000).toISOString()}`,
      )
    ).body as { conversations: Conversation[] };

    expect(page.conversations.map((it) => it.messages[0].text)).toEqual([
      'Primeira',
    ]);
    expect(
      (await request(app.getHttpServer()).get('/agent/conversations?limit=0'))
        .status,
    ).toBe(400);
  });

  it('keeps what became of each plan in the history', async () => {
    await task('Responder e-mails', 30, true);
    scriptStudyPlan();
    const plan = ((await ask('Encaixa 2h de estudo')).body as AgentReply).plan!;

    expect((await history())[0].messages[1].planStatus).toBe('proposed');
    await post(`/agent/plans/${plan.id}/apply`);
    expect((await history())[0].messages[1].planStatus).toBe('applied');
    await post(`/agent/plans/${plan.id}/undo`);
    expect((await history())[0].messages[1].planStatus).toBe('undone');
  });

  it('looks earlier conversations up only through its tool', async () => {
    model.steps = [say('Fica às 18:30.')];
    await ask('Passa a academia pras 18:30');

    model.steps = [
      () => call('read_conversations', { text: 'ACADEMIA' }),
      (messages) => {
        const found = lastTool(messages) as {
          messages: { role: string; text: string; at: string }[];
        };
        expect(found.messages.map((it) => it.text)).toEqual([
          'Passa a academia pras 18:30',
        ]);
        expect(found.messages[0].at).toBe('2026-03-10T10:00');
        return { kind: 'final', content: 'Você pediu 18:30.' };
      },
    ];
    const reply = (await ask('O que eu pedi sobre a academia?'))
      .body as AgentReply;

    expect(reply.steps).toEqual(['Procurei nas conversas: "ACADEMIA"']);
  });

  it('says so when no model is configured', async () => {
    model.configured = false;

    const response = await ask('Oi');

    expect(response.status).toBe(503);
    expect(response.body).toMatchObject({ kind: 'model_down' });
    expect((response.body as { message: string }).message).toContain(
      'não está conectada',
    );
  });
  describe('the answer as a surface', () => {
    it('answers the afternoon as a slice of the day, with two ways to tap', async () => {
      await task('Ler artigo', 30);
      await event('Reunião', '2026-03-10T14:00:00-03:00');
      model.steps = [
        (messages) =>
          call('answer', {
            caption: 'Sua tarde tem duas janelas.',
            blocks: [
              { type: 'day', day: 'hoje', from: '13:00', to: '18:00' },
              {
                type: 'choices',
                options: [
                  {
                    label: 'Ler às 15:30',
                    changes: [
                      {
                        do: 'at_hour',
                        ref: refOf(messages, 'Ler artigo'),
                        day: 'hoje',
                        time: '15:30',
                      },
                    ],
                  },
                  { label: 'Só amanhã', say: 'Deixa o artigo para amanhã' },
                ],
              },
            ],
          }),
      ];

      const reply = (await ask('Como está minha tarde?')).body as AgentReply;

      expect(reply.ui[0]).toEqual({
        version: 'v0.9',
        createSurface: {
          surfaceId: expect.stringMatching(/^turn-/) as string,
          catalogId: 'https://lunna.pietroteruya.dev/a2ui/v1/catalog.json',
        },
      });
      const [caption, slice, choices] = drawn(reply);
      expect(drawn(reply).map((it) => it.component)).toEqual([
        'Caption',
        'DayPeek',
        'Choices',
      ]);
      expect(caption.text).toBe('Sua tarde tem duas janelas.');
      const at = (hhmm: string) =>
        new Date(`2026-03-10T${hhmm}:00-03:00`).toISOString();
      expect(slice.items).toEqual([
        { kind: 'free', title: '', start: at('13:00'), end: at('13:55') },
        {
          kind: 'fixed',
          title: 'Reunião',
          start: at('14:00'),
          end: at('15:00'),
        },
        { kind: 'free', title: '', start: at('15:05'), end: at('18:00') },
      ]);

      const [read, later] = choices.data as {
        label: string;
        plan?: { id: string };
        say?: string;
        action: { event: { name: string; context: object } };
      }[];
      expect(read.action.event).toEqual({
        name: 'choose',
        context: { planId: read.plan!.id },
      });
      expect(later).toMatchObject({
        say: 'Deixa o artigo para amanhã',
        action: {
          event: {
            name: 'choose',
            context: { say: 'Deixa o artigo para amanhã' },
          },
        },
      });
      // Older builds: only what carries a plan, and the caption as the reply.
      expect(reply.options.map((it) => it.label)).toEqual(['Ler às 15:30']);
      expect(reply.reply).toBe('Sua tarde tem duas janelas.');
      expect(model.seen).toHaveLength(1);

      const after = (await post(`/agent/plans/${read.plan!.id}/apply?days=3`))
        .body as Timeline;
      expect(
        after.tasks.find((it) => it.title === 'Ler artigo')?.startTime,
      ).toBe(at('15:30'));
    });

    it('draws an artifact from anywhere: its counts, and what comes next by hour first', async () => {
      const artifacts = app.get(ArtifactStore);
      const tasks = app.get(TaskStore);
      const artifact = await artifacts.insert(USER, {
        title: 'Tese',
        deadline: '2026-04-30',
      });
      const into = async (title: string, backlog: boolean, done = false) => {
        const body = (await task(title, 45, backlog)).body as Timeline;
        const id = [...body.tasks, ...body.backlog].find(
          (it) => it.title === title,
        )!.id;
        await tasks.update(USER, {
          ...(await tasks.get(USER, id))!,
          artifactId: artifact.id,
          ...(done ? { doneAt: NOW.toISOString(), backlog: false } : {}),
        });
      };
      await into('Revisar capítulo 1', true, true);
      await into('Capítulo 2', true);
      await into('Bibliografia', true);
      await into('Reunião com orientador', false);
      model.steps = [
        (messages) =>
          call('answer', {
            blocks: [{ type: 'artifact', ref: artifactRef(messages, 'Tese') }],
          }),
      ];

      const reply = (await ask('Como está a Tese?')).body as AgentReply;

      const [peek] = drawn(reply);
      expect(peek.component).toBe('ArtifactPeek');
      expect(peek.data).toMatchObject({
        id: artifact.id,
        title: 'Tese',
        deadline: '2026-04-30',
        done: 1,
        total: 4,
      });
      expect(
        (peek.data as { next: { title: string; at?: string }[] }).next.map(
          (it) => [it.title, it.at !== undefined],
        ),
      ).toEqual([
        ['Reunião com orientador', true],
        ['Capítulo 2', false],
        ['Bibliografia', false],
      ]);
      // No caption: the reply in words is written by the server.
      expect(reply.reply).toBe('Entrega Tese: 1 de 4 feitas.');
    });

    it('sends an answer with nothing left to draw back to the model', async () => {
      await task('Ler artigo', 30);
      model.steps = [
        () =>
          call('answer', {
            caption:
              'Uma frase longa demais que não cabe na legenda curta que o cartão tem para ela, e ainda continua por mais um pouco.',
            blocks: [{ type: 'cards', refs: ['t99'] }],
          }),
        (messages) => {
          expect(lastTool(messages).error).toMatch(/^Nothing could be drawn: /);
          return call('answer', {
            blocks: [
              {
                type: 'cards',
                title: 'Hoje',
                refs: [refOf(messages, 'Ler artigo')],
              },
            ],
          });
        },
      ];

      const reply = (await ask('O que tenho hoje?')).body as AgentReply;

      const [cards] = drawn(reply);
      expect(cards).toMatchObject({ component: 'Cards', title: 'Hoje' });
      expect((cards.data as { title: string }[]).map((it) => it.title)).toEqual(
        ['Ler artigo'],
      );
    });

    it('names cards by their titles in what the person reads', async () => {
      await task('Ler artigo', 30, true);
      model.steps = [
        (messages) =>
          call('answer', {
            caption: `A ${refOf(messages, 'Ler artigo')} está no backlog.`,
            blocks: [{ type: 'cards', refs: [refOf(messages, 'Ler artigo')] }],
          }),
      ];

      const reply = (await ask('Cadê o artigo?')).body as AgentReply;

      expect(reply.reply).toBe('A Ler artigo está no Depois eu priorizo.');
    });

    it('keeps a ref on the same card from turn to turn', async () => {
      await event('Reunião', '2026-03-10T16:00:00-03:00');
      model.steps = [say('Certo.')];
      const first = (await ask('Oi')).body as AgentReply;
      // Earlier than the Reunião: renumbered by hour, it would be e1.
      await event('Dentista', '2026-03-10T12:00:00-03:00');
      model.steps = [say('Certo.')];

      await post('/agent/turn', {
        conversationId: first.conversationId,
        messages: [
          { role: 'user', text: 'Oi' },
          { role: 'assistant', text: 'Certo.' },
          { role: 'user', text: 'E agora?' },
        ],
      });

      const context = model.seen[1][model.seen[1].length - 1].content;
      expect(context).toContain('e1 · Reunião');
      expect(context).toContain('e2 · Dentista');
    });

    it('reaches a task off the board through its artifact, and moves it like any other', async () => {
      const artifacts = app.get(ArtifactStore);
      const tasks = app.get(TaskStore);
      const artifact = await artifacts.insert(USER, { title: 'Mudança' });
      for (let i = 1; i <= 30; i++) await task(`Coisa ${i}`, 15, true);
      const body = (await task('Orçar frete', 30, true)).body as Timeline;
      const id = body.backlog.find((it) => it.title === 'Orçar frete')!.id;
      await tasks.update(USER, {
        ...(await tasks.get(USER, id))!,
        artifactId: artifact.id,
      });
      model.steps = [
        (messages) => {
          // Past the backlog's first 30, it is not on the board.
          expect(() => refOf(messages, 'Orçar frete')).toThrow();
          return call('read_cards', {
            refs: [artifactRef(messages, 'Mudança')],
          });
        },
        (messages) => {
          expect(lastTool(messages).cards).toContain(
            'b31 · Orçar frete · backlog task · 30 min · artifact Mudança',
          );
          return propose({
            data: { what: 'orçar frete', when: 'amanhã às 9' },
            changes: [
              { do: 'at_hour', ref: 'b31', day: 'amanhã', time: '09:00' },
            ],
          });
        },
      ];

      const reply = (await ask('Põe o frete da mudança amanhã às 9'))
        .body as AgentReply;

      expect(reply.steps).toContain('Li Mudança');
      const after = (await post(`/agent/plans/${reply.plan!.id}/apply?days=3`))
        .body as Timeline;
      expect(
        after.tasks.find((it) => it.title === 'Orçar frete')?.startTime,
      ).toBe(new Date(`${TOMORROW}T09:00:00-03:00`).toISOString());
    });
  });
});
