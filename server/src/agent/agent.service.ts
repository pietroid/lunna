import { randomUUID } from 'crypto';
import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { CalendarService } from '../calendar/calendar.service';
import { CalendarUser } from '../calendar/calendar.types';
import { Trace } from '../common/trace';
import { EventLayoutService } from '../events/event-layout.service';
import {
  Day,
  intervalOfTask,
  TimelineService,
} from '../events/timeline.service';
import { ArtifactStore } from '../artifacts/artifact.store';
import { TaskStore } from '../tasks/task.store';
import {
  addMinutes,
  DEFAULT_WORK_DAY,
  Interval,
  nextFreeSlot,
  roundUpToFiveMinutes,
} from '../time/work-hours';
import {
  addDaysIn,
  formatTimeIn,
  instantOf,
  isoDayIn,
  isoIn,
  sameDayIn,
  startOfDayIn,
  Zone,
} from '../time/zone';
import { AgentError } from './agent.errors';
import {
  A2uiMessage,
  Block,
  Choice,
  legacyOptions,
  peekCard,
  peekDay,
  peekArtifact,
  summary,
  toA2ui,
} from './answer';
import { SYSTEM_PROMPT, TOOLS } from './agent.prompt';
import { Board, BoardCard, HORIZON_DAYS, noonOf } from './board';
import { ConversationStore, PlanStatus } from './conversation.store';
import { Hands, make, sandbox, takeBack } from './gestures';
import {
  ChatMessage,
  ModelOutcome,
  ModelUsage,
  OpenRouterClient,
  ToolCall,
} from './openrouter.client';
import { speakable } from './speech';
import {
  Assumption,
  Gesture,
  NewThing,
  Plan,
  PlanChange,
  PlanStore,
  Pushed,
  Undo,
} from './plan';

/** One message of the conversation, as the app keeps it. */
export interface AgentMessage {
  role: 'user' | 'assistant';
  text: string;
  /** How long it took to say, when the user spoke it. */
  voiceSeconds?: number;
}

/**
 * What a conversation is about, when it was opened from a page rather than
 * from Tempo: a task's or an artifact's.
 */
export type Subject = { taskId: string } | { artifactId: string };

/** How much of a subject's notes the model reads. */
const MAX_NOTES = 2000;

/** A plan, as the app draws it. */
export interface PlanView {
  id: string;
  changes: PlanChange[];
  pushed: Pushed[];
  assumed: Assumption[];
}

/** An answer offered to tap: its plan, made with no other turn. */
export interface QuickReply {
  label: string;
  plan: PlanView;
}

/** What one turn answers with. */
export interface AgentReply {
  /** The conversation the turn was written into. */
  conversationId: string;
  /**
   * The answer as one A2UI surface (`toA2ui`): what the app draws. The
   * fields after it say the same for builds older than the surface, and
   * [reply] is also what the conversation keeps.
   */
  ui: A2uiMessage[];
  /** The answer in words: the caption, or a line per block. Never empty. */
  reply: string;
  /** What the server found, one short line each, in the order it found it. */
  steps: string[];
  /** The changes it proposes, when it proposes any. */
  plan?: PlanView;
  /** Answers to tap: a doubt's, or another way beside [plan]. */
  options: QuickReply[];
}

/** A turn as the service works it out: the reply, plus what only tests and evals read. */
export interface TurnResult extends AgentReply {
  /** The surface's blocks, as `ui` encodes them. */
  blocks: Block[];
  /** How many refs and scheduler words `speakable` took out of the model's words. */
  leaks: number;
  /** What the model wrote for the person, before `speakable`. */
  raw: string[];
}

/** A proposal the agent makes without being asked. */
export interface Suggestion {
  text: string;
  plan: PlanView;
}

/**
 * The model asked for something that cannot be: told to the model, in its
 * terms, for it to fix or to ask the person about.
 */
class Refusal extends Error {}

/** One of the model's changes, every reference in it resolved. */
interface Draft {
  gesture: Gesture;
  /** What the server found resolving it, for the person to read. */
  facts: string[];
  assumed: Assumption[];
  /** The card it moves, when it moves one. */
  card?: BoardCard;
  /** For a place: the titles of the cards around it. */
  place?: { after?: string; before?: string };
  /** Whether it may be a card already there under another name. */
  duplicate: boolean;
}

/** Everything one turn works from. */
interface Turn {
  user: CalendarUser;
  conversationId: string;
  board: Board;
  now: Date;
  trace: Trace;
  steps: string[];
  calls: number;
  usage: ModelUsage;
  leaks: number;
  raw: string[];
}

/** What a plan block came to. */
type Proposal =
  | { kind: 'plan'; plan: Plan; options: QuickReply[] }
  | { kind: 'doubt'; reply: string; options: QuickReply[] };

/** A turn's answer, bound: the blocks, and the plans behind them. */
interface Answered {
  blocks: Block[];
  plan?: Plan;
}

/** At most this many blocks in one answer. */
const MAX_BLOCKS = 6;

/** At most this many cards in a cards block. */
const MAX_CARDS = 8;

/** A caption longer than this is not drawn. */
const MAX_CAPTION = 80;

/** A heading or a choice's label longer than this is cut. */
const MAX_HEADING = 40;

/** How many model round-trips one turn is allowed. */
const MAX_ITERATIONS = 4;

/** How many pushed tasks a plan shows; the rest follow them. */
const MAX_PUSHED = 8;

/** How many past messages one search hands the model. */
const MAX_FOUND = 20;

/** How long something new takes when nobody said. */
const DEFAULT_MINUTES = 30;

/** How many conversations' refs are kept in memory. */
const MAX_CONVERSATIONS_HELD = 500;

/**
 * Lunna's agent: it reads the day and proposes changes to it.
 *
 * Reads run the moment the model asks, and there are no writes at all. The
 * model says what the person meant, as gestures on cards it names by ref;
 * the server resolves the days, the cards and the hours, makes the gestures
 * on a sandbox copy of the day to see what they do, and files the plan. The
 * user applies it, and the same gestures are made again on the real day,
 * through the same layout the app's own drags go through.
 */
@Injectable()
export class AgentService {
  private readonly _plans = new PlanStore();
  /** The suggestion last offered to each person, so it is offered once. */
  private readonly _suggested = new Map<string, Plan>();
  /**
   * The doubt each conversation was last left with, by one of its answers'
   * plans: answered by typing rather than a tap, the options missed.
   */
  private readonly _asked = new Map<string, string>();
  /** The refs each conversation was shown, by card id (`Board`). */
  private readonly _refs = new Map<string, Map<string, string>>();

