import { randomUUID } from 'crypto';
import {
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  Optional,
} from '@nestjs/common';
import { ANALYTICS, NoAnalytics } from '../analytics/analytics';
import type { Analytics } from '../analytics/analytics';
import { ConfigService } from '@nestjs/config';
import { CalendarService } from '../calendar/calendar.service';
import { CalendarUser } from '../calendar/calendar.types';
import { Timeline } from '../events/entities/event.entity';
import { Trace } from '../common/trace';
import { EventLayoutService } from '../events/event-layout.service';
import { TimelineService } from '../events/timeline.service';
import { MemoryRhythmStore } from '../rhythm/rhythm.store';
import { RhythmService } from '../rhythm/rhythm.service';
import { ArtifactStore } from '../artifacts/artifact.store';
import { ArtifactsService } from '../artifacts/artifacts.service';
import { addDays, daysBetween, endOfMonth } from '../artifacts/stretch';
import { RoutinesService } from '../routines/routines.service';
import { TaskStore } from '../tasks/task.store';
import { UsersService } from '../users/users.service';
import {
  addMinutes,
  DEFAULT_WORK_DAY,
  nextFreeSlot,
  parseMinuteOfDay,
  roundUpToFiveMinutes,
  workWindowFor,
} from '../time/work-hours';
import {
  addDaysIn,
  formatTimeIn,
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
  PreviewItem,
  summary,
  toA2ui,
} from './answer';
import {
  actionOf,
  ACTIONS,
  DEFAULT_SHAPE,
  Draft,
  Refusal,
  Resolving,
  SCHEMA_SHAPES,
  SchemaShape,
  Subject,
} from './actions';
import { SYSTEM_PROMPT, toolsFor } from './agent.prompt';
import { Board, BoardArtifact, BoardCard, HORIZON_DAYS, noonOf } from './board';
import { ConversationStore, PlanStatus } from './conversation.store';
import {
  Hands,
  handsOver,
  Made,
  make,
  NO_WORK_DAYS,
  sandbox,
  Seed,
  snapshot,
  takeBack,
  undoOf,
  WorkDays,
} from './gestures';
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
  MemoryPlanStore,
  NewPlan,
  newOf,
  Plan,
  PlanChange,
  PlanStore,
  Pushed,
} from './plan';
import { ToolDefinition } from './openrouter.client';
import {
  MemorySuggestionStore,
  NewSuggestion,
  Opening,
  StoredSuggestion,
  SuggestionKind,
  SuggestionStore,
} from './suggestion.store';
import { appliesOf } from './speech';
import { basisOf, requestOf, workQuality, WorkQuality } from './work-quality';

export type { Subject } from './actions';

/** One message of the conversation, as the app keeps it. */
export interface AgentMessage {
  role: 'user' | 'assistant';
  text: string;
  /** How long it took to say, when the user spoke it. */
  voiceSeconds?: number;
}

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
  /** The hours the model said to look again after this turn, as it said them. */
  followUp?: number;
}

/** The one thing the agent offers without being asked, as the app reads it. */
export interface Suggestion {
  id: string;
  /** `welcome` is drawn by the app's own words; the others by [text]. */
  kind: SuggestionKind;
  /** Its Work Quality topic, or a template's focus. Never drawn. */
  focus: string;
  text: string;
  /** ISO 8601: when the next one is made. Null for the welcome. */
  nextAt: string | null;
  /** [nextAt] for builds before it, never null. */
  validUntil: string;
  /** Made from the card, with no conversation. */
  action?: { label: string; plan: PlanView };
  /** The agent's first message in a conversation opened from it. */
  opening: Opening;
}

/** What a template is about, in the order it looks. */
type SuggestionFocus = 'goal' | 'delivery' | 'routine';

/** What `_offer` works out, before anything is filed. */
interface Offer {
  focus: SuggestionFocus;
  /** What the card says. */
  text: string;
  /** What the conversation opens on. */
  opening: string;
  /** The delivery it is about, drawn in the opening. */
  artifact?: BoardArtifact;
  action?: { label: string; at: string; plan: NewPlan };
  choices: Choice[];
}

/** Everything one turn works from. */
interface Turn {
  user: CalendarUser;
  conversationId: string;
  board: Board;
  /** The rows the board was read from, which every dry run starts from. */
  seed: Seed;
  about?: Subject;
  now: Date;
  trace: Trace;
  steps: string[];
  calls: number;
  usage: ModelUsage;
  leaks: number;
  raw: string[];
  /** What each plan rehearsed would make, as its tabs draw it, by plan id. */
  previews: Map<string, PreviewItem[]>;
}

/** What a plan block came to. */
type Proposal =
  | { kind: 'plan'; plan: Plan; options: QuickReply[] }
  | { kind: 'doubt'; reply: string; options: QuickReply[] };

