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
import { EventLayoutService } from '../events/event-layout.service';
import { TimelineService } from '../events/timeline.service';
import {
  ArtifactStore,
  MemoryArtifactStore,
} from '../artifacts/artifact.store';
import { MemoryTaskStore, TaskStore } from '../tasks/task.store';
import { DEFAULT_WORK_DAY } from '../time/work-hours';
import { AgentService } from './agent.service';
import { ComposeDraft, ComposeService } from './compose';
import { ComposeController } from './compose.controller';
import {
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
  seen: { messages: ChatMessage[]; force?: string }[] = [];

  generate(
    messages: ChatMessage[],
    _tools: unknown,
    options: { force?: string } = {},
  ): Promise<ModelOutcome> {
    this.seen.push({ messages: [...messages], force: options.force });
    const step = this.steps.shift();
    if (step === undefined) throw new Error('The model was not scripted');
    return Promise.resolve(step(messages));
  }
}

function read(args: object): Step {
  return () => ({
    kind: 'tool_calls',
    toolCalls: [
      {
        id: 'call-read',
        type: 'function',
        function: { name: 'read_request', arguments: JSON.stringify(args) },
      },
    ],
  });
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

describe('the composer', () => {
  let app: INestApplication<App>;
  let model: ScriptedModel;
  let artifacts: MemoryArtifactStore;

  beforeEach(async () => {
    model = new ScriptedModel();
    const moduleRef = await Test.createTestingModule({
      imports: [ConfigModule.forRoot({ ignoreEnvFile: true })],
      controllers: [ComposeController],
      providers: [
        ComposeService,
        AgentService,
        TimelineService,
        EventLayoutService,
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

    artifacts = moduleRef.get(ArtifactStore);
    app = moduleRef.createNestApplication();
    await app.listen(0, '127.0.0.1');
  });

  afterEach(async () => {
    await app.close();
  });

  const compose = (text: string) =>
    request(app.getHttpServer()).post('/agent/compose').send({ text });

  const draftOf = (response: { body: unknown }) =>
    (response.body as { draft: ComposeDraft }).draft;

  it('reads an event in one forced call, its hour in the person’s zone', async () => {
    model.steps = [
      read({
        kind: 'event',
        title: 'Dentista',
        day: '2026-03-11',
        time: '15:00',
      }),
    ];

    const draft = draftOf(await compose('dentista amanhã às 15h').expect(201));

    expect(draft).toEqual({
      kind: 'event',
      title: 'Dentista',
      start: new Date('2026-03-11T15:00:00-03:00').toISOString(),
      minutes: 60,
      subtasks: [],
      changes: [],
    });
    expect(model.seen).toHaveLength(1);
    expect(model.seen[0].force).toBe('read_request');
    const context = model.seen[0].messages[0].content;
    expect(context).toContain('2026-03-10');
    expect(context).toContain('Tomorrow is 2026-03-11');
  });

  it('reads a task under a delivery, with its subtasks in order', async () => {
    const post = await artifacts.insert(USER, {
      title: 'Post: Lua cheia em Touro',
      position: 0,
    });
    model.steps = [
      (messages) => {
        expect(messages[0].content).toContain('p1 · Post: Lua cheia em Touro');
        return read({
          kind: 'task',
          title: 'Vídeo',
          minutes: 90,
          parent: 'p1',
          subtasks: [{ title: 'Roteiro' }, { title: 'Gravar', minutes: 30 }],
        })(messages);
      },
    ];

    const draft = draftOf(
      await compose('vídeo pro post de touro, 1h30: roteiro, gravar').expect(
        201,
      ),
    );

    expect(draft).toMatchObject({
      kind: 'task',
      title: 'Vídeo',
      minutes: 90,
      parent: { id: post.id, title: 'Post: Lua cheia em Touro' },
      subtasks: [{ title: 'Roteiro' }, { title: 'Gravar', minutes: 30 }],
    });
    expect(draft.start).toBeUndefined();
  });

  it('reads a goal with its amount and its day', async () => {
    model.steps = [
      read({
        kind: 'goal',
        title: 'Novembro',
        value: 10000,
        day: '2026-11-30',
      }),
    ];

    expect(draftOf(await compose('10 mil até 30/11').expect(201))).toEqual({
      kind: 'goal',
      title: 'Novembro',
      value: 10000,
      due: '2026-11-30',
      subtasks: [],
      changes: [],
    });
  });

  it('hands a bigger request to the agent’s turn', async () => {
    model.steps = [
      read({ kind: 'plan', title: 'reorganizar' }),
      () => ({ kind: 'final', content: 'Posso mover os e-mails para depois.' }),
    ];

    const draft = draftOf(
      await compose('organiza minha tarde e tira os e-mails').expect(201),
    );

    expect(draft.kind).toBe('plan');
    expect(draft.title).toContain('e-mails');
    expect(draft.conversationId).toBeDefined();
    expect(model.seen).toHaveLength(2);
    expect(model.seen[1].force).toBeUndefined();
  });

  it('falls back to the turn when the read fails or is not to be trusted', async () => {
    model.steps = [
      () => {
        throw new ModelUnavailableError('down', 503);
      },
      () => ({ kind: 'final', content: 'Anotei a ideia.' }),
      // An event with no hour is not one.
      read({ kind: 'event', title: 'Reunião' }),
      () => ({ kind: 'final', content: 'Quando é a reunião?' }),
    ];

    expect(draftOf(await compose('algo').expect(201)).kind).toBe('plan');
    expect(draftOf(await compose('reunião').expect(201)).title).toBe(
      'Quando é a reunião?',
    );
  });

  it('refuses an empty line, in Portuguese', async () => {
    const refused = await compose('   ').expect(400);
    expect((refused.body as { message: string }).message).toContain('Escreva');
    expect(model.seen).toHaveLength(0);
  });
});