  constructor(
    private readonly _model: OpenRouterClient,
    private readonly _timeline: TimelineService,
    private readonly _layout: EventLayoutService,
    private readonly _calendar: CalendarService,
    private readonly _tasks: TaskStore,
    private readonly _artifacts: ArtifactStore,
    private readonly _conversations: ConversationStore,
  ) {}

  get configured(): boolean {
    return this._model.configured;
  }

  private get _hands(): Hands {
    return {
      timeline: this._timeline,
      layout: this._layout,
      calendar: this._calendar,
      tasks: this._tasks,
    };
  }

  /**
   * Answers the last message of [history], the conversation [conversationId]
   * (a new one when absent), and writes both down. Changes nothing on the day.
   *
   * [history] is all the model is told of the past: earlier conversations are
   * for the person to read back, and for the model to look up when asked.
   */
  async turn(
    user: CalendarUser,
    conversationId: string | undefined,
    history: AgentMessage[],
    focusDay: string | undefined,
    about: Subject | undefined,
    trace: Trace,
    now = new Date(),
  ): Promise<TurnResult> {
    const conversation = conversationId ?? randomUUID();
    const asked = this._asked.get(conversation);
    if (asked !== undefined) {
      this._asked.delete(conversation);
      const option = this._plans.get(user.id, asked);
      if (
        option !== undefined &&
        option.applied === undefined &&
        !this._plans.answered(option)
      ) {
        trace.log('agent.doubtAnswered', { via: 'text' });
      }
    }
    const answer = await this._answer(
      user,
      conversation,
      history,
      focusDay,
      about,
      trace,
      now,
    );
    const said = history[history.length - 1];
    await this._conversations.append(user, conversation, [
      {
        role: 'user',
        text: said.text,
        voiceSeconds: said.voiceSeconds,
        at: now,
      },
      {
        role: 'assistant',
        text: answer.reply,
        steps: answer.steps,
        plan: answer.plan,
        // After the question, however long the answer took to work out.
        at: new Date(now.getTime() + 1),
      },
    ]);

    return { conversationId: conversation, ...answer };
  }

  /**
   * The refs handed out in [conversationId] so far, by id: the board keeps
   * them, so "a t2" means the same card on the next turn.
   */
  private _refsOf(conversationId: string): Map<string, string> {
    const known = this._refs.get(conversationId);
    if (known !== undefined) return known;

    // In memory, like the plans: the oldest conversations go first.
    if (this._refs.size >= MAX_CONVERSATIONS_HELD) {
      const [oldest] = this._refs.keys();
      this._refs.delete(oldest);
    }
    const refs = new Map<string, string>();
    this._refs.set(conversationId, refs);

    return refs;
  }

  /**
   * What the model reads about the page the person is on: the task or the
   * artifact, as `read_cards` reads it. Refused when there is no such thing.
   */
  private async _subject(
    user: CalendarUser,
    about: Subject,
    board: Board,
  ): Promise<string> {
    if ('taskId' in about) {
      const card =
        board.byId(about.taskId) ??
        (await this._tasks
          .get(user, about.taskId)
          .then((task) =>
            task === undefined ? undefined : board.reach(task),
          ));
      if (card === undefined) {
        throw new AgentError(
          'refused',
          'Não encontrei essa tarefa.',
          HttpStatus.NOT_FOUND,
        );
      }
      return [
        'The person is on this task’s page:',
        ...this._read(board, card.ref),
      ].join('\n');
    }

    const artifact = board.artifactById(about.artifactId);
    if (artifact === undefined) {
      throw new AgentError(
        'refused',
        'Não encontrei essa entrega.',
        HttpStatus.NOT_FOUND,
      );
    }
    return [
      'The person is on this artifact’s page:',
      ...this._read(board, artifact.ref),
    ].join('\n');
  }

  /**
   * One card or artifact, read whole: its line, its notes and (an artifact's)
   * every task under a ref. The page's context and `read_cards` are this
   * same function, so what the model knows of an artifact is the same
   * wherever the person asked from.
   */
  private _read(board: Board, ref: string): string[] {
    const notes = (text: string) => {
      const kept = text.trim().slice(0, MAX_NOTES);
      return kept === ''
        ? ['  Notes: (none)']
        : ['  Notes:', ...kept.split('\n').map((line) => `    ${line}`)];
    };

    const artifact = board.artifact(ref);
    if (artifact !== undefined) {
      const { title, deadline, doneAt } = artifact.artifact;
      return [
        `  ${artifact.ref} · artifact “${title}”${deadline === undefined ? '' : `, due ${deadline}`}${doneAt === undefined ? '' : ' (done)'}`,
        ...notes(artifact.artifact.notes),
        '  Its tasks:',
        ...(artifact.tasks.length === 0
          ? ['    (none)']
          : artifact.tasks.map(
              (task) => `    ${board.line(board.reach(task))}`,
            )),
      ];
    }

    const card = board.ref(ref);
    if (card === undefined) return [`  No card or artifact ${ref}.`];
    return [`  ${board.line(card)}`, ...notes(card.notes)];
  }

  /** The conversations before [before], most recent first. */
  history(user: CalendarUser, before: Date | undefined, limit: number) {
    return this._conversations.recent(user, before, limit);
  }