/** A turn's answer, bound: the blocks, and the plans behind them. */
interface Answered {
  blocks: Block[];
  plan?: Plan;
  followUp?: number;
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

/** How many conversations' refs are kept in memory. */
const MAX_CONVERSATIONS_HELD = 500;

/** A delete that takes more tasks with it than this is asked about first. */
const MAX_SILENT_CASCADE = 3;

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
  private readonly _plans: PlanStore;
  private readonly _suggestions: SuggestionStore;
  /** The tools, a plan's changes in the shape `AGENT_SCHEMA` names. */
  private readonly _tools: ToolDefinition[];
  private readonly _deliveries: ArtifactsService;
  private readonly _routines: RoutinesService;
  /** Where the working day is kept; nowhere in the tests that leave it out. */
  private readonly _users: WorkDays;
  private readonly _rhythm: RhythmService;
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
    @Optional() plans?: PlanStore,
    @Optional() config?: ConfigService,
    @Optional() suggestions?: SuggestionStore,
    @Optional()
    @Inject(ANALYTICS)
    private readonly _analytics: Analytics = new NoAnalytics(),
    @Optional() users?: UsersService,
    @Optional() rhythm?: RhythmService,
  ) {
    this._users = users ?? NO_WORK_DAYS;
    this._rhythm = rhythm ?? new RhythmService(new MemoryRhythmStore());
    this._plans = plans ?? new MemoryPlanStore();
    this._suggestions = suggestions ?? new MemorySuggestionStore();
    this._tools = toolsFor(schemaShapeOf(config?.get<string>('AGENT_SCHEMA')));
    this._deliveries = handsOver(
      _calendar,
      _tasks,
      _artifacts,
      _timeline,
      _layout,
    ).deliveries;
    this._routines = new RoutinesService(_calendar);
  }

  get configured(): boolean {
    return this._model.configured;
  }

  private get _hands(): Hands {
    return {
      timeline: this._timeline,
      layout: this._layout,
      calendar: this._calendar,
      tasks: this._tasks,
      artifacts: this._artifacts,
      deliveries: this._deliveries,
      routines: this._routines,
      users: this._users,
      rhythm: this._rhythm,
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
    suggestionId?: string,
  ): Promise<TurnResult> {
    const conversation = conversationId ?? randomUUID();
    // Opened from a suggestion: its opening is the agent's first message,
    // as the server wrote it, not as the app sent it back.
    const held =
      suggestionId === undefined
        ? undefined
        : await this._suggestions.current(user.id);
    const opening = held?.id === suggestionId ? held?.opening : undefined;
    if (opening !== undefined) {
      const first = history.findIndex((it) => it.role === 'user');
      history = [
        { role: 'assistant', text: opening.reply },
        ...history.slice(first),
      ];
    }
    const asked = this._asked.get(conversation);
    if (asked !== undefined) {
      this._asked.delete(conversation);
      const option = await this._plans.get(user.id, asked);
      if (
        option !== undefined &&
        option.applied === undefined &&
        !(await this._plans.answered(option))
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
      ...(opening === undefined || conversationId !== undefined
        ? []
        : [
            {
              role: 'assistant' as const,
              text: opening.reply,
              steps: [],
              plan: opening.plan,
              // Before the question.
              at: new Date(now.getTime() - 1),
            },
          ]),
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

    // Talked about: the next suggestion counts from this message.
    if (held !== undefined && opening !== undefined) {
      await this._answered(user, held, 'answeredAt', answer.followUp, now);
    }

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

    const kind = board.kind(ref);
    if (kind !== undefined) return [`  ${board.kindLine(kind)}`];
    const goal = board.goal(ref);
    if (goal !== undefined) return [`  ${board.goalLine(goal)}`];

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
    const [day, artifacts, artifactTasks, categories, types, goals, routines] =
      await Promise.all([
        this._timeline.day(user, HORIZON_DAYS, now),
        this._artifacts.list(user),
        this._tasks.ofArtifacts(user),
        this._artifacts.categories(user),
        this._artifacts.types(user),
        this._artifacts.goals(user),
        this._calendar.routines(user),
      ]);
    const seed: Seed = {
      day,
      artifacts,
      artifactTasks,
      categories,
      types,
      goals,
      routines,
    };
    const board = new Board(day, this._timeline.view(day), {
      refs: this._refsOf(conversationId),
      ...seed,
    });
    const subject =
      about === undefined
        ? ''
        : `\n\n${await this._subject(user, about, board)}`;
    const turn: Turn = {
      user,
      conversationId,
      board,
      seed,
      about,
      now,
      trace,
      steps: [],
      calls: 0,
      usage: { promptTokens: 0, completionTokens: 0, cachedTokens: 0, cost: 0 },
      leaks: 0,
      raw: [],
      previews: new Map(),
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
    const { blocks, plan, followUp } = answered;
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
      ...(followUp === undefined ? {} : { followUp }),
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
    tools = this._tools,
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
    const plan = await this._plans.get(user.id, planId);
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
    if (await this._plans.answered(plan)) {
      throw new AgentError(
        'refused',
        'Essa pergunta já foi respondida com outra opção.',
        HttpStatus.CONFLICT,
      );
    }

    const hands = this._hands;
    const touched: string[] = [];
    const made: Made = new Map();
    // Read once first, so what a read writes by itself (the days of
    // routines, a paused block's end) is not taken for the plan's.
    await hands.timeline.day(user, 1, now);
    const before = await snapshot(hands, user, now);

    try {
      for (const gesture of plan.gestures) {
        touched.push(await make(hands, user, gesture, made, trace, now));
      }
    } catch (error) {
      trace.warn('agent.applyFailed', {
        planId,
        error: error instanceof Error ? error.message : String(error),
      });
      await takeBack(
        hands,
        user,
        undoOf(before, await snapshot(hands, user, now)),
        now,
      );
      throw new AgentError(
        'drift',
        'Seu dia mudou desde esse plano e ele não cabe mais. Peça de novo.',
        HttpStatus.CONFLICT,
      );
    }

    plan.applied = {
      undo: undoOf(before, await snapshot(hands, user, now)),
      touched,
    };
    await this._plans.save(plan);
    await this._mark(user, plan.group ?? planId, 'applied', trace);
    // From the card or from the conversation, the suggestion is taken.
    const held = await this._suggestions.current(user.id);
    if (held?.action?.planId === planId) {
      await this._answered(user, held, 'takenAt', undefined, now);
    }
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
    const plan = await this._plans.get(user.id, planId);
    if (plan?.applied === undefined) {
      throw new AgentError(
        'refused',
        'Não há mais o que desfazer.',
        HttpStatus.NOT_FOUND,
      );
    }

    await takeBack(this._hands, user, plan.applied.undo);
    // Back to a proposal: the card offers Aplicar again.
    plan.applied = undefined;
    await this._plans.save(plan);
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
   * The one thing worth offering without being asked: a turn the agent
   * asks itself about the person's first unmet Work Quality level, kept
   * until its `nextAt`.
   *
   * Code picks the topic (`workQuality`); the model writes the words, the
   * plan and when to look again. A person who never had one finds the
   * welcome, fixed words that never expire. Once answered (Aplicar, ✕, a
   * message in the conversation it opened) or once what it is about
   * changes, it hides until `nextAt`, when the next turn reads the day as it
   * is then. A turn that cannot be had falls back to the arithmetic
   * template (`_offer`).
   */
  async suggestion(
    user: CalendarUser,
    now = new Date(),
  ): Promise<Suggestion | undefined> {
    const [day, artifacts, artifactTasks, types, goals, routines, answer] =
      await Promise.all([
        this._timeline.day(user, HORIZON_DAYS, now),
        this._artifacts.list(user),
        this._tasks.ofArtifacts(user),
        this._artifacts.types(user),
        this._artifacts.goals(user),
        this._calendar.routines(user),
        this._deliveries.answer(user, now),
      ]);
    const view = this._timeline.view(day);
    const board = new Board(day, view, {
      artifacts,
      artifactTasks,
      types,
      goals,
      routines,
    });
    const running = board.goals.find(
      (it) => it.goal.starts <= board.today && board.today <= it.goal.deadline,
    );
    const quality = workQuality({
      today: board.today,
      answer,
      routines: routines.length,
      timeGone: running === undefined ? 0 : running.view.timeGone,
      mark: day.rhythm === undefined ? undefined : board.mark(board.today),
    });
    const basis = basisOf(quality);

    const held = await this._suggestions.current(user.id);
    if (held === undefined) {
      // Someone who already set a goal by hand is past the welcome.
      return quality.topic === 'goal'
        ? this._welcome(user, quality, basis, now)
        : this._write(user, board, view, quality, basis, now);
    }

    if (held.kind === 'welcome' && held.answeredAt === undefined) {
      if (quality.topic !== 'goal') {
        return this._write(user, board, view, quality, basis, now);
      }
      if (held.dismissedAt !== undefined && now < held.nextAt!) {
        return undefined;
      }
      return suggestionView(held, undefined);
    }

    if (held.nextAt !== undefined && now < held.nextAt) {
      if (
        held.takenAt !== undefined ||
        held.dismissedAt !== undefined ||
        held.answeredAt !== undefined ||
        held.basis !== basis
      ) {
        return undefined;
      }
      if (held.action === undefined) return suggestionView(held, undefined);
      const plan = await this._plans.get(user.id, held.action.planId);
      // Its plan lived its two hours, or was applied some other way: the
      // turn is asked again, of the day as it is now.
      if (plan !== undefined && plan.applied === undefined) {
        return suggestionView(held, plan);
      }
    }

    return this._write(user, board, view, quality, basis, now);
  }

  /** Puts away [suggestionId], the ✕: the welcome for a day, a turn until its `nextAt`. */
  async dismiss(
    user: CalendarUser,
    suggestionId: string,
    now = new Date(),
  ): Promise<void> {
    const held = await this._suggestions.current(user.id);
    if (held?.id !== suggestionId) {
      throw new AgentError(
        'refused',
        'Essa sugestão já mudou.',
        HttpStatus.NOT_FOUND,
      );
    }
    const nextAt =
      held.nextAt ??
      intoWorkDay(
        new Date(now.getTime() + DEFAULT_FOLLOW_UP * 3_600_000),
        user,
        this._timeline.zone(user),
      );
    await this._suggestions.answer(user.id, held.id, {
      dismissedAt: now,
      nextAt,
    });
    this.onNextAt?.(user.id, nextAt);
  }

  /**
   * Called with each `nextAt` written: the timer (`SuggestionTimer`) arms
   * itself there, so the next suggestion is ready when the phone rings.
   */
  onNextAt?: (userId: string, at: Date) => void;

  /** Every suggestion's next turn still to come, for the timer to re-arm at boot. */
  pendingSuggestions(now: Date) {
    return this._suggestions.pending(now);
  }

  /** [held] answered at [now]: the next one comes [followUp] hours later. */
  private async _answered(
    user: CalendarUser,
    held: StoredSuggestion,
    answer: 'takenAt' | 'answeredAt',
    followUp: number | undefined,
    now: Date,
  ): Promise<void> {
    const nextAt = nextAtOf(
      now,
      followUp ?? held.followUp,
      user,
      this._timeline.zone(user),
    );
    await this._suggestions.answer(user.id, held.id, {
      [answer]: now,
      nextAt,
    });
    this.onNextAt?.(user.id, nextAt);
  }

  /** The welcome, filed: no model, no expiry, the app draws its words. */
  private async _welcome(
    user: CalendarUser,
    quality: WorkQuality,
    basis: string,
    now: Date,
  ): Promise<Suggestion> {
    const blocks: Block[] = [{ kind: 'caption', text: WELCOME_QUESTION }];
    const kept = await this._suggestions.put(
      user.id,
      {
        kind: 'welcome',
        focus: quality.topic,
        text: WELCOME_QUESTION,
        opening: {
          ui: toA2ui(`welcome-${randomUUID().slice(0, 8)}`, blocks),
          reply: WELCOME_QUESTION,
          steps: [],
          options: [],
        },
        basis,
        workQuality: quality.score,
      },
      now,
    );
    this._measure(user, kept);
    return suggestionView(kept, undefined);
  }

  /**
   * A new suggestion about [quality]: the turn the agent asks itself, or the
   * template when there is no model or the turn fails.
   */
  private async _write(
    user: CalendarUser,
    board: Board,
    view: Timeline,
    quality: WorkQuality,
    basis: string,
    now: Date,
  ): Promise<Suggestion | undefined> {
    const zone = board.zone;
    let made: NewSuggestion | undefined;
    let plan: Plan | undefined;

    if (this._model.configured) {
      const trace = Trace.start(user.id, 'suggestion');
      try {
        const turn = await this._answer(
          user,
          randomUUID(),
          [{ role: 'user', text: requestOf(quality) }],
          undefined,
          undefined,
          trace,
          now,
        );
        plan =
          turn.plan === undefined
            ? undefined
            : await this._plans.get(user.id, turn.plan.id);
        const caption = turn.blocks.find((it) => it.kind === 'caption');
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        const { blocks, leaks, raw, followUp, ...opening } = turn;
        made = {
          kind: 'turn',
          focus: quality.topic,
          text: caption?.text ?? turn.reply,
          ...(plan === undefined
            ? {}
            : { action: { label: 'Aplicar', planId: plan.id } }),
          opening,
          basis,
          workQuality: quality.score,
          followUp: clampFollowUp(followUp),
          nextAt: nextAtOf(now, followUp, user, zone),
        };
      } catch (error) {
        trace.warn('agent.suggestionFailed', {
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    made ??= await this._template(user, board, view, quality, basis, now);
    if (made === undefined) return undefined;
    if (made.kind === 'template') {
      plan =
        made.action === undefined
          ? undefined
          : await this._plans.get(user.id, made.action.planId);
    }

    const kept = await this._suggestions.put(user.id, made, now);
    this._measure(user, kept);
    if (kept.nextAt !== undefined) this.onNextAt?.(user.id, kept.nextAt);
    return suggestionView(kept, plan);
  }

  /** The arithmetic suggestion of #67, written when the turn cannot be had. */
  private async _template(
    user: CalendarUser,
    board: Board,
    view: Timeline,
    quality: WorkQuality,
    basis: string,
    now: Date,
  ): Promise<NewSuggestion | undefined> {
    const offer = this._offer(user, board, view, now);
    if (offer === undefined) return undefined;

    const plan =
      offer.action === undefined
        ? undefined
        : await this._plans.put(user.id, offer.action.plan);
    const blocks: Block[] = [
      { kind: 'caption', text: offer.opening },
      ...(offer.artifact === undefined
        ? []
        : [
            {
              kind: 'artifact' as const,
              artifact: peekArtifact(board, offer.artifact),
            },
          ]),
      ...(plan === undefined
        ? []
        : [{ kind: 'plan' as const, plan: planView(plan) }]),
      ...(offer.choices.length === 0
        ? []
        : [{ kind: 'choices' as const, options: offer.choices }]),
    ];

    return {
      kind: 'template',
      focus: offer.focus,
      text: offer.text,
      ...(plan === undefined || offer.action === undefined
        ? {}
        : { action: { label: offer.action.label, planId: plan.id } }),
      opening: {
        ui: toA2ui(`suggestion-${randomUUID().slice(0, 8)}`, blocks),
        reply: summary(board, blocks),
        steps: [],
        ...(plan === undefined ? {} : { plan: planView(plan) }),
        options: [],
      },
      basis,
      workQuality: quality.score,
      nextAt: nextAtOf(now, undefined, user, board.zone),
    };
  }

  /** Phase 0 of the RFC: the score, as a number, each time one is written. */
  private _measure(user: CalendarUser, kept: StoredSuggestion): void {
    this._analytics.capture(user.id, SUGGESTION_EVENT, {
      work_quality: kept.workQuality,
      topic: kept.focus,
      kind: kept.kind,
      plan: kept.action !== undefined,
    });
  }

  /** What to offer now, in the order the agent looks. */
  private _offer(
    user: CalendarUser,
    board: Board,
    view: Timeline,
    now: Date,
  ): Offer | undefined {
    const zone = board.zone;
    const today = board.today;
    const free = (minutes: number) => {
      const slot = nextFreeSlot(
        roundUpToFiveMinutes(now),
        minutes,
        view.cards.map((card) => ({
          start: new Date(card.startTime),
          end: new Date(card.endTime),
        })),
        zone,
        user.workDay ?? DEFAULT_WORK_DAY,
      );
      return sameDayIn(slot.start, now, zone) ? slot.start : undefined;
    };
    const placing = (
      task: { id: string; title: string; minutes: number; routine: boolean },
      at: Date,
    ): Offer['action'] => ({
      label: `Encaixar às ${formatTimeIn(at, zone)}`,
      at: at.toISOString(),
      plan: {
        gestures: [{ do: 'at_hour', id: task.id, at: at.toISOString() }],
        changes: [
          {
            kind: 'move_task',
            id: task.id,
            title: task.title,
            minutes: task.minutes,
            at: at.toISOString(),
            routine: task.routine,
          },
        ],
        pushed: [],
        assumed: [],
      },
    });

    // 1. The goal: none running, or nothing open that counts towards it.
    const goal = board.goals.find(
      (it) => it.goal.starts <= today && today <= it.goal.deadline,
    );
    if (goal === undefined) {
      const last = [...board.goals].sort((a, b) =>
        b.goal.deadline.localeCompare(a.goal.deadline),
      )[0];
      const by = goalDeadline(today);
      const amounts =
        last === undefined
          ? [5000, 10000]
          : [last.goal.target, roundTo(last.goal.target * 1.2, 500)];
      return {
        focus: 'goal',
        text:
          `Você ainda não tem um objetivo. Quanto quer faturar até ${ddmm(by)}? ` +
          'Com esse número eu sei o que adiantar a cada dia.',
        opening:
          `Quanto você quer faturar até ${ddmm(by)}? Me diz um valor e eu ` +
          'monto o objetivo, com as entregas que já estão abertas.',
        choices: [...new Set(amounts)].map((amount) => ({
          label: reais(amount),
          say: `Quero faturar ${reais(amount)} até ${ddmm(by)}.`,
        })),
      };
    }

    const { target, done } = goal.view;
    if (done < target && goal.view.queuedCount === 0) {
      const kinds = board.kinds
        .filter((it) => (it.type.price ?? 0) > 0)
        .slice(0, 2);
      return {
        focus: 'goal',
        text:
          `Faltam ${reais(target - done)} para o objetivo de ` +
          `${ddmm(goal.goal.deadline)}, e nenhuma entrega aberta vence até ` +
          'lá. Qual é a próxima?',
        opening:
          `Nenhuma entrega aberta conta para os ${reais(target)} até ` +
          `${ddmm(goal.goal.deadline)}. O que você vai entregar até lá?`,
        choices:
          kinds.length === 0
            ? [
                {
                  label: 'Criar uma entrega',
                  say: 'Quero criar uma entrega para esse objetivo.',
                },
                { label: 'Mudar o objetivo', say: 'Quero mudar o objetivo.' },
              ]
            : kinds.map((it) => ({
                label: it.type.name,
                say: `Quero criar uma entrega de ${it.type.name} até ${ddmm(goal.goal.deadline)}.`,
              })),
      };
    }

    // 2. A delivery: the goal is behind what its days ask by now.
    const asked = target * goal.view.timeGone;
    if (done < target && done < asked) {
      const short = reais(target - done);
      const counted = board.artifacts
        .filter(
          (it) =>
            it.artifact.doneAt === undefined &&
            it.artifact.deadline !== undefined &&
            it.artifact.deadline <= goal.goal.deadline &&
            (it.artifact.value ?? 0) > 0,
        )
        .sort(
          (a, b) =>
            a.artifact.deadline!.localeCompare(b.artifact.deadline!) ||
            (b.artifact.value ?? 0) - (a.artifact.value ?? 0),
        );
      for (const it of counted) {
        const due = ddmm(it.artifact.deadline!);
        const open = it.tasks
          .filter((task) => task.doneAt === undefined)
          .map((task) => board.reach(task));
        if (open.length === 0) {
          return {
            focus: 'delivery',
            text:
              `Faltam ${short} para o objetivo, e “${it.artifact.title}” ` +
              `vence ${due} sem nenhuma tarefa. Vamos dividir em partes?`,
            opening: `“${it.artifact.title}” vence ${due} e ainda não tem tarefas. Por onde começa?`,
            artifact: it,
            choices: [],
          };
        }
        if (open.some((card) => card.day === today)) continue;

        const next = [
          ...open
            .filter((card) => card.start !== undefined && !card.started)
            .sort((a, b) => a.start!.getTime() - b.start!.getTime()),
          ...open.filter((card) => card.start === undefined),
        ][0];
        if (next === undefined) continue;
        const at = free(next.minutes);
        if (at === undefined) continue;
        const hour = formatTimeIn(at, zone);
        return {
          focus: 'delivery',
          text:
            `Faltam ${short} para o objetivo, e “${it.artifact.title}” ` +
            `vence ${due}. Encaixo “${next.title}” hoje às ${hour}?`,
          opening:
            `Faltam ${short} para os ${reais(target)}. “${it.artifact.title}” ` +
            `vence ${due} e é o que mais adianta: encaixo “${next.title}” hoje às ${hour}.`,
          artifact: it,
          action: placing(next, at),
          choices: [],
        };
      }
    }

    // 3. The day: what waits in Para depois and fits in what is left.
    for (const task of view.backlog.slice(0, 3)) {
      const at = free(task.durationMinutes);
      if (at === undefined) continue;
      const hour = formatTimeIn(at, zone);
      return {
        focus: 'routine',
        text:
          `"${task.title}" está esperando no Para depois. ` +
          `Hoje às ${hour} tem espaço para ela. Quer encaixar?`,
        opening: `"${task.title}" cabe hoje às ${hour}. Encaixo?`,
        action: placing(
          {
            id: task.id,
            title: task.title,
            minutes: task.durationMinutes,
            routine: task.routine !== undefined,
          },
          at,
        ),
        choices: [],
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
        case 'preview': {
          const items =
            plan === undefined ? undefined : turn.previews.get(plan.id);
          if (plan === undefined || items === undefined || items.length === 0) {
            dropped.push(
              'a preview needs a plan that makes a goal or a delivery',
            );
          } else {
            block = {
              kind: 'preview',
              items,
              applies: appliesOf(plan.changes),
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

    // A preview is read before the plan it shows, which it then stands for.
    const ordered = [
      ...(focus === undefined ? [] : [focus]),
      ...blocks.filter((it) => it !== focus),
    ];
    const preview = ordered.findIndex((it) => it.kind === 'preview');
    const planAt = ordered.findIndex((it) => it.kind === 'plan');
    if (preview > planAt && planAt >= 0) {
      ordered.splice(planAt, 0, ...ordered.splice(preview, 1));
    }
    const followUp =
      typeof args.followUp === 'number' ? args.followUp : undefined;

    return {
      blocks: [...(caption === undefined ? [] : [caption]), ...ordered],
      plan,
      ...(followUp === undefined ? {} : { followUp }),
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
          const drafts = this._drafts(turn, changes, false);
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
    const drafts = this._drafts(turn, raw, typeof data.minutes === 'number');
    for (const draft of drafts) turn.steps.push(...draft.facts);

    const doubt = await this._doubt(turn, drafts);
    if (doubt !== undefined) return doubt;

    const plan = await this._rehearse(turn, drafts);

    // Something new with no hour said: the hour is the agent's proposal,
    // and the backlog is always one tap away.
    const options: QuickReply[] = [];
    const fresh = drafts.filter((it) => newOf(it.gesture) !== undefined);
    const unsaid = typeof data.when !== 'string' || data.when.trim() === '';
    const thing = fresh.length === 1 ? newOf(fresh[0].gesture) : undefined;
    if (
      drafts.length === 1 &&
      thing !== undefined &&
      unsaid &&
      fresh[0].gesture.do !== 'to_backlog' &&
      thing.fixed !== true
    ) {
      const backlog = await this._rehearse(
        turn,
        [{ ...fresh[0], gesture: { do: 'to_backlog', new: thing } }],
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

    const cascade = await this._cascade(turn, drafts);
    if (cascade !== undefined) return cascade;

    for (const [index, draft] of drafts.entries()) {
      const thing = newOf(draft.gesture);
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
          ? 'no Para depois'
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
                ? 'Usar o do Para depois'
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
    if (card.foreign) return undefined;
    if (g.do !== 'at_hour' && g.do !== 'place' && g.do !== 'to_backlog') {
      return undefined;
    }
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
    const { board, now, trace } = turn;
    // A copy: set_work_day gives the sandbox's person other hours.
    const user = { ...turn.user };
    const before = board.day;
    const hands = sandbox(
      user,
      turn.seed,
      drafts.some((it) => it.gesture.do.endsWith('_routine')),
    );
    const ids: string[] = [];
    const made: Made = new Map();

    for (const draft of drafts) {
      ids.push(await make(hands, user, draft.gesture, made, trace, now));
    }
    const after = await hands.timeline.day(user, HORIZON_DAYS, now);

    const changes = drafts.map((draft, i) => {
      const action = actionOf(draft.gesture.do);
      if (action?.line === undefined) {
        throw new Error(`Nothing draws ${draft.gesture.do}`);
      }
      return action.line({ board, after, drafts }, draft, ids[i]);
    });

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

    const plan = await this._plans.put(user.id, {
      gestures: drafts.map((it) => it.gesture),
      changes,
      pushed: pushed
        .sort((a, b) => Date.parse(a.before) - Date.parse(b.before))
        .slice(0, MAX_PUSHED),
      assumed: dedupeAssumed(drafts.flatMap((it) => it.assumed)),
      group,
    });
    turn.previews.set(plan.id, await previewsOf(hands, user, drafts, ids, now));
    return plan;
  }

  /**
   * A delete that takes more than a few tasks with it is asked about once,
   * before any plan: all of them, or only the delivery.
   */
  private async _cascade(
    turn: Turn,
    drafts: Draft[],
  ): Promise<Proposal | undefined> {
    const index = drafts.findIndex(
      (it) =>
        it.gesture.do === 'remove_artifact' &&
        !it.gesture.keepTasks &&
        (it.view?.takes?.length ?? 0) > MAX_SILENT_CASCADE,
    );
    if (index < 0) return undefined;

    const draft = drafts[index];
    const going = draft.view!.takes!.length;
    const group = randomUUID();
    const swapIn = (replacement: Draft) =>
      drafts.map((it, i) => (i === index ? replacement : it));
    const all = await this._rehearse(turn, drafts, group);
    const only = await this._rehearse(
      turn,
      swapIn({
        ...draft,
        gesture: {
          ...(draft.gesture as { do: 'remove_artifact'; id: string }),
          keepTasks: true,
        },
      }),
      group,
    );

    return {
      kind: 'doubt',
      reply: `A entrega ${draft.view!.title} leva junto ${going} tarefas do Para depois. Apago todas, ou só a entrega?`,
      options: [
        { label: `Apagar as ${going}`, plan: planView(all) },
        { label: 'Só a entrega', plan: planView(only) },
      ],
    };
  }

  /**
   * A plan's changes, read in order, each through its action: an earlier
   * change may name what it makes (`as`) for the later ones.
   */
  private _drafts(turn: Turn, raw: unknown[], lengthSaid: boolean): Draft[] {
    const declared: Resolving['declared'] = new Map();
    return raw.map((item) =>
      this._draft(
        turn,
        (item ?? {}) as Record<string, unknown>,
        lengthSaid,
        declared,
      ),
    );
  }

  /**
   * One of the model's changes, read by the action it names: the refs
   * resolved to cards, the day and hour to an instant, and what was not said
   * taken as a default that the card then names. Refuses, in the model's
   * terms, what cannot be.
   */
  private _draft(
    turn: Turn,
    item: Record<string, unknown>,
    lengthSaid: boolean,
    declared: Resolving['declared'],
  ): Draft {
    const { board, now } = turn;
    const action = actionOf(item.do);
    if (action === undefined) {
      throw new Refusal(
        `Unknown change "${String(item.do)}": use ${ACTIONS.map((it) => it.name).join(', ')}.`,
      );
    }
    // An argument the verb does not take is refused, not guessed at; an
    // empty one (the flat shape lets the model fill every field) is not one.
    for (const [key, value] of Object.entries(item)) {
      if (key === 'do' || key in action.args) continue;
      if (value === undefined || value === null || value === '') continue;
      if (value === false) continue;
      throw new Refusal(`${action.name} takes no ${key}.`);
    }

    const facts: string[] = [];
    const r: Resolving = {
      board,
      now,
      about: turn.about,
      lengthSaid,
      declared,
      facts,
      assumed: [],
      card(value, what) {
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
      },
      movable(card) {
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
      },
      artifact(value, what) {
        if (value === undefined || value === null || value === '')
          return undefined;
        const it =
          typeof value === 'string' ? board.artifact(value) : undefined;
        if (it === undefined) {
          throw new Refusal(
            `No delivery ${JSON.stringify(value)} for ${what}. Use a delivery ref from the board (p1).`,
          );
        }
        facts.push(`Achei a entrega ${it.artifact.title}`);
        return it;
      },
      day: (value) => this._day(turn, value, facts),
    };

    return action.resolve(r, item);
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

/** The shape `AGENT_SCHEMA` names, or the default for anything else. */
function schemaShapeOf(value: string | undefined): SchemaShape {
  return SCHEMA_SHAPES.includes(value as SchemaShape)
    ? (value as SchemaShape)
    : DEFAULT_SHAPE;
}

/** [held] as the app reads it, its action's plan as filed. */
function suggestionView(
  held: StoredSuggestion,
  plan: Plan | undefined,
): Suggestion {
  return {
    id: held.id,
    kind: held.kind,
    focus: held.focus,
    text: held.text,
    nextAt: held.nextAt?.toISOString() ?? null,
    // Builds before `nextAt` read this, and cannot read a null.
    validUntil: (
      held.nextAt ?? new Date(held.createdAt.getTime() + 24 * 3_600_000)
    ).toISOString(),
    ...(held.action === undefined || plan === undefined
      ? {}
      : { action: { label: held.action.label, plan: planView(plan) } }),
    opening: held.opening,
  };
}

/** The welcome's question: the chat opens on it. The card draws its own words. */
const WELCOME_QUESTION = 'Quanto você quer faturar este mês?';

/** The hours until the next suggestion when a turn says nothing. */
export const DEFAULT_FOLLOW_UP = 24;

/** What a turn may say about its follow-up, in hours. */
const FOLLOW_UP_RANGE = { min: 3, max: 24 };

/** Captured each time a suggestion is written, with `work_quality`. */
export const SUGGESTION_EVENT = 'suggestion_written';

/** [hours] held to 3–24, or 24 when none was given. */
export function clampFollowUp(hours: number | undefined): number {
  if (hours === undefined || !Number.isFinite(hours)) return DEFAULT_FOLLOW_UP;
  return Math.min(
    FOLLOW_UP_RANGE.max,
    Math.max(FOLLOW_UP_RANGE.min, Math.round(hours)),
  );
}

/**
 * When the next suggestion comes: [followUp] hours (3–24, 24 by default)
 * after [answered], moved into the working day, so none lands at 23:00.
 */
export function nextAtOf(
  answered: Date,
  followUp: number | undefined,
  user: CalendarUser,
  zone: Zone,
): Date {
  return intoWorkDay(
    new Date(answered.getTime() + clampFollowUp(followUp) * 3_600_000),
    user,
    zone,
  );
}

/** [at], or the start of the next working day when it falls outside one. */
export function intoWorkDay(at: Date, user: CalendarUser, zone: Zone): Date {
  const window = workWindowFor(at, zone, user.workDay ?? DEFAULT_WORK_DAY);
  return at < window.start ? window.start : at;
}

/**
 * The day a new goal would be asked to reach by: the end of this month, or
 * of the next when this one has less than a week left.
 */
function goalDeadline(today: string): string {
  const end = endOfMonth(today);
  return daysBetween(today, end) < 7 ? endOfMonth(addDays(end, 1)) : end;
}

/** [value] rounded to the nearest [step]. */
function roundTo(value: number, step: number): number {
  return Math.round(value / step) * step;
}

/** Whole reais as a person reads them: R$ 10.000. */
function reais(value: number): string {
  return `R$ ${Math.round(value)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
}

/** `2026-11-30` as a person reads it: 30/11. */
function ddmm(day: string): string {
  return `${day.slice(8, 10)}/${day.slice(5, 7)}`;
}

/**
 * What [drafts] made on the sandbox [hands], as the tabs will draw it: each
 * new goal, and the goal running today when a new delivery counts towards
 * it, with what its open deliveries bring (the plan's included); then each
 * new delivery; then each routine written or changed, as Rotina will have
 * it. Nothing when the plan makes none of them.
 */
async function previewsOf(
  hands: Hands,
  user: CalendarUser,
  drafts: Draft[],
  ids: string[],
  now: Date,
): Promise<PreviewItem[]> {
  const made = (kind: string) =>
    ids.filter((_, i) => drafts[i].gesture.do === kind);
  const newGoals = made('new_goal');
  const newArtifacts = made('new_artifact');
  const routineIds = [...made('new_routine'), ...made('edit_routine')];
  const routines = (
    routineIds.length === 0 ? [] : await hands.routines.list(user)
  )
    .filter((it) => routineIds.includes(it.id))
    .map((it): PreviewItem => ({
      type: 'routine',
      title: it.title,
      start: parseMinuteOfDay(it.time) ?? 0,
      minutes: it.durationMinutes,
      days: it.days,
      checklist: it.checklist,
    }));
  if (newGoals.length === 0 && newArtifacts.length === 0) return routines;

  const answer = await hands.deliveries.answer(user, now);
  const today = isoDayIn(now, hands.timeline.zone(user));
  const artifacts = answer.artifacts.filter((it) =>
    newArtifacts.includes(it.id),
  );
  const running = answer.goals.find(
    (it) =>
      it.start <= today &&
      today < it.end &&
      artifacts.some(
        (a) => a.deadline !== null && a.deadline < it.end && (a.value ?? 0) > 0,
      ),
  );
  const goals = answer.goals.filter(
    (it) => newGoals.includes(it.id) || it === running,
  );

  return [
    ...goals.map((it): PreviewItem => ({
      type: 'goal',
      target: it.target,
      start: it.start,
      end: it.end,
      done: it.done,
      queued: it.queued,
      queuedCount: it.queuedCount,
    })),
    ...artifacts.map((it): PreviewItem => ({
      type: 'artifact',
      title: it.title,
      minutes: it.minutes,
      ...(it.deadline === null ? {} : { deadline: it.deadline }),
      ...(it.value === null ? {} : { value: it.value }),
    })),
    ...routines,
  ];
}
