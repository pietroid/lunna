import { Injectable, NotFoundException } from '@nestjs/common';
import { A2uiParserService } from '../a2ui/a2ui-parser.service';
import { A2uiPromptService } from '../a2ui/a2ui-prompt.service';
import { A2uiValidationService } from '../a2ui/a2ui-validation.service';
import {
  containsConfirm,
  emptyReplyUi,
  unavailableUi,
  writeFailedUi,
} from '../a2ui/a2ui.builders';
import { A2uiComponent } from '../a2ui/a2ui.types';
import { CalendarReaderService } from '../calendar/calendar-reader.service';
import { Trace } from '../common/trace';
import { Zone } from '../time/zone';
import {
  AgentUnavailableError,
  AgentService,
  GenerateResult,
  ToolDescriptor,
} from './agent.service';
import { Message, MessageMetadata, ToolRun } from './entities/message.entity';
import { Thread, ThreadItem } from './entities/thread.entity';
import { messageId, slugify, titleFrom } from './thread-markdown';
import { toItem, ThreadsStore } from './threads.store';

/**
 * A thread, end to end.
 *
 * One turn is always the same five steps: write what the user said, build the
 * prompt, ask the agent, read what came back, write the answer. The agent runs
 * whatever tools it needs inside step three, so there is one place where a turn
 * can go wrong and one trace that describes it.
 *
 * Step three has one extra input: whether this turn may change anything. Reads
 * always run. A write runs only when the user has just authorised it, and this
 * is the only place that decides so.
 */
@Injectable()
export class ThreadsService {
  constructor(
    private readonly store: ThreadsStore,
    private readonly agent: AgentService,
    private readonly prompt: A2uiPromptService,
    private readonly parser: A2uiParserService,
    private readonly validator: A2uiValidationService,
    private readonly calendar: CalendarReaderService,
  ) {}

  /**
   * Every open thread as a row, most recently replied to first.
   *
   * What Coisas draws, and all of what it draws: every conversation the user
   * has open, whether or not any hour was ever set aside for it. Solved
   * threads are left out because they have a screen of their own.
   */
  async findItems(userId: string): Promise<ThreadItem[]> {
    return (await this.store.readAll(userId))
      .filter((thread) => !thread.solved)
      .map(toItem)
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
  }

  /** Everything the user has closed, most recently touched first. */
  async findSolved(userId: string): Promise<ThreadItem[]> {
    return (await this.store.readAll(userId))
      .filter((thread) => thread.solved)
      .map(toItem)
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
  }

  async findOne(userId: string, slug: string): Promise<Thread> {
    const thread = await this.find(userId, slug);
    if (thread === null) throw new NotFoundException(`No thread "${slug}"`);
    return thread;
  }

  /** One thread, or null when there is no such conversation. */
  async find(userId: string, slug: string): Promise<Thread | null> {
    return this.store.read(userId, slug);
  }

  /** One turn's trace, for debugging a reply after the fact. */
  async findTrace(
    userId: string,
    slug: string,
    traceId: string,
  ): Promise<unknown> {
    const trace = await this.store.readTrace(userId, slug, traceId);
    if (trace === null) throw new NotFoundException(`No trace "${traceId}"`);
    return trace;
  }

  /**
   * Starts a thread from its first message and answers it.
   *
   * The slug comes from the message, so a thread's folder says what it is
   * without anything having to open it.
   */
  async create(userId: string, text: string, trace: Trace): Promise<Thread> {
    const slug = await this._freeSlug(userId, slugify(text));
    trace.attachSlug(slug);
    trace.log('thread.create', { slug });

    await this.store.create(userId, slug, titleFrom(text));
    await this.store.append(userId, slug, [userMessage(text)]);
    // Nothing has been proposed yet, so the first turn of a thread can only
    // read and propose.
    await this._answer(userId, slug, trace, { allowWrites: false });

    return this.findOne(userId, slug);
  }

