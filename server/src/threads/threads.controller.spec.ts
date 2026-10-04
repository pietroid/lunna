// firebase-admin pulls an ESM-only dependency that Jest cannot require on
// Node 22. Nothing here verifies a token, so the module is stubbed and the
// guard it backs is overridden below.
jest.mock('firebase-admin/auth', () => ({ getAuth: jest.fn() }));

import { promises as fs } from 'fs';
import * as os from 'os';
import * as path from 'path';
import {
  CanActivate,
  ExecutionContext,
  INestApplication,
} from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { CalendarReaderService } from '../calendar/calendar-reader.service';
import { systemZone, Zone } from '../time/zone';
import { A2uiParserService } from '../a2ui/a2ui-parser.service';
import { A2uiPromptService } from '../a2ui/a2ui-prompt.service';
import { A2uiValidationService } from '../a2ui/a2ui-validation.service';
import {
  AgentService,
  GenerateResult,
  ToolDescriptor,
  ToolTraceEntry,
} from './agent.service';
import { ThreadsController } from './threads.controller';
import { ThreadsService } from './threads.service';
import { ThreadsStore } from './threads.store';
import { dayFolder } from './thread-markdown';
import { Thread, ThreadItem } from './entities/thread.entity';

/** supertest types `body` as `any`; these keep the assertions typed. */
function thread(response: { body: unknown }): Thread {
  return response.body as Thread;
}

function items(response: { body: unknown }): ThreadItem[] {
  return response.body as ThreadItem[];
}

/** Every string the user would actually read in a rendered message. */
function visibleText(message: { metadata?: { a2ui?: unknown } }): string[] {
  const found: string[] = [];

  const walk = (node: unknown): void => {
    if (node === null || typeof node !== 'object') return;
    const record = node as Record<string, unknown>;

    for (const key of ['text', 'title', 'subtitle']) {
      const value = record[key];
      if (typeof value === 'string' && value !== '') found.push(value);
    }

    for (const child of (record.children as unknown[]) ?? []) walk(child);
  };

  walk(message.metadata?.a2ui);
  return found;
}

/** Signs every request in as a fixed user, standing in for Firebase. */
class StubAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    context.switchToHttp().getRequest<{ user: unknown }>().user = {
      uid: 'test-user',
    };
    return true;
  }
}

/**
 * Stands in for the agent container.
 *
 * It answers with the JSON an obedient model would produce, so these tests
 * exercise the server's own path: prompt, parse, validate, store.
 */
class StubAgentService {
  /** Overridden per test to rehearse a particular model reply. */
  raw = JSON.stringify({
    a2ui: { component: 'Text', text: 'Noted.' },
  });

  /** Overridden per test to rehearse what the tools did. */
  toolTrace: ToolTraceEntry[] = [];

  /** What the server said this turn was allowed to do, per call. */
  readonly allowWritesSeen: boolean[] = [];

  tools(): Promise<ToolDescriptor[]> {
    return Promise.resolve([
      {
        name: 'calendar_list_events',
        description: 'List events',
        effect: 'read',
      },
      {
        name: 'calendar_create_event',
        description: 'Create an event',
        effect: 'write',
      },
    ]);
  }

  generate(input: { allowWrites: boolean }): Promise<GenerateResult> {
    this.allowWritesSeen.push(input.allowWrites);

    return Promise.resolve({
      raw: this.raw,
      toolTrace: this.toolTrace,
      model: 'stub',
      latencyMs: 0,
      iterations: 1,
    });
  }
}

/** One entry of a rehearsed tool trace, with the boring fields filled in. */
function toolEntry(entry: Partial<ToolTraceEntry>): ToolTraceEntry {
  return {
    id: 'call_1',
    name: 'calendar_create_event',
    arguments: {},
    effect: 'write',
    summary: 'Adicionar "Standup" na sua agenda',
    ok: false,
    startedAt: new Date().toISOString(),
    durationMs: 1,
    ...entry,
  };
}

/**
 * The calendar, as far as a thread is concerned: one zone and nothing else.
 *
 * The machine's, because every date in this file is written as a local one.
 * The real reader would ask the agent, which is not running here.
 */
class StubCalendarReader {
  zone(): Promise<Zone> {
    return Promise.resolve(systemZone());
  }
}