  private async _answer(
    user: CalendarUser,
    conversationId: string,
    history: AgentMessage[],
    focusDay: string | undefined,
    about: Subject | undefined,
    trace: Trace,
    now: Date,
  ): Promise<Omit<TurnResult, 'conversationId'>> {
    const [day, artifacts, artifactTasks] = await Promise.all([
      this._timeline.day(user, HORIZON_DAYS, now),
      this._artifacts.list(user),
      this._tasks.ofArtifacts(user),
    ]);
    const board = new Board(day, this._timeline.view(day), {
      refs: this._refsOf(conversationId),
      artifacts,
      artifactTasks,
    });
    const subject =
      about === undefined
        ? ''
        : `\n\n${await this._subject(user, about, board)}`;
    const turn: Turn = {
      user,
      conversationId,
      board,
      now,
      trace,
      steps: [],
      calls: 0,
      usage: { promptTokens: 0, completionTokens: 0, cachedTokens: 0, cost: 0 },
      leaks: 0,
      raw: [],
    };
    const said = history[history.length - 1].text;

    // The day goes last, right before the request, where it is read best.
    const messages: ChatMessage[] = [
      { role: 'system', content: SYSTEM_PROMPT },
      ...history
        .slice(0, -1)
        .map((it) => ({ role: it.role, content: it.text })),
      {
        role: 'user',
        content: `${board.context(focusDay, said)}${subject}\n\n---\nRequest: ${said}`,
      },
    ];

    const done = (answered: Answered) => {
      trace.log('agent.turn', {
        calls: turn.calls,
        ...turn.usage,
        ms: trace.elapsedMs,
        blocks: answered.blocks.map((it) => it.kind),
        leaks: turn.leaks,
      });
      if (turn.leaks > 0) trace.warn('agent.leak', { leaks: turn.leaks });
      return this._reply(turn, answered);
    };

    for (let iteration = 1; iteration <= MAX_ITERATIONS; iteration++) {
      const outcome = await this._generate(turn, messages, iteration);

      if (outcome.kind === 'final') {
        return done(this._plain(turn, outcome.content));
      }

      messages.push({
        role: 'assistant',
        content: '',
        tool_calls: outcome.toolCalls,
      });

      for (const call of outcome.toolCalls) {
        const result = await this._run(turn, call);
        messages.push({
          role: 'tool',
          tool_call_id: call.id,
          content: JSON.stringify(result.answer),
        });
        if (result.answered !== undefined) return done(result.answered);
      }
    }

    // Out of round-trips: one last call with no tools leaves the model
    // nothing to do but say where it got to.
    trace.warn('agent.iterationLimit');
    const closing = await this._generate(
      turn,
      [
        ...messages,
        {
          role: 'system',
          content:
            'Stop calling tools and answer now, in Portuguese, in one short sentence.',
        },
      ],
      MAX_ITERATIONS + 1,
      [],
    );

    return done(
      this._plain(
        turn,
        closing.kind === 'final'
          ? closing.content
          : 'Não consegui montar isso. Pode pedir de outro jeito?',
      ),
    );
  }

  /** [answered] as the turn's reply: the surface, and the same in old shapes. */
  private _reply(
    turn: Turn,
    answered: Answered,
  ): Omit<TurnResult, 'conversationId'> {
    const { blocks, plan } = answered;
    const choices = blocks.flatMap((it) =>
      it.kind === 'choices' ? it.options : [],
    );

    return {
      ui: toA2ui(`turn-${randomUUID().slice(0, 8)}`, blocks),
      reply: summary(turn.board, blocks),
      steps: dedupe(turn.steps),
      ...(plan === undefined ? {} : { plan: planView(plan) }),
      options: legacyOptions(choices),
      blocks,
      leaks: turn.leaks,
      raw: turn.raw,
    };
  }

  /** Words the model wrote outside `answer`: a caption with no limit. */
  private _plain(turn: Turn, content: string): Answered {
    const text = this._say(turn, content);
    return {
      blocks: [
        {
          kind: 'caption',
          text: text === '' ? 'Não entendi. Pode dizer de outro jeito?' : text,
        },
      ],
    };
  }

  /** [text] as the person may read it, counting what had to be taken out. */
  private _say(turn: Turn, text: string): string {
    turn.raw.push(text);
    const said = speakable(text, turn.board);
    turn.leaks += said.leaks;
    return said.text;
  }

  private async _generate(
    turn: Turn,
    messages: ChatMessage[],
    iteration: number,
    tools = TOOLS,
  ): Promise<ModelOutcome> {
    const outcome = await turn.trace.span('agent.model', { iteration }, () =>
      this._model.generate(messages, tools),
    );
    turn.calls++;
    if (outcome.usage !== undefined) {
      turn.usage.promptTokens += outcome.usage.promptTokens;
      turn.usage.completionTokens += outcome.usage.completionTokens;
      turn.usage.cachedTokens += outcome.usage.cachedTokens;
      turn.usage.cost += outcome.usage.cost;
      turn.usage.model = outcome.usage.model;
    }

    return outcome;
  }

  /** Makes every change of [planId], or none of them. */
  async apply(
    user: CalendarUser,
    planId: string,
    trace: Trace,
    now = new Date(),
  ): Promise<string[]> {
    const plan = this._plans.get(user.id, planId);
    if (plan === undefined) {
      throw new AgentError(
        'refused',
        'Esse plano expirou. Peça de novo.',
        HttpStatus.NOT_FOUND,
      );
    }
    if (plan.applied !== undefined) {
      throw new AgentError(
        'refused',
        'Esse plano já foi aplicado.',
        HttpStatus.CONFLICT,
      );
    }
    if (this._plans.answered(plan)) {
      throw new AgentError(
        'refused',
        'Essa pergunta já foi respondida com outra opção.',
        HttpStatus.CONFLICT,
      );
    }

    const undo: Undo[] = [];
    const touched: string[] = [];

    try {
      for (const gesture of plan.gestures) {
        touched.push(await make(this._hands, user, gesture, undo, trace, now));
      }
    } catch (error) {
      trace.warn('agent.applyFailed', {
        planId,
        error: error instanceof Error ? error.message : String(error),
      });
      await takeBack(this._hands, user, undo, trace);
      throw new AgentError(
        'drift',
        'Seu dia mudou desde esse plano e ele não cabe mais. Peça de novo.',
        HttpStatus.CONFLICT,
      );
    }

    plan.applied = { undo, touched };
    await this._mark(user, plan.group ?? planId, 'applied', trace);
    trace.log('agent.applied', {
      planId,
      changes: plan.gestures.length,
      option: plan.group !== undefined,
    });
    if (plan.group !== undefined) {
      trace.log('agent.doubtAnswered', { via: 'option' });
    }

    return touched;
  }

  /** Takes an applied plan back, every change of it, and leaves it a plan. */
  async undo(user: CalendarUser, planId: string, trace: Trace): Promise<void> {
    const plan = this._plans.get(user.id, planId);
    if (plan?.applied === undefined) {
      throw new AgentError(
        'refused',
        'Não há mais o que desfazer.',
        HttpStatus.NOT_FOUND,
      );
    }

    await takeBack(this._hands, user, plan.applied.undo, trace);
    // Back to a proposal: the card offers Aplicar again.
    plan.applied = undefined;
    await this._mark(user, plan.group ?? planId, 'undone', trace);
    trace.log('agent.undone', { planId });
  }