  /**
   * Starts a thread with a name and nothing said in it yet.
   *
   * What opening a block of time gives you: a conversation about it, called
   * whatever the block is called, with the field waiting. No agent runs,
   * because nobody has said anything for it to answer.
   */
  async createEmpty(userId: string, title: string): Promise<Thread> {
    const slug = await this._freeSlug(userId, slugify(title));
    await this.store.create(userId, slug, titleFrom(title));

    return this.findOne(userId, slug);
  }

  /**
   * Appends a message to an existing thread and answers it.
   *
   * [armWrites] is true when the message came from a confirm action, which is
   * the user saying yes to a change described in the previous message.
   */
  async addMessage(
    userId: string,
    slug: string,
    text: string,
    trace: Trace,
    armWrites = false,
  ): Promise<Thread> {
    const thread = await this.findOne(userId, slug);
    trace.log('thread.message', { slug, length: text.length, armWrites });

    // Read before appending: the proposal is the message that was last on
    // screen when the user answered.
    const allowWrites =
      armWrites || this._awaitingConfirmation(thread.messages);

    await this.store.append(userId, slug, [userMessage(text)]);
    await this._answer(userId, slug, trace, { allowWrites });

    return this.findOne(userId, slug);
  }

  /**
   * Whether the last thing the assistant said was a proposal.
   *
   * A tapped button is not the only way to say yes. Someone who reads "posso
   * agendar quinta às 10?" and types "pode" has confirmed it just as clearly,
   * and being told to use the button instead would be the pedantry this whole
   * flow exists to avoid. So the proposal arms the turn that answers it,
   * however that answer arrives.
   *
   * It arms exactly one turn. The next message lands after a reply that is no
   * longer a proposal, and the gate closes again.
   */
  private _awaitingConfirmation(messages: Message[]): boolean {
    for (let index = messages.length - 1; index >= 0; index--) {
      const message = messages[index];
      if (message.role !== 'agent') continue;
      return message.metadata?.proposedWrite === true;
    }
    return false;
  }

  /**
   * Marks a thread solved, or opens a closed one again.
   *
   * Nothing happens to the calendar. A conversation being finished with says
   * nothing about an hour, and an hour that is finished with is taken off the
   * day by finishing the block, which is a different act on a different
   * screen.
   */
  async setSolved(
    userId: string,
    slug: string,
    solved: boolean,
    trace: Trace,
  ): Promise<ThreadItem[]> {
    await this.findOne(userId, slug);
    trace.log('thread.solved', { slug, solved });

    await this.store.updateState(userId, slug, { solved });

    return this.findItems(userId);
  }

  /** Applies a thread-level change the app asked for. */
  async applyThreadOp(
    userId: string,
    slug: string,
    op: 'solve' | 'reopen' | 'rename' | 'delete',
    title: string | undefined,
    trace: Trace,
  ): Promise<Thread | null> {
    await this.findOne(userId, slug);
    trace.log('thread.op', { slug, op, title });

    switch (op) {
      case 'solve':
        await this.store.updateState(userId, slug, { solved: true });
        break;
      case 'reopen':
        await this.store.updateState(userId, slug, { solved: false });
        break;
      case 'rename':
        if (title === undefined || title.trim() === '') {
          throw new NotFoundException('rename needs a title');
        }
        await this.store.updateState(userId, slug, { title: title.trim() });
        break;
      case 'delete':
        await this.store.remove(userId, slug);
        return null;
    }

    return this.findOne(userId, slug);
  }