describe('ThreadsController', () => {
  let app: INestApplication<App>;
  let root: string;
  let agent: StubAgentService;

  beforeEach(async () => {
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'focus-api-'));
    process.env.FOCUS_DATA_DIR = root;

    const moduleRef = await Test.createTestingModule({
      // The prompt service reads the model name and the day's hours from
      // config. Nothing here reaches the agent, but it is still constructed.
      imports: [ConfigModule.forRoot({ ignoreEnvFile: true })],
      controllers: [ThreadsController],
      providers: [
        ThreadsService,
        ThreadsStore,
        AgentService,
        A2uiPromptService,
        A2uiParserService,
        A2uiValidationService,
        CalendarReaderService,
      ],
    })
      .overrideGuard(FirebaseAuthGuard)
      .useClass(StubAuthGuard)
      .overrideProvider(AgentService)
      .useClass(StubAgentService)
      .overrideProvider(CalendarReaderService)
      .useClass(StubCalendarReader)
      .compile();

    agent = moduleRef.get(AgentService);
    agent.toolTrace = [];

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
    delete process.env.FOCUS_DATA_DIR;
    await fs.rm(root, { recursive: true, force: true });
  });

  it('starts a thread and answers it', async () => {
    const response = await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Buy milk tomorrow' })
      .expect(201);

    expect(thread(response)).toMatchObject({
      slug: 'buy-milk-tomorrow',
      title: 'Buy milk tomorrow',
    });
    expect(thread(response).messages).toHaveLength(2);
    expect(thread(response).messages[0]).toMatchObject({
      role: 'user',
      text: 'Buy milk tomorrow',
    });
    expect(thread(response).messages[1]).toMatchObject({
      role: 'agent',
      metadata: { contentType: 'a2ui' },
    });
  });

  it("writes the thread as one markdown file in today's folder", async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Buy milk' })
      .expect(201);

    const markdown = await fs.readFile(
      path.join(root, 'test-user', dayFolder(new Date()), 'buy-milk.md'),
      'utf8',
    );

    expect(markdown).toContain('solved: false');
    expect(markdown).toContain('# Buy milk');
    expect(markdown).toMatch(/## user @ /);
    expect(markdown).toMatch(/## agent @ /);
    expect(markdown).toContain('"component":"Text"');
  });

  it('appends to an existing thread', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Buy milk' })
      .expect(201);

    const response = await request(app.getHttpServer())
      .post('/threads/buy-milk/messages')
      .send({ message: 'And eggs' })
      .expect(201);

    expect(thread(response).messages).toHaveLength(4);
    expect(thread(response).messages[2].text).toBe('And eggs');
  });

  it('gives a second thread with the same first message its own file', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Standup' })
      .expect(201);

    const second = await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Standup' })
      .expect(201);

    expect(thread(second).slug).toBe('standup-2');
  });

  it('drops an action type the catalog does not have', async () => {
    agent.raw = JSON.stringify({
      a2ui: {
        component: 'Column',
        children: [
          { component: 'Text', text: 'Shall I?' },
          {
            component: 'AppButton',
            text: 'Do it',
            action: {
              type: 'confirmTool',
              toolCallId: 'made-up',
              decision: 'confirm',
            },
          },
        ],
      },
    });

    const created = await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Schedule something' })
      .expect(201);

    const reply = thread(created).messages[1];
    expect(JSON.stringify(reply.metadata?.a2ui)).not.toContain('made-up');
    expect(visibleText(reply)).toContain('Shall I?');
    // The button lost its action, so it is dropped rather than rendered dead.
    expect(visibleText(reply)).not.toContain('Do it');
  });

  it('keeps tool names and raw JSON out of what the user reads', async () => {
    agent.raw = JSON.stringify({
      a2ui: {
        component: 'Column',
        children: [
          {
            component: 'Text',
            text: 'I called calendar_create_event for you.',
          },
          {
            component: 'Text',
            text: '{"busy":[{"start":"2026-09-20T10:00:00Z"}]}',
          },
        ],
      },
    });

    const created = await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Book it' })
      .expect(201);

    const rendered = visibleText(thread(created).messages[1]).join(' ');
    expect(rendered).not.toContain('calendar_create_event');
    expect(rendered).not.toContain('busy');
    expect(rendered).toContain('I called that for you.');
  });

  it('recovers a reply the model wrapped in a code fence', async () => {
    agent.raw =
      'Sure!\n```json\n{"a2ui":{"component":"Text","text":"On it."}}\n```';

    const created = await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Remind me' })
      .expect(201);

    const reply = thread(created).messages[1];
    expect(reply.metadata?.parseStrategy).toBe('fenced');
    expect(visibleText(reply)).toContain('On it.');
  });

  describe('the Coisas list', () => {
    it('says nothing about when a thread happens', async () => {
      await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'First' })
        .expect(201);

      const [item] = items(
        await request(app.getHttpServer()).get('/threads').expect(200),
      );

      // A conversation is a conversation. An hour for it is a block on the
      // calendar, and the row here makes no claim about one.
      expect(item).not.toHaveProperty('startTime');
      expect(item).not.toHaveProperty('durationMinutes');
    });

    it('lists open threads with their last reply, newest first', async () => {
      await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Buy milk' })
        .expect(201);
      await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Call mum' })
        .expect(201);

      const list = items(
        await request(app.getHttpServer()).get('/threads').expect(200),
      );

      expect(list.map((item) => item.slug)).toEqual(['call-mum', 'buy-milk']);
      expect(list[0].preview).not.toBe('');
    });

    it('leaves out what has been solved', async () => {
      await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Buy milk' })
        .expect(201);
      await request(app.getHttpServer())
        .post('/threads/buy-milk/solved')
        .send({ solved: true })
        .expect(201);

      const list = items(
        await request(app.getHttpServer()).get('/threads').expect(200),
      );

      expect(list).toEqual([]);
      expect(
        items(
          await request(app.getHttpServer()).get('/threads/solved').expect(200),
        ).map((item) => item.slug),
      ).toEqual(['buy-milk']);
    });
  });

  describe('solving a thread', () => {
    it('marks it solved', async () => {
      await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Buy milk' })
        .expect(201);

      await request(app.getHttpServer())
        .post('/threads/buy-milk/solved')
        .send({ solved: true })
        .expect(201);

      expect(
        (await request(app.getHttpServer()).get('/threads/buy-milk')).body,
      ).toMatchObject({ slug: 'buy-milk', solved: true });
    });

    it('refuses a body without a solved flag', async () => {
      await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Buy milk' })
        .expect(201);

      await request(app.getHttpServer())
        .post('/threads/buy-milk/solved')
        .send({})
        .expect(400);
    });

    it('404s for a thread that is not there', async () => {
      await request(app.getHttpServer())
        .post('/threads/nope/solved')
        .send({ solved: true })
        .expect(404);
    });
  });

  describe('the write gate', () => {
    /** A reply that proposes a change and offers the confirm that runs it. */
    const proposal = JSON.stringify({
      a2ui: {
        component: 'Column',
        children: [
          { component: 'Text', text: 'Posso deixar assim:' },
          {
            component: 'AppButton',
            text: 'Agendar',
            action: {
              type: 'confirm',
              text: 'Agendar "Standup" na quinta, 25/09, das 10:00 às 11:00',
            },
          },
        ],
      },
    });

    it('does not arm the first turn of a thread', async () => {
      await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Agenda um standup quinta' })
        .expect(201);

      expect(agent.allowWritesSeen).toEqual([false]);
    });

    it('keeps a confirm button and remembers that it proposed', async () => {
      agent.raw = proposal;

      const created = await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Agenda um standup quinta' })
        .expect(201);

      const reply = thread(created).messages[1];
      expect(reply.metadata?.proposedWrite).toBe(true);
      expect(JSON.stringify(reply.metadata?.a2ui)).toContain(
        '"type":"confirm"',
      );
      expect(visibleText(reply)).toContain('Agendar');
    });

    it('arms the turn a confirm action starts', async () => {
      agent.raw = proposal;
      await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Agenda um standup quinta' })
        .expect(201);

      agent.raw = JSON.stringify({
        a2ui: { component: 'Text', text: 'Agendado.' },
      });

      await request(app.getHttpServer())
        .post('/threads/agenda-um-standup-quinta/actions')
        .send({
          action: {
            type: 'confirm',
            text: 'Agendar "Standup" na quinta, 25/09, das 10:00 às 11:00',
          },
        })
        .expect(201);

      expect(agent.allowWritesSeen).toEqual([false, true]);
    });

    it('arms a typed answer to a proposal too', async () => {
      agent.raw = proposal;
      await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Agenda um standup quinta' })
        .expect(201);

      // Someone who reads a proposal and types "pode" has said yes as clearly
      // as someone who tapped it.
      await request(app.getHttpServer())
        .post('/threads/agenda-um-standup-quinta/messages')
        .send({ message: 'pode agendar' })
        .expect(201);

      expect(agent.allowWritesSeen).toEqual([false, true]);
    });

    it('closes the gate again once the reply is no longer a proposal', async () => {
      agent.raw = proposal;
      await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Agenda um standup quinta' })
        .expect(201);

      agent.raw = JSON.stringify({
        a2ui: { component: 'Text', text: 'Agendado.' },
      });
      await request(app.getHttpServer())
        .post('/threads/agenda-um-standup-quinta/messages')
        .send({ message: 'pode agendar' })
        .expect(201);

      await request(app.getHttpServer())
        .post('/threads/agenda-um-standup-quinta/messages')
        .send({ message: 'e na sexta?' })
        .expect(201);

      expect(agent.allowWritesSeen).toEqual([false, true, false]);
    });

    it('drops a confirm too vague to stand as its own message', async () => {
      agent.raw = JSON.stringify({
        a2ui: {
          component: 'Column',
          children: [
            { component: 'Text', text: 'Posso agendar?' },
            {
              component: 'AppButton',
              text: 'Sim',
              action: { type: 'confirm', text: 'Sim' },
            },
          ],
        },
      });

      const created = await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Agenda alguma coisa' })
        .expect(201);

      const reply = thread(created).messages[1];
      expect(JSON.stringify(reply.metadata?.a2ui)).not.toContain('confirm');
      expect(reply.metadata?.proposedWrite).toBeUndefined();
    });
  });

  describe('a write that failed', () => {
    it('overrules a reply claiming a failed write succeeded', async () => {
      agent.raw = JSON.stringify({
        a2ui: { component: 'Text', text: 'Pronto, agendei para quinta!' },
      });
      agent.toolTrace = [
        toolEntry({ ok: false, error: 'Calendar event creation failed: 500' }),
      ];

      const created = await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Agenda o standup' })
        .expect(201);

      const rendered = visibleText(thread(created).messages[1]).join(' ');
      expect(rendered).not.toContain('agendei');
      expect(rendered).toContain('Não consegui fazer isso');
      expect(rendered).toContain('Adicionar "Standup" na sua agenda');
    });

    it('leaves the retry armed, so an outage is not re-approved', async () => {
      agent.raw = JSON.stringify({
        a2ui: { component: 'Text', text: 'Pronto!' },
      });
      agent.toolTrace = [toolEntry({ ok: false, error: 'ETIMEDOUT' })];

      const created = await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Agenda o standup' })
        .expect(201);

      expect(thread(created).messages[1].metadata?.proposedWrite).toBe(true);
    });

    it('says nothing about a write that was merely blocked', async () => {
      agent.raw = JSON.stringify({
        a2ui: { component: 'Text', text: 'Posso agendar quinta às 10?' },
      });
      agent.toolTrace = [
        toolEntry({ ok: false, blocked: true, error: 'NOT EXECUTED' }),
      ];

      const created = await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Agenda o standup' })
        .expect(201);

      // Nothing was attempted, so the proposal is the right thing to show.
      const rendered = visibleText(thread(created).messages[1]).join(' ');
      expect(rendered).toContain('Posso agendar quinta');
      expect(rendered).not.toContain('Não consegui');
    });

    it('lets the model speak when a retry inside the turn worked', async () => {
      agent.raw = JSON.stringify({
        a2ui: { component: 'Text', text: 'Agendado para quinta.' },
      });
      agent.toolTrace = [
        toolEntry({ id: 'call_1', ok: false, error: 'transient' }),
        toolEntry({ id: 'call_2', ok: true }),
      ];

      const created = await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Agenda o standup' })
        .expect(201);

      expect(visibleText(thread(created).messages[1]).join(' ')).toContain(
        'Agendado para quinta.',
      );
    });

    it('records what each tool did, effect and all', async () => {
      agent.toolTrace = [
        toolEntry({ name: 'calendar_list_events', effect: 'read', ok: true }),
        toolEntry({ ok: true }),
      ];

      const created = await request(app.getHttpServer())
        .post('/threads')
        .send({ message: 'Agenda o standup' })
        .expect(201);

      expect(thread(created).messages[1].metadata?.toolRuns).toMatchObject([
        { name: 'calendar_list_events', effect: 'read', ok: true },
        { name: 'calendar_create_event', effect: 'write', ok: true },
      ]);
    });
  });

  it('marks a thread solved without calling the agent', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Tidy up' })
      .expect(201);

    const response = await request(app.getHttpServer())
      .post('/threads/tidy-up/actions')
      .send({ action: { type: 'thread', op: 'solve' } })
      .expect(201);

    const updated = (response.body as { thread: Thread }).thread;
    expect(updated.solved).toBe(true);
    // Nothing was said: solving is a state change, not a turn.
    expect(updated.messages).toHaveLength(2);
  });

  it('rejects an action the server does not route', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: 'Anything' })
      .expect(201);

    await request(app.getHttpServer())
      .post('/threads/anything/actions')
      .send({ action: { type: 'dismiss' } })
      .expect(400);
  });

  it('404s an unknown thread', async () => {
    await request(app.getHttpServer()).get('/threads/nothing').expect(404);
  });

  it('400s an empty message', async () => {
    await request(app.getHttpServer())
      .post('/threads')
      .send({ message: '   ' })
      .expect(400);
  });
});