  /** Notes on the conversation what became of a plan; never fails a write. */
  private async _mark(
    user: CalendarUser,
    planId: string,
    status: PlanStatus,
    trace: Trace,
  ): Promise<void> {
    try {
      await this._conversations.markPlan(user, planId, status);
    } catch (error) {
      trace.warn('agent.markFailed', {
        planId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  /**
   * One thing worth offering without being asked: the first task in the
   * backlog that fits in the room left today.
   *
   * No model: a suggestion is drawn every time Tempo opens, and this one
   * needs only arithmetic. It is the same plan a turn would make, so the
   * app applies and undoes it the same way.
   */
  async suggestion(
    user: CalendarUser,
    now = new Date(),
  ): Promise<Suggestion | undefined> {
    const zone = this._timeline.zone(user);
    const workDay = user.workDay ?? DEFAULT_WORK_DAY;
    const view = this._timeline.view(await this._timeline.day(user, 1, now));
    const busy: Interval[] = view.cards.map((card) => ({
      start: new Date(card.startTime),
      end: new Date(card.endTime),
    }));
    const from = roundUpToFiveMinutes(now);

    for (const task of view.backlog.slice(0, 3)) {
      const slot = nextFreeSlot(
        from,
        task.durationMinutes,
        busy,
        zone,
        workDay,
      );
      if (!sameDayIn(slot.start, now, zone)) continue;

      const at = slot.start.toISOString();
      const last = this._suggested.get(user.id);
      const offered =
        last !== undefined &&
        this._plans.get(user.id, last.id) !== undefined &&
        last.applied === undefined &&
        last.changes[0]?.id === task.id &&
        last.changes[0]?.at === at
          ? last
          : this._plans.put(user.id, {
              gestures: [{ do: 'at_hour', id: task.id, at }],
              changes: [
                {
                  kind: 'move_task',
                  id: task.id,
                  title: task.title,
                  minutes: task.durationMinutes,
                  at,
                  routine: task.routine !== undefined,
                },
              ],
              pushed: [],
              assumed: [],
            });
      this._suggested.set(user.id, offered);

      return {
        text:
          `"${task.title}" está esperando no Depois eu priorizo. ` +
          `Hoje às ${formatTimeIn(slot.start, zone)} tem espaço para ela. ` +
          'Quer encaixar?',
        plan: planView(offered),
      };
    }

    return undefined;
  }

  /** Runs one tool call, and says what it found in the model's terms. */
  private async _run(
    turn: Turn,
    call: ToolCall,
  ): Promise<{ answer: unknown; answered?: Answered }> {
    let args: Record<string, unknown>;
    try {
      args = JSON.parse(call.function.arguments) as Record<string, unknown>;
    } catch {
      return { answer: { error: 'Arguments were not valid JSON.' } };
    }

    turn.trace.log('agent.tool', { name: call.function.name });

    switch (call.function.name) {
      case 'read_timeline': {
        const { board } = turn;
        const from =
          typeof args.day === 'string' ? board.dayOf(args.day) : board.today;
        if (from === undefined) {
          return {
            answer: {
              error: `Unknown day "${String(args.day)}". Use hoje, amanhã, a weekday, or YYYY-MM-DD from the date table, within ${HORIZON_DAYS} days.`,
            },
          };
        }
        const days = clampInt(args.days, 1, 7, 1);
        turn.steps.push(
          `Olhei ${days === 1 ? board.dayLabel(from) : `${days} dias`}`,
        );
        return { answer: { day: board.read(from, days) } };
      }
      case 'read_conversations': {
        const read = await this._past(turn, args);
        turn.steps.push(read.step);
        return { answer: read.snapshot };
      }
      case 'read_cards': {
        const { board } = turn;
        const refs = (Array.isArray(args.refs) ? args.refs : [])
          .filter((it): it is string => typeof it === 'string')
          .slice(0, MAX_CARDS);
        if (refs.length === 0) {
          return { answer: { error: 'read_cards needs refs, e.g. ["p1"].' } };
        }
        const titles = refs
          .map((ref) => board.title(ref))
          .filter((it) => it !== undefined);
        if (titles.length > 0) turn.steps.push(`Li ${titles.join(', ')}`);
        return {
          answer: {
            cards: refs.flatMap((ref) => this._read(board, ref)).join('\n'),
          },
        };
      }
      case 'answer': {
        try {
          const answered = await this._compose(turn, args);
          if ('error' in answered) {
            turn.trace.log('agent.emptyAnswer', { error: answered.error });
            return { answer: { error: answered.error } };
          }
          return { answer: { ok: true }, answered };
        } catch (error) {
          if (!(error instanceof Refusal || error instanceof HttpException)) {
            throw error;
          }
          turn.trace.log('agent.refused', { error: error.message });
          return { answer: { error: error.message } };
        }
      }
      default:
        return { answer: { error: `Unknown tool ${call.function.name}` } };
    }
  }

  /**
   * The model's `answer`, bound: each block it chose, filled in from the
   * board and the dry runs. A plan that fails is refused back to the model,
   * which answers again; any other block that breaks a limit is dropped and
   * the rest drawn. Only an answer with nothing left goes back.
   */
  private async _compose(
    turn: Turn,
    args: Record<string, unknown>,
  ): Promise<Answered | { error: string }> {
    const { board, trace } = turn;
    const dropped: string[] = [];
    const raw = (Array.isArray(args.blocks) ? args.blocks : []).filter(
      (it): it is Record<string, unknown> =>
        typeof it === 'object' && it !== null,
    );
    const items = raw.slice(0, MAX_BLOCKS);
    if (raw.length > MAX_BLOCKS) {
      dropped.push(`only ${MAX_BLOCKS} blocks are drawn`);
    }

    // The plan first: the choices beside it answer the same question.
    const planned = items.find((it) => it.type === 'plan');
    let plan: Plan | undefined;
    const beside: Choice[] = [];
    if (planned !== undefined) {
      const proposal = await this._propose(turn, planned);
      if (proposal.kind === 'doubt') {
        // A doubt replaces the plan, and everything else with it.
        trace.log('agent.doubt', { options: proposal.options.length });
        this._asked.set(turn.conversationId, proposal.options[0].plan.id);
        return {
          blocks: [
            { kind: 'caption', text: proposal.reply },
            {
              kind: 'choices',
              options: proposal.options.map((it) => ({
                label: it.label,
                plan: it.plan,
              })),
            },
          ],
        };
      }
      plan = proposal.plan;
      beside.push(
        ...proposal.options.map((it) => ({ label: it.label, plan: it.plan })),
      );
    }
    const group = plan?.id ?? randomUUID();

    const blocks: Block[] = [];
    let focus: Block | undefined;
    for (const item of items) {
      let block: Block | undefined;
      switch (item.type) {
        case 'plan':
          if (item !== planned) dropped.push('only one plan is drawn');
          else if (plan !== undefined)
            block = { kind: 'plan', plan: planView(plan) };
          break;
        case 'choices':
          block = await this._choices(turn, item, group, dropped);
          break;
        case 'day':
          block = this._dayBlock(turn, item, dropped);
          break;
        case 'cards':
          block = this._cardsBlock(turn, item, dropped);
          break;
        case 'artifact': {
          const artifact =
            typeof item.ref === 'string' ? board.artifact(item.ref) : undefined;
          if (artifact === undefined) {
            dropped.push(`no artifact ${String(item.ref)}`);
          } else {
            block = {
              kind: 'artifact',
              artifact: peekArtifact(board, artifact),
            };
          }
          break;
        }
        default:
          dropped.push(`unknown block type ${String(item.type)}`);
      }
      if (block === undefined) continue;
      blocks.push(block);
      if (item.focus === true && focus === undefined) focus = block;
    }

    // Deixar para depois sits beside the plan, with the model's own choices
    // when it gave some.
    if (beside.length > 0) {
      const choices = blocks.find((it) => it.kind === 'choices');
      if (choices !== undefined) {
        choices.options.push(...beside.slice(0, 3 - choices.options.length));
      } else {
        const at = blocks.findIndex((it) => it.kind === 'plan');
        blocks.splice(at + 1, 0, { kind: 'choices', options: beside });
      }
    }

    let caption: Block | undefined;
    if (typeof args.caption === 'string' && args.caption.trim() !== '') {
      const text = this._say(turn, args.caption);
      if (text.length > MAX_CAPTION) {
        dropped.push(`the caption is over ${MAX_CAPTION} characters`);
      } else {
        caption = { kind: 'caption', text };
      }
    }

    if (dropped.length > 0) trace.log('agent.dropped', { dropped });
    if (blocks.length === 0 && caption === undefined) {
      return {
        error: `Nothing could be drawn${dropped.length === 0 ? '' : `: ${dropped.join('; ')}`}. Call answer again.`,
      };
    }

    const offered = blocks
      .flatMap((it) => (it.kind === 'choices' ? it.options : []))
      .find((it) => it.plan !== undefined);
    if (offered?.plan !== undefined) {
      this._asked.set(turn.conversationId, offered.plan.id);
    }

    return {
      blocks: [
        ...(caption === undefined ? [] : [caption]),
        ...(focus === undefined ? [] : [focus]),
        ...blocks.filter((it) => it !== focus),
      ],
      plan,
    };
  }

  /** A choices block: 2–3 answers, each its own dry run or words to say. */
  private async _choices(
    turn: Turn,
    item: Record<string, unknown>,
    group: string,
    dropped: string[],
  ): Promise<Block | undefined> {
    const raw = (Array.isArray(item.options) ? item.options : []).filter(
      (it): it is Record<string, unknown> =>
        typeof it === 'object' && it !== null,
    );
    const options: Choice[] = [];

    for (const it of raw.slice(0, 3)) {
      const label = heading(
        this._say(turn, typeof it.label === 'string' ? it.label : ''),
      );
      if (label === '') {
        dropped.push('a choice with no label');
        continue;
      }
      const changes = Array.isArray(it.changes) ? it.changes : [];
      if (changes.length > 0) {
        try {
          const drafts = changes.map((change) =>
            this._draft(turn, change as Record<string, unknown>, false),
          );
          for (const draft of drafts) turn.steps.push(...draft.facts);
          const plan = await this._rehearse(turn, drafts, group);
          options.push({ label, plan: planView(plan) });
        } catch (error) {
          if (!(error instanceof Refusal || error instanceof HttpException)) {
            throw error;
          }
          dropped.push(`choice "${label}": ${error.message}`);
        }
      } else if (typeof it.say === 'string' && it.say.trim() !== '') {
        options.push({ label, say: this._say(turn, it.say).slice(0, 200) });
      } else {
        dropped.push(`choice "${label}" needs changes or say`);
      }
    }

    if (options.length < 2) {
      dropped.push('choices need 2 or 3 options that hold');
      return undefined;
    }
    return { kind: 'choices', options };
  }

  /** A day block: a slice of one day within reach, with its free room. */
  private _dayBlock(
    turn: Turn,
    item: Record<string, unknown>,
    dropped: string[],
  ): Block | undefined {
    const { board } = turn;
    const said = typeof item.day === 'string' ? item.day.trim() : 'hoje';
    const day = board.dayOf(said === '' ? 'hoje' : said);
    if (day === undefined) {
      dropped.push(`day "${said}" is out of reach`);
      return undefined;
    }

    const block = peekDay(
      board,
      day,
      minuteOf(item.from),
      minuteOf(item.to),
      item.free !== false,
    );
    if (Date.parse(block.from) >= Date.parse(block.to)) {
      dropped.push(
        `${said} ${String(item.from)}–${String(item.to)} is outside the working day`,
      );
      return undefined;
    }
    return block;
  }

  /** A cards block: up to 8 cards by ref, under the model's heading. */
  private _cardsBlock(
    turn: Turn,
    item: Record<string, unknown>,
    dropped: string[],
  ): Block | undefined {
    const { board } = turn;
    const refs = (Array.isArray(item.refs) ? item.refs : []).filter(
      (it): it is string => typeof it === 'string',
    );
    const cards = refs
      .map((ref) => {
        const card = board.ref(ref);
        if (card === undefined) dropped.push(`no card ${ref}`);
        return card;
      })
      .filter((it) => it !== undefined)
      .slice(0, MAX_CARDS);
    if (cards.length === 0) {
      dropped.push('a cards block with no card');
      return undefined;
    }

    const title =
      typeof item.title === 'string' && item.title.trim() !== ''
        ? heading(this._say(turn, item.title))
        : undefined;
    return {
      kind: 'cards',
      ...(title === undefined || title === '' ? {} : { title }),
      cards: cards.map((card) => peekCard(board, card, item.notes === true)),
    };
  }

  /**
   * Turns the model's changes into a plan, or into one question.
   *
   * The doubts the server can see for itself are found here, not left to
   * the model: something new with the name of a card already there is
   * asked about, with an answer to tap for each reading.
   */
  private async _propose(
    turn: Turn,
    args: Record<string, unknown>,
  ): Promise<Proposal> {
    const raw = Array.isArray(args.changes) ? args.changes : [];
    if (raw.length === 0)
      throw new Refusal('A plan needs at least one change.');

    const data = (args.data ?? {}) as Record<string, unknown>;
    const drafts = raw.map((item) =>
      this._draft(
        turn,
        item as Record<string, unknown>,
        typeof data.minutes === 'number',
      ),
    );
    for (const draft of drafts) turn.steps.push(...draft.facts);

    const doubt = await this._doubt(turn, drafts);
    if (doubt !== undefined) return doubt;

    const plan = await this._rehearse(turn, drafts);

    // Something new with no hour said: the hour is the agent's proposal,
    // and the backlog is always one tap away.
    const options: QuickReply[] = [];
    const fresh = drafts.filter(
      (it) => it.gesture.do !== 'swap' && it.gesture.new !== undefined,
    );
    const unsaid = typeof data.when !== 'string' || data.when.trim() === '';
    if (
      drafts.length === 1 &&
      fresh.length === 1 &&
      unsaid &&
      fresh[0].gesture.do !== 'to_backlog' &&
      fresh[0].gesture.do !== 'swap' &&
      fresh[0].gesture.new?.fixed !== true
    ) {
      const backlog = await this._rehearse(
        turn,
        [
          {
            ...fresh[0],
            gesture: { do: 'to_backlog', new: fresh[0].gesture.new },
          },
        ],
        plan.id,
      );
      options.push({ label: 'Deixar para depois', plan: planView(backlog) });
    }

    return { kind: 'plan', plan, options };
  }

  /**
   * The one question a plan needs before it can be made, when the server
   * can see it: something new named like a card already there. Each answer
   * is a plan of its own.
   */
  private async _doubt(
    turn: Turn,
    drafts: Draft[],
  ): Promise<Proposal | undefined> {
    const { board } = turn;

    for (const [index, draft] of drafts.entries()) {
      const thing = draft.gesture.do === 'swap' ? undefined : draft.gesture.new;
      if (thing === undefined || draft.duplicate) continue;

      const card = board.alike(thing.title).find((it) => !it.started);
      if (card === undefined) continue;

      const moved = this._asMove(draft, card);
      if (moved === undefined) {
        throw new Refusal(
          `"${card.title}" is already on the day (${card.ref}). Move it by its ref, or confirm with the person that this is another one and send duplicate: true.`,
        );
      }

      const group = randomUUID();
      const swapIn = (replacement: Draft) =>
        drafts.map((it, i) => (i === index ? replacement : it));
      const move = await this._rehearse(turn, swapIn(moved), group);
      const other = await this._rehearse(
        turn,
        swapIn({ ...draft, duplicate: true }),
        group,
      );

      const where =
        card.start === undefined
          ? 'no Depois eu priorizo'
          : `${board.dayLabel(card.day!)} às ${formatTimeIn(card.start, board.zone)}`;
      const to = move.changes[index]?.at;
      const going =
        to === undefined
          ? 'que muda'
          : `que vai para ${board.dayLabel(isoDayIn(new Date(to), board.zone))} às ${formatTimeIn(new Date(to), board.zone)}`;

      turn.steps.push(`Já existe ${board.describe(card)}`);

      return {
        kind: 'doubt',
        reply: `Você já tem ${card.title} ${where}. É esse ${going}, ou é outro compromisso?`,
        options: [
          {
            label:
              card.start === undefined
                ? 'Usar o do Depois eu priorizo'
                : `Mover o de ${board.dayLabel(card.day!)}`,
            plan: planView(move),
          },
          { label: 'É outro, marcar mais um', plan: planView(other) },
        ],
      };
    }

    return undefined;
  }

  /** [draft] made on [card] instead of on something new, when it can be. */
  private _asMove(draft: Draft, card: BoardCard): Draft | undefined {
    const g = draft.gesture;
    if (g.do === 'swap' || card.foreign) return undefined;
    if (card.kind === 'event' && g.do !== 'at_hour') return undefined;
    if (card.kind === 'task' && g.do === 'to_backlog' && card.backlog) {
      return undefined;
    }

    const gesture: Gesture =
      g.do === 'at_hour'
        ? { do: 'at_hour', id: card.id, at: g.at }
        : g.do === 'place'
          ? { do: 'place', id: card.id, after: g.after, before: g.before }
          : { do: 'to_backlog', id: card.id };
    return {
      ...draft,
      gesture,
      card,
      assumed: draft.assumed.filter((it) => it.kind !== 'minutes'),
      duplicate: true,
    };
  }

  /**
   * Makes [drafts] on a sandbox copy of the day, and files them as a plan
   * when the day they leave is what was asked for.
   */
  private async _rehearse(
    turn: Turn,
    drafts: Draft[],
    group?: string,
  ): Promise<Plan> {
    const { user, board, now, trace } = turn;
    const before = board.day;
    const hands = sandbox(user, before);
    const ids: string[] = [];

    for (const draft of drafts) {
      ids.push(await make(hands, user, draft.gesture, [], trace, now));
    }
    const after = await hands.timeline.day(user, HORIZON_DAYS, now);

    const changes = drafts.map((draft, i) =>
      this._view(board, after, draft, ids[i]),
    );

    // Nothing pushes an event, so one laid on another is two things at
    // once: the person is asked, never handed the overlap.
    changes.forEach((change, i) => {
      if (change.kind !== 'add_event' && change.kind !== 'move_event') return;
      const start = new Date(change.at!);
      const end = addMinutes(start, change.minutes);
      const under = board.cards.find(
        (card) =>
          card.kind === 'event' &&
          card.id !== drafts[i].card?.id &&
          card.start! < end &&
          card.end! > start,
      );
      if (under === undefined) return;
      throw new Refusal(
        `"${change.title}" at ${board.when(start)} would sit on ${under.ref} "${under.title}" (${board.when(under.start!)}), a fixed event: two things at once. Ask the person for another hour, or whether to move "${under.title}".`,
      );
    });

    // An hour asked for is kept, or the person is asked about it: the
    // layout gives an anchored task the first room after whatever is
    // already there, and nothing pushes an event.
    drafts.forEach((draft, i) => {
      const g = draft.gesture;
      if (g.do !== 'at_hour' || g.new?.fixed === true) return;
      if (draft.card?.kind === 'event') return;

      const landed = changes[i].at;
      if (landed === undefined || Date.parse(landed) <= Date.parse(g.at))
        return;

      const asked = new Date(g.at);
      const blocker = board.cards.find(
        (card) =>
          card.start !== undefined &&
          !ids.includes(card.id) &&
          card.start < new Date(landed) &&
          card.end! > asked,
      );
      throw new Refusal(
        `"${changes[i].title}" would not start at ${board.when(asked)} but at ${board.when(new Date(landed))}` +
          (blocker === undefined
            ? ', outside the working day.'
            : `: ${blocker.ref} "${blocker.title}" (${blocker.kind === 'event' ? 'a fixed event, never pushed' : 'a task that keeps its hour'}) is there. Move it in the same plan, or ask the person what to do.`),
      );
    });

    const named = new Set(ids);
    const pushed: Pushed[] = [];
    for (const task of before.tasks) {
      if (named.has(task.id) || before.live.has(task.id)) continue;
      const was = before.placed.get(task.id);
      const will = after.placed.get(task.id);
      if (was === undefined || will === undefined) continue;
      if (will.start.getTime() <= was.start.getTime()) continue;

      pushed.push({
        id: task.id,
        title: task.title,
        before: was.start.toISOString(),
        at: will.start.toISOString(),
      });
    }

    const plan = this._plans.put(user.id, {
      gestures: drafts.map((it) => it.gesture),
      changes,
      pushed: pushed
        .sort((a, b) => Date.parse(a.before) - Date.parse(b.before))
        .slice(0, MAX_PUSHED),
      assumed: dedupeAssumed(drafts.flatMap((it) => it.assumed)),
    });
    plan.group = group;

    return plan;
  }

  /** How the card draws [draft], made as card [id] on the day [after]. */
  private _view(
    board: Board,
    after: Day,
    draft: Draft,
    id: string,
  ): PlanChange {
    const g = draft.gesture;
    const thing: NewThing | undefined = g.do === 'swap' ? undefined : g.new;
    const card = draft.card;
    const common = {
      ...(card === undefined ? {} : { id: card.id }),
      title: thing?.title ?? card!.title,
      minutes: thing?.minutes ?? card!.minutes,
      ...(card?.start === undefined
        ? {}
        : { before: card.start.toISOString() }),
      routine: card?.routine ?? false,
    };

    if (g.do === 'to_backlog') return { kind: 'to_backlog', ...common };

    const event = after.events.find((it) => it.id === id);
    if (event !== undefined && event.taskId === undefined) {
      return {
        kind: thing === undefined ? 'move_event' : 'add_event',
        ...common,
        at: event.startTime,
      };
    }

    const interval = intervalOfTask(after, id);
    if (interval === undefined) {
      throw new Error(`The dry run lost "${common.title}"`);
    }

    return {
      kind: thing === undefined ? 'move_task' : 'add_task',
      ...common,
      at: interval.start.toISOString(),
      ...(draft.place === undefined ? {} : { place: draft.place }),
    };
  }

  /**
   * One of the model's changes, read: the refs resolved to cards, the day
   * and hour to an instant, and what was not said taken as a default that
   * the card then names. Refuses, in the model's terms, what cannot be.
   */
  private _draft(
    turn: Turn,
    item: Record<string, unknown>,
    lengthSaid: boolean,
  ): Draft {
    const { board, now } = turn;
    const kind = item.do;
    const facts: string[] = [];
    const assumed: Assumption[] = [];

    const cardOf = (value: unknown, what: string): BoardCard | undefined => {
      if (value === undefined || value === null || value === '')
        return undefined;
      const card = typeof value === 'string' ? board.ref(value) : undefined;
      if (card === undefined) {
        throw new Refusal(
          `No card ${JSON.stringify(value)} for ${what}. Use a ref from the board (t1, e1, b1), or read_timeline for other days.`,
        );
      }
      facts.push(`Achei ${board.describe(card)}`);
      return card;
    };
    const movable = (card: BoardCard) => {
      if (card.foreign) {
        throw new Refusal(
          `${card.ref} "${card.title}" is not Lunna's: it is never moved.`,
        );
      }
      if (card.started) {
        throw new Refusal(
          `${card.ref} "${card.title}" has already started: nothing begun is moved.`,
        );
      }
      return card;
    };

    const card = cardOf(item.ref, 'ref');
    if (card !== undefined) movable(card);

    const rawNew = item.new as Record<string, unknown> | undefined;
    let thing: NewThing | undefined;
    if (rawNew !== undefined && rawNew !== null) {
      if (card !== undefined)
        throw new Refusal('Give either ref or new, not both.');
      const title = typeof rawNew.title === 'string' ? rawNew.title.trim() : '';
      if (title === '') throw new Refusal('new needs a title.');
      const given =
        typeof rawNew.minutes === 'number' && Number.isFinite(rawNew.minutes);
      const minutes = given
        ? clampInt(rawNew.minutes, 5, 720, DEFAULT_MINUTES)
        : DEFAULT_MINUTES;
      // A length the person did not say is the agent's choice, whoever
      // picked it, and the card names it.
      if (!given || !lengthSaid) assumed.push({ kind: 'minutes', minutes });
      thing = {
        title: title.slice(0, 200),
        minutes,
        fixed: rawNew.fixed === true,
      };
    }
    const duplicate = item.duplicate === true;

    if (kind !== 'swap' && card === undefined && thing === undefined) {
      throw new Refusal(
        `${String(kind)} needs a ref (an existing card) or new (something new).`,
      );
    }
    const target = card === undefined ? { new: thing } : { id: card.id };

    switch (kind) {
      case 'place': {
        if (card?.kind === 'event' || thing?.fixed === true) {
          throw new Refusal(
            'A fixed event takes an hour, not a place in the queue: use at_hour.',
          );
        }
        const after = cardOf(item.after, 'after');
        const before = cardOf(item.before, 'before');
        if ((after ?? before)?.id === card?.id && card !== undefined) {
          throw new Refusal('A card cannot be placed next to itself.');
        }
        if (after?.backlog === true || before?.backlog === true) {
          throw new Refusal(
            'Backlog cards have no place in the queue: name cards from the day.',
          );
        }
        if (after === undefined && before === undefined)
          assumed.push({ kind: 'end_of_queue' });

        return {
          gesture: {
            do: 'place',
            ...target,
            after: after?.id,
            before: before?.id,
          },
          facts,
          assumed,
          card,
          place: { after: after?.title, before: before?.title },
          duplicate,
        };
      }

      case 'at_hour': {
        const day = this._day(turn, item.day, facts);
        const time =
          typeof item.time === 'string'
            ? /^(\d{1,2}):(\d{2})$/.exec(item.time.trim())
            : null;
        if (time === null || Number(time[1]) > 23 || Number(time[2]) > 59) {
          throw new Refusal(
            `at_hour needs time as HH:mm, got ${String(item.time)}.`,
          );
        }
        const [year, month, date] = day.split('-').map(Number);
        const at = instantOf(
          {
            year,
            month,
            day: date,
            hour: Number(time[1]),
            minute: Number(time[2]),
            second: 0,
          },
          board.zone,
        );
        if (at.getTime() < now.getTime() - 60_000) {
          throw new Refusal(
            `${board.when(at)} has already passed. Ask the person for another hour.`,
          );
        }

        const fixed = thing?.fixed === true || card?.kind === 'event';
        const window = board.window(day);
        const minutes = thing?.minutes ?? card!.minutes;
        if (
          !fixed &&
          (at < window.start || addMinutes(at, minutes) > window.end)
        ) {
          throw new Refusal(
            `${board.when(at)} is outside the working day (${formatTimeIn(window.start, board.zone)}–${formatTimeIn(window.end, board.zone)}): nothing is scheduled there. Ask the person.`,
          );
        }

        return {
          gesture: { do: 'at_hour', ...target, at: at.toISOString() },
          facts,
          assumed,
          card,
          duplicate,
        };
      }

      case 'first_free': {
        if (item.day === undefined || item.day === '')
          assumed.push({ kind: 'today' });
        const day = this._day(turn, item.day ?? 'hoje', facts);
        if (board.over(day)) {
          throw new Refusal(
            `The working day of ${board.dayLabel(day)} is over: nothing more fits. Ask the person whether amanhã will do.`,
          );
        }
        const minutes = thing?.minutes ?? card!.minutes;
        const room = board
          .free(day)
          .find(
            (it) => it.end.getTime() - it.start.getTime() >= minutes * 60_000,
          );
        if (room === undefined) {
          throw new Refusal(
            `There are no ${minutes} free minutes ${board.dayLabel(day)}. Ask the person.`,
          );
        }
        facts.push(
          `Livre ${board.dayLabel(day)}: ${formatTimeIn(room.start, board.zone)}–${formatTimeIn(room.end, board.zone)}`,
        );

        return {
          gesture: { do: 'at_hour', ...target, at: room.start.toISOString() },
          facts,
          assumed,
          card,
          duplicate,
        };
      }

      case 'to_backlog': {
        if (card?.kind === 'event' || thing?.fixed === true) {
          throw new Refusal(
            'Only tasks go to the backlog, never a fixed event.',
          );
        }
        if (card?.backlog === true) {
          throw new Refusal(`${card.ref} is already in the backlog.`);
        }
        return {
          gesture: { do: 'to_backlog', ...target },
          facts,
          assumed,
          card,
          duplicate,
        };
      }

      case 'swap': {
        const other = cardOf(item.with, 'with');
        if (card === undefined || other === undefined) {
          throw new Refusal('swap needs ref and with, two tasks on the day.');
        }
        movable(other);
        for (const it of [card, other]) {
          if (it.kind === 'event' || it.backlog) {
            throw new Refusal(
              `${it.ref} "${it.title}" cannot swap: only tasks on the day trade places.`,
            );
          }
        }
        return {
          gesture: { do: 'swap', id: card.id, with: other.id },
          facts,
          assumed,
          card,
          duplicate,
        };
      }

      default:
        throw new Refusal(
          `Unknown change "${String(kind)}": use place, at_hour, first_free, to_backlog or swap.`,
        );
    }
  }

  /** The day a change names, noting what a word like "amanhã" came to. */
  private _day(turn: Turn, value: unknown, facts: string[]): string {
    const { board } = turn;
    const said = typeof value === 'string' ? value.trim() : '';
    const day = said === '' ? undefined : board.dayOf(said);
    if (day === undefined) {
      throw new Refusal(
        `Unknown day "${said}". Use hoje, amanhã, a weekday, or YYYY-MM-DD from the date table, within ${HORIZON_DAYS} days.`,
      );
    }

    if (!/^\d{4}-\d{2}-\d{2}$/.test(said) && day !== board.today) {
      const word = said.charAt(0).toUpperCase() + said.slice(1).toLowerCase();
      const label = board.dayLabel(day);
      const date = `${day.slice(8, 10)}/${day.slice(5, 7)}`;
      facts.push(
        label.includes('/')
          ? `${word} é ${date}`
          : `${word} é ${weekdayPt(day)} ${date}`,
      );
    }

    return day;
  }

  /** Past conversations, searched by words and days. */
  private async _past(
    turn: Turn,
    args: Record<string, unknown>,
  ): Promise<{ step: string; snapshot: unknown }> {
    const { user, board, conversationId } = turn;
    const zone = board.zone;
    const text =
      typeof args.text === 'string' && args.text.trim() !== ''
        ? args.text.trim().slice(0, 80)
        : undefined;
    const day =
      typeof args.day === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(args.day)
        ? args.day
        : undefined;
    const from =
      day === undefined ? undefined : startOfDayIn(noonOf(day, zone), zone);

    const found = await this._conversations.search(user, {
      text,
      from,
      until:
        from === undefined
          ? undefined
          : startOfDayIn(addDaysIn(from, 1, zone), zone),
      exclude: conversationId,
      limit: MAX_FOUND,
    });

    const what = [
      text === undefined ? undefined : `"${text}"`,
      day === undefined ? undefined : board.dayLabel(day),
    ].filter((it) => it !== undefined);

    return {
      step:
        `Procurei nas conversas${what.length === 0 ? '' : `: ${what.join(', ')}`}` +
        (found.length === 0 ? ', sem nada' : ''),
      snapshot: {
        messages: found.map((message) => ({
          conversation: message.conversationId,
          at: wallText(new Date(message.at), zone),
          role: message.role,
          text: message.text,
          plan:
            message.plan === undefined
              ? undefined
              : {
                  status: message.planStatus ?? 'proposed',
                  changes: message.plan.changes.map((change) => ({
                    kind: change.kind,
                    title: change.title,
                    at:
                      change.at === undefined
                        ? 'backlog'
                        : wallText(new Date(change.at), zone),
                  })),
                },
        })),
      },
    };
  }
}

/** "2026-10-16T08:00", a wall clock the model reads. */
function wallText(at: Date, zone: Zone): string {
  return isoIn(at, zone).slice(0, 16);
}

function weekdayPt(day: string): string {
  return ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'][
    new Date(`${day}T12:00:00Z`).getUTCDay()
  ];
}

function clampInt(
  value: unknown,
  min: number,
  max: number,
  fallback: number,
): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;

  return Math.min(max, Math.max(min, Math.round(value)));
}

/** A heading or a label, cut to fit. */
function heading(text: string): string {
  const said = text.trim();
  return said.length <= MAX_HEADING
    ? said
    : `${said.slice(0, MAX_HEADING - 1).trimEnd()}…`;
}

/** "13:30" as minutes after midnight ("24:00" is the end of the day). */
function minuteOf(value: unknown): number | undefined {
  if (typeof value !== 'string') return undefined;
  const time = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (time === null) return undefined;
  const minute = Number(time[1]) * 60 + Number(time[2]);
  return Number(time[2]) > 59 || minute > 24 * 60 ? undefined : minute;
}

function dedupe(lines: string[]): string[] {
  return [...new Set(lines)];
}

function dedupeAssumed(assumed: Assumption[]): Assumption[] {
  const seen = new Set<string>();
  return assumed.filter((it) => {
    const key = JSON.stringify(it);
    return !seen.has(key) && seen.add(key);
  });
}

/** A plan as the app draws it. */
function planView(plan: Plan): PlanView {
  return {
    id: plan.id,
    changes: plan.changes,
    pushed: plan.pushed,
    assumed: plan.assumed,
  };
}