  /**
   * Asks the agent for the next reply and writes it into the thread.
   *
   * Everything the user will read passes through parse, then validate, then
   * store. A reply that fails any of those still lands as a message, because a
   * thread that silently stops answering is harder to debug than one that says
   * what went wrong.
   */
  private async _answer(
    userId: string,
    slug: string,
    trace: Trace,
    options: {
      /** Whether a tool may change the user's data on this turn. */
      allowWrites: boolean;
      note?: string;
      toolRuns?: MessageMetadata['toolRuns'];
    },
  ): Promise<void> {
    const thread = await this.findOne(userId, slug);

    let tools: ToolDescriptor[] = [];
    let result: GenerateResult;

    try {
      tools = await this.agent.tools(trace);
      const messages = this.prompt.build({
        history: thread.messages,
        userMessage: '',
        tools,
        allowWrites: options.allowWrites,
        note: options.note,
        zone: await this._zone(userId, trace),
      });

      trace.log('prompt.built', {
        messageCount: messages.length,
        systemChars: messages[0]?.content.length ?? 0,
        tools: tools.map((tool) => tool.name),
        allowWrites: options.allowWrites,
      });

      result = await this.agent.generate(
        { userId, slug, messages, allowWrites: options.allowWrites },
        trace,
      );
    } catch (error) {
      await this._handleUnavailable(userId, slug, trace, error);
      return;
    }

    const toolRuns: ToolRun[] = [
      ...(options.toolRuns ?? []),
      ...result.toolTrace.map((entry) => ({
        name: entry.name,
        effect: entry.effect,
        ok: entry.ok,
        blocked: entry.blocked,
        durationMs: entry.durationMs,
        error: entry.error,
      })),
    ];

    // The one case where the model does not get the last word. A write that
    // was attempted and broke is where a reply is most likely to say "pronto,
    // agendei" over a tool result that says nothing of the sort, and no amount
    // of prompting makes that safe. The trace is the fact; the prose is not.
    const failure = this._failedWrite(result);
    if (failure !== undefined) {
      trace.error('turn.writeFailed', {
        tool: failure.name,
        error: failure.error,
        claimedLength: result.raw.length,
      });

      await this._appendUi(
        userId,
        slug,
        writeFailedUi(failure.summary, failure.error ?? ''),
        {
          contentType: 'a2ui',
          model: result.model,
          latencyMs: result.latencyMs,
          traceId: trace.id,
          toolRuns,
          // The retry button is a confirm, so the next turn is still allowed to
          // run the write. Making the user re-approve something they already
          // approved, because the calendar timed out, would be punishing them
          // for an outage.
          proposedWrite: true,
        },
      );

      await this._saveTrace(userId, slug, trace);
      return;
    }

    const parsed = this.parser.parse(result.raw);
    trace.log('a2ui.parse', {
      strategy: parsed.strategy,
      detail: parsed.detail,
      rawLength: result.raw.length,
    });

    // A failed parse used to be wrapped anyway, as `children: [undefined]`.
    // The validator then rejected the child, dropped the empty Column, and the
    // user read a generic apology whose real cause was that the model had
    // returned nothing at all. It is its own outcome, and it says so.
    if (parsed.component === undefined) {
      trace.error('a2ui.parseFailed', {
        detail: parsed.detail,
        rawLength: result.raw.length,
        toolsRun: toolRuns.map((run) => run.name),
      });

      await this._appendUi(userId, slug, emptyReplyUi(), {
        contentType: 'a2ui',
        model: result.model,
        latencyMs: result.latencyMs,
        traceId: trace.id,
        toolRuns: toolRuns.length > 0 ? toolRuns : undefined,
        parseStrategy: parsed.strategy,
      });

      await this._saveTrace(userId, slug, trace);
      return;
    }

    const validated = this.validator.validate(
      { component: 'Column', children: [parsed.component] },
      { toolNames: tools.map((tool) => tool.name) },
    );

    if (!validated.clean) {
      // Logged in full, because a reply that quietly lost a button looks fine
      // on screen and is invisible without this line.
      trace.warn('a2ui.repaired', {
        issues: validated.issues,
        strategy: parsed.strategy,
      });
    }

    trace.log('a2ui.validated', {
      clean: validated.clean,
      issues: validated.issues.length,
      components: countComponents(validated.component),
    });

    // A proposal arms the next turn, so it is recorded on the message rather
    // than inferred later from prose that no longer carries the action.
    const proposedWrite = containsConfirm(validated.component);
    if (proposedWrite) trace.log('turn.proposedWrite', {});

    await this._appendUi(userId, slug, validated.component, {
      contentType: 'a2ui',
      model: result.model,
      latencyMs: result.latencyMs,
      traceId: trace.id,
      toolRuns: toolRuns.length > 0 ? toolRuns : undefined,
      a2uiIssues: validated.issues.length > 0 ? validated.issues : undefined,
      parseStrategy: parsed.strategy,
      proposedWrite: proposedWrite ? true : undefined,
    });

    await this._saveTrace(userId, slug, trace);
  }

