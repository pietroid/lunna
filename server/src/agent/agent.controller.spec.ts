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
  OpenRouterClient,
} from './openrouter.client';

const ZONE = 'America/Sao_Paulo';
/** Tuesday 10 March 2026, ten in the morning in São Paulo. */
const NOW = new Date('2026-03-10T13:00:00Z');
const TOMORROW = '2026-03-11';

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

function say(content: string): Step {
  return () => ({ kind: 'final', content });
}

/** What the last tool answered, as the model reads it. */
function lastTool(messages: ChatMessage[]): Record<string, unknown> {
  const tool = [...messages].reverse().find((it) => it.role === 'tool');
  return JSON.parse(tool?.content ?? '{}') as Record<string, unknown>;
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
        { provide: ConversationStore, useClass: MemoryConversationStore },
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

  const post = (path: string, payload?: object) =>
    request(app.getHttpServer()).post(path).send(payload);

  const day = async (): Promise<Timeline> =>
    (await request(app.getHttpServer()).get('/timeline?days=3'))
      .body as Timeline;

  const ask = (text: string) =>
    post('/agent/turn', { messages: [{ role: 'user', text }] });

  /** Scripts the plan in the mockup: two hours of study, e-mails after. */
  function scriptStudyPlan(): void {
    model.steps = [
      () => call('read_timeline', { from: TOMORROW }),
      (messages) => {
        const read = lastTool(messages) as {
          items: { id: string; title: string }[];
          backlog: { id: string; title: string }[];
        };
        const emails = [...read.items, ...read.backlog].find(
          (it) => it.title === 'Responder e-mails',
        );

        return call('propose_plan', {
          findings: ['Achei 08:00–10:00 livre'],
          changes: [
            {
              kind: 'add_task',
              title: 'Estudo: Flutter',
              minutes: 120,
              at: `${TOMORROW}T08:00`,
            },
            { kind: 'move_task', id: emails?.id, at: `${TOMORROW}T10:05` },
          ],
        });
      },
      say('Fica assim amanhã: estudo às 08:00 e e-mails depois.'),
    ];
  }

  it('proposes a plan and changes nothing until it is applied', async () => {
    await post('/tasks', { title: 'Responder e-mails', minutes: 30 });
    scriptStudyPlan();

    const turn = await ask('Encaixa 2h de estudo amanhã de manhã');
    const reply = turn.body as AgentReply;

    expect(turn.status).toBe(201);
    expect(reply.reply).toContain('Fica assim');
    expect(reply.steps).toEqual(['Olhei amanhã', 'Achei 08:00–10:00 livre']);
    expect(reply.plan?.changes.map((it) => it.kind)).toEqual([
      'add_task',
      'move_task',
    ]);

    const before = await day();
    expect(before.tasks.map((it) => it.title)).not.toContain('Estudo: Flutter');
    expect(before.backlog.map((it) => it.title)).toEqual(['Responder e-mails']);
  });

  it('applies a plan whole, and undoes it whole', async () => {
    await post('/tasks', { title: 'Responder e-mails', minutes: 30 });
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

    expect((await post(`/agent/plans/${plan.id}/apply`)).status).toBe(409);

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

  it('hands a bad proposal back to the model instead of filing it', async () => {
    model.steps = [
      () =>
        call('propose_plan', {
          changes: [{ kind: 'move_task', id: 'nope', at: `${TOMORROW}T09:00` }],
        }),
      (messages) => {
        expect(lastTool(messages).error).toContain('No task');
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
        call('propose_plan', {
          changes: [
            {
              kind: 'add_task',
              title: 'Ontem',
              minutes: 30,
              at: '2026-03-09T09:00',
            },
          ],
        }),
      (messages) => {
        expect(lastTool(messages).error).toContain('in the past');
        return { kind: 'final', content: 'Esse horário já passou.' };
      },
    ];

    expect(((await ask('Ontem às 9')).body as AgentReply).plan).toBeUndefined();
  });

  it('tells the model when it is and what the screen shows', async () => {
    model.steps = [say('Oi!')];

    await post('/agent/turn', {
      messages: [{ role: 'user', text: 'Oi' }],
      day: TOMORROW,
    });

    const context = model.seen[0][1].content;
    expect(context).toContain('2026-03-10T10:00');
    expect(context).toContain('Tuesday');
    expect(context).toContain(`showing ${TOMORROW}`);
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
    const told = model.seen[model.seen.length - 1];
    expect(told.filter((it) => it.role !== 'system')).toEqual([
      { role: 'user', content: 'Outra coisa' },
    ]);

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
    await post('/tasks', { title: 'Responder e-mails', minutes: 30 });
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

  it('tells the model the minute it is in every read', async () => {
    model.steps = [
      () => call('read_timeline', {}),
      (messages) => {
        expect(lastTool(messages).now).toBe('2026-03-10T10:00');
        return { kind: 'final', content: 'Ok.' };
      },
    ];

    await ask('Como está meu dia?');
  });

  it('shows what a plan pushes later, as the queue would', async () => {
    await post('/tasks', {
      title: 'Revisar proposta',
      minutes: 60,
      backlog: false,
    });
    await post('/tasks', {
      title: 'Responder e-mails',
      minutes: 30,
      backlog: false,
    });
    model.steps = [
      () =>
        call('propose_plan', {
          changes: [
            {
              kind: 'add_event',
              title: 'Dentista',
              minutes: 60,
              at: '2026-03-10T10:30',
            },
          ],
        }),
      (messages) => {
        expect(lastTool(messages).pushed).toEqual([
          {
            title: 'Revisar proposta',
            from: '2026-03-10T10:00',
            to: '2026-03-10T11:35',
          },
          {
            title: 'Responder e-mails',
            from: '2026-03-10T11:05',
            to: '2026-03-10T12:40',
          },
        ]);
        return {
          kind: 'final',
          content: 'Quer que eu coloque o Dentista às 10:30 e empurre o resto?',
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

  it('refuses a task at an hour an event keeps, so the model asks', async () => {
    await post('/events', {
      title: 'Reunião',
      durationMinutes: 60,
      startTime: new Date('2026-03-10T15:00:00-03:00').toISOString(),
    });
    model.steps = [
      () =>
        call('propose_plan', {
          changes: [
            {
              kind: 'add_task',
              title: 'Ligar pro banco',
              minutes: 30,
              at: '2026-03-10T15:00',
            },
          ],
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

  it('says so when no model is configured', async () => {
    model.configured = false;

    const response = await ask('Oi');

    expect(response.status).toBe(503);
    expect((response.body as { message: string }).message).toContain(
      'não está conectada',
    );
  });
});