  /**
   * The zone the prompt's "now" line is written in.
   *
   * The calendar's own zone, so the model reads the same clock the user does
   * rather than whatever zone the container happens to run in. It is only a
   * date in a sentence, so a calendar that cannot be reached costs the turn
   * nothing: the prompt falls back to the server's zone on its own.
   */
  private async _zone(userId: string, trace: Trace): Promise<Zone | undefined> {
    try {
      return await this.calendar.zone({ id: userId });
    } catch (error) {
      trace.log('prompt.zone.unavailable', {
        reason: error instanceof Error ? error.message : String(error),
      });
      return undefined;
    }
  }

  /**
   * The write that was attempted and broke, if the turn has one.
   *
   * A blocked write does not count: nothing was tried, and the reply proposing
   * it is exactly what should be shown. A write that failed and was then
   * retried successfully does not count either, which is why the whole trace is
   * weighed rather than the last entry.
   */
  private _failedWrite(
    result: GenerateResult,
  ): GenerateResult['toolTrace'][number] | undefined {
    const writes = result.toolTrace.filter((entry) => entry.effect === 'write');
    if (writes.some((entry) => entry.ok)) return undefined;
    return writes.find((entry) => entry.blocked !== true);
  }

  private async _handleUnavailable(
    userId: string,
    slug: string,
    trace: Trace,
    error: unknown,
  ): Promise<void> {
    const message = error instanceof Error ? error.message : String(error);
    trace.error('turn.unavailable', {
      error: message,
      kind: error instanceof AgentUnavailableError ? 'agent' : 'server',
    });

    await this._appendUi(userId, slug, unavailableUi(), {
      contentType: 'a2ui',
      traceId: trace.id,
      model: 'unavailable',
    });

    await this._saveTrace(userId, slug, trace);
  }

  private async _appendUi(
    userId: string,
    slug: string,
    component: A2uiComponent,
    metadata: MessageMetadata,
  ): Promise<void> {
    const createdAt = new Date();

    await this.store.append(userId, slug, [
      {
        id: messageId('agent', createdAt),
        role: 'agent',
        text: '',
        createdAt,
        metadata: { ...metadata, a2ui: component },
      },
    ]);
  }

  private async _saveTrace(
    userId: string,
    slug: string,
    trace: Trace,
  ): Promise<void> {
    try {
      await this.store.saveTrace(userId, slug, trace.id, {
        traceId: trace.id,
        slug,
        totalMs: trace.elapsedMs,
        events: trace.events,
      });
    } catch (error) {
      // A trace that cannot be written must never cost the user their reply.
      trace.warn('trace.saveFailed', {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * The first slug not already taken, suffixed `-2`, `-3`, and so on.
   *
   * Two threads can genuinely start with the same sentence, and neither
   * should silently land in the other's file.
   */
  private async _freeSlug(userId: string, base: string): Promise<string> {
    if (!(await this.store.exists(userId, base))) return base;

    for (let suffix = 2; suffix < 1000; suffix++) {
      const candidate = `${base}-${suffix}`;
      if (!(await this.store.exists(userId, candidate))) return candidate;
    }

    return `${base}-${Date.now()}`;
  }
}

function userMessage(text: string): Message {
  const createdAt = new Date();
  return {
    id: messageId('user', createdAt),
    role: 'user',
    text,
    createdAt,
  };
}

function countComponents(component: A2uiComponent): number {
  return (
    1 +
    (component.children ?? []).reduce(
      (total, child) => total + countComponents(child),
      0,
    )
  );
}
