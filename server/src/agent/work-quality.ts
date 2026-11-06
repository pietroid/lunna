import { createHash } from 'crypto';
import type {
  ArtifactsAnswer,
  ArtifactView,
  GoalView,
} from '../artifacts/artifact.types';
import type { DayMark } from '../time/day-kinds';
import type { Task } from '../tasks/task.types';
import type { PastSuggestion } from './suggestion.store';

/**
 * Work Quality: how defined a person's plan is, in seven levels, each one
 * arithmetic on what Entregas and Objetivos already read. The first level
 * not met is what the one suggestion is about; the count met is the score
 * (`work_quality`, 0–7), sent to PostHog as a number and never drawn.
 *
 * Levels run top to bottom: no goal outranks everything, and the routine
 * comes after the work, since it is built around what the month holds.
 * See `product/research/2026-10-29-agentic-suggestions/`.
 */
export const LEVELS = [
  'goal',
  'reach',
  'shape',
  'tasks',
  'fits',
  'routine',
  'pace',
] as const;

export type Level = (typeof LEVELS)[number];

/** A level, or `keep` when every one is met. */
export type Topic = Level | 'keep';

/** What the levels are measured on. */
export interface QualityState {
  /** `YYYY-MM-DD` in the person's zone. */
  today: string;
  /** Entregas and Objetivos, as their routes answer. */
  answer: Pick<ArtifactsAnswer, 'artifacts' | 'goals' | 'schedule'>;
  /** How many routines the person has written. */
  routines: number;
  /** The share of the running goal's working time gone, 0–1. */
  timeGone: number;
  /** What kind of day today is, when the person keeps a rhythm. */
  mark?: DayMark;
}

/** A person's Work Quality: the score, the topic, and its facts. */
export interface WorkQuality {
  /** How many levels are met, 0–7. */
  score: number;
  topic: Topic;
  /** The goal running today, if one is. */
  goal?: GoalView;
  /** The open deliveries due by the running goal's last day, in queue order. */
  counted: ArtifactView[];
  /**
   * What the topic is about, in the model's terms: the request the server
   * writes for the turn, and (hashed) its basis.
   */
  facts: Record<string, unknown>;
  /** Today's kind, when it is not a working day: the turn is told. */
  rest?: DayMark;
}

/** The pace a goal may fall behind its days before it is behind: 15 %. */
export const PACE_SLACK = 0.15;

/** [state]'s Work Quality. */
export function workQuality(state: QualityState): WorkQuality {
  const { today, answer } = state;
  const goal = answer.goals.find(
    (it) => it.start <= today && today < it.end && it.kind === 'money',
  );
  const open = answer.artifacts.filter((it) => it.doneAt === null);
  const counted =
    goal === undefined
      ? []
      : open.filter(
          (it) =>
            it.deadline !== null &&
            it.deadline < goal.end &&
            (it.value ?? 0) > 0,
        );
  // The main delivery: Entregas' first that counts, or else its first.
  const main = counted[0] ?? open[0];
  const unshaped = open.filter(
    (it) =>
      it.deadline === null || (it.value ?? 0) <= 0 || (it.minutes ?? 0) <= 0,
  );
  const { needMinutes, freeMinutes } = answer.schedule;
  const rest =
    state.mark === undefined || state.mark.kind === 'work'
      ? {}
      : { rest: state.mark };

  const checks: [Level, () => boolean, () => Record<string, unknown>][] = [
    ['goal', () => goal !== undefined, () => ({ goals: answer.goals.length })],
    [
      'reach',
      () => goal!.done + goal!.queued >= goal!.target,
      () => ({
        target: goal!.target,
        lastDay: lastDayOf(goal!),
        done: goal!.done,
        queued: goal!.queued,
        deliveries: counted.map((it) => it.title),
        short: goal!.target - goal!.done - goal!.queued,
      }),
    ],
    [
      'shape',
      () => unshaped.length === 0,
      () => ({
        deliveries: unshaped.map((it) => ({
          title: it.title,
          missing: [
            ...(it.deadline === null ? ['deadline'] : []),
            ...((it.value ?? 0) <= 0 ? ['value'] : []),
            ...((it.minutes ?? 0) <= 0 ? ['minutes'] : []),
          ],
        })),
      }),
    ],
    [
      'tasks',
      () =>
        main === undefined ||
        main.tasks.some((task) => task.doneAt === undefined),
      () => ({ delivery: main.title, deadline: main.deadline }),
    ],
    [
      'fits',
      () => needMinutes <= freeMinutes,
      () => ({
        needMinutes,
        freeMinutes,
        until: answer.schedule.until,
      }),
    ],
    ['routine', () => state.routines > 0, () => ({ routines: 0 })],
    [
      'pace',
      () => goal!.done >= goal!.target * (state.timeGone - PACE_SLACK),
      () => ({
        target: goal!.target,
        lastDay: lastDayOf(goal!),
        done: goal!.done,
        askedByNow: Math.round(goal!.target * state.timeGone),
      }),
    ],
  ];

  let score = 0;
  for (const [level, met, facts] of checks) {
    if (!met()) {
      return { score, topic: level, goal, counted, facts: facts(), ...rest };
    }
    score++;
  }
  return { score, topic: 'keep', goal, counted, facts: {}, ...rest };
}

/** A task paused in Pendentes long enough that it is worth a word. */
export const STUCK_PENDING_DAYS = 3;
/** A task written down this many days ago and still not done. */
export const WAITING_DAYS = 7;
/** A task short enough that it is done soon, unless it is overdue. */
export const QUICK_MINUTES = 15;
/** At most this many candidates per topic. */
const TACTICAL_PER_KIND = 3;

/** What a tactical suggestion is about: one task, beside the Work Quality topic. */
export type TacticalTopic = 'quick' | 'stuck' | 'waiting';

/** One task the suggestion could be about: quick, long stuck, or long waiting. */
export interface Tactical {
  topic: TacticalTopic;
  title: string;
  minutes: number;
  where: 'queue' | 'pending' | 'backlog';
  days?: number;
  overdue?: boolean;
}

/**
 * The day's tactical candidates, one task each. A task begun, done,
 * cancelled or a routine's day is no candidate. For each task only the
 * first that applies: stuck (paused in Pendentes for days), waiting
 * (written down long ago, still not done) then quick (short, or overdue in
 * the queue). At most [TACTICAL_PER_KIND] of each, stuck and waiting oldest
 * first, quick in queue order, then stuck, waiting, quick.
 */
export function tacticalOf(
  tasks: Task[],
  backlog: Task[],
  begun: ReadonlySet<string>,
  now: Date,
): Tactical[] {
  const skip = (task: Task) =>
    task.doneAt !== undefined ||
    task.cancelled === true ||
    task.routineId !== undefined ||
    begun.has(task.id);
  const seen = new Set<string>();
  const stuck: Tactical[] = [];
  const waiting: Tactical[] = [];
  const quick: Tactical[] = [];

  for (const task of backlog) {
    if (seen.has(task.id) || skip(task)) continue;
    if (task.pendingAt === undefined) continue;
    const days = daysAgo(task.pendingAt, now);
    if (days >= STUCK_PENDING_DAYS) {
      stuck.push({
        topic: 'stuck',
        title: task.title,
        minutes: task.minutes,
        where: 'pending',
        days,
      });
      seen.add(task.id);
    }
  }

  for (const task of [...tasks, ...backlog]) {
    if (seen.has(task.id) || skip(task)) continue;
    if (task.pendingAt !== undefined || task.createdAt === undefined) continue;
    const days = daysAgo(task.createdAt, now);
    if (days >= WAITING_DAYS) {
      waiting.push({
        topic: 'waiting',
        title: task.title,
        minutes: task.minutes,
        where: task.backlog ? 'backlog' : 'queue',
        days,
      });
      seen.add(task.id);
    }
  }

  for (const task of tasks) {
    if (seen.has(task.id) || skip(task)) continue;
    const overdue =
      task.notBefore !== undefined && new Date(task.notBefore) < now;
    if (task.minutes <= QUICK_MINUTES || overdue) {
      quick.push({
        topic: 'quick',
        title: task.title,
        minutes: task.minutes,
        where: 'queue',
        ...(overdue ? { overdue: true } : {}),
      });
      seen.add(task.id);
    }
  }

  const oldestFirst = (a: Tactical, b: Tactical) =>
    (b.days ?? 0) - (a.days ?? 0);
  return [
    ...stuck.sort(oldestFirst).slice(0, TACTICAL_PER_KIND),
    ...waiting.sort(oldestFirst).slice(0, TACTICAL_PER_KIND),
    ...quick.slice(0, TACTICAL_PER_KIND),
  ];
}

/** Whole days between [at] and [now], rounded down. */
function daysAgo(at: string, now: Date): number {
  return Math.floor((now.getTime() - new Date(at).getTime()) / 86_400_000);
}

/**
 * What a suggestion about [quality] is made from, hashed: its topic, its
 * facts, and the tactical candidates of its topic when it chose one (none
 * for a tier topic, so its hash is as before). A change to the very
 * thing it is about hides it; a change to anything else leaves it.
 */
export function basisOf(
  quality: WorkQuality,
  tactical: Tactical[] = [],
): string {
  const basis: unknown[] = [quality.topic, quality.facts];
  if (tactical.length > 0) {
    basis.push(tactical.map((it) => [it.topic, it.title]));
  }
  return createHash('sha256').update(JSON.stringify(basis)).digest('hex');
}

/** The request the server writes for a turn about [quality]: the person asked nothing. */
export function requestOf(
  quality: WorkQuality,
  context?: { history: PastSuggestion[]; tactical: Tactical[]; now: Date },
): string {
  const lines = [
    'Nobody asked: this is the suggestion the app shows on its home, written by the server for the person.',
    `Topic (Work Quality level ${quality.score + 1} of 7, never named to the person): ${quality.topic}. ${TOPICS[quality.topic]}`,
    `Facts: ${JSON.stringify(quality.facts)}`,
    ...(quality.rest === undefined ? [] : [restOf(quality.rest)]),
  ];
  if (context !== undefined) {
    if (context.history.length > 0) {
      lines.push(
        `Your last suggestions to this person, newest first: ${context.history
          .map((it) => historyLine(it, context.now))
          .join('; ')}.`,
      );
    }
    if (context.tactical.length > 0) {
      lines.push(
        `Tactical candidates, one task each: ${context.tactical
          .map(tacticalLine)
          .join('; ')}. What each means: ${TACTICAL_LEGEND}.`,
      );
    }
    lines.push(PRIORITISE);
  }
  lines.push(
    'Propose the one next step: a plan when one fits (with a preview block when it makes a goal, a delivery or a routine), choices when the person must say something first. The caption is the whole message on the card, at most 80 characters, speaking to the person. Set followUp to the hours until you look again, 1 to 4: 1 when a step is under way right now, 4 otherwise; the server moves it into the working day.',
  );
  return lines.join('\n');
}

/** One past suggestion, as the model is told of it, oldest worded in time. */
function historyLine(it: PastSuggestion, now: Date): string {
  const kind = it.kind === 'welcome' ? ' (welcome)' : '';
  return `${it.focus}${kind}, ${it.outcome} ${ago(it.createdAt, now)} ago`;
}

/** One tactical candidate, as the model is told of it. */
function tacticalLine(it: Tactical): string {
  if (it.topic === 'stuck') {
    return `stuck "${it.title}" (in Pendentes ${it.days} days)`;
  }
  if (it.topic === 'waiting') {
    const where = it.where === 'backlog' ? 'Para depois' : 'the queue';
    return `waiting "${it.title}" (in ${where} ${it.days} days)`;
  }
  return `quick "${it.title}" (${it.minutes} min in the queue${it.overdue === true ? ', its hour has passed' : ''})`;
}

/** How long ago [at] was, in hours under two days, then in days. */
function ago(at: Date, now: Date): string {
  const hours = Math.max(
    1,
    Math.round((now.getTime() - at.getTime()) / 3_600_000),
  );
  if (hours < 48) return `${hours} hour${hours === 1 ? '' : 's'}`;
  return `${Math.round((now.getTime() - at.getTime()) / 86_400_000)} days`;
}

/** What the turn is told of each tactical topic, as a one-line legend. */
const TACTICAL: Record<TacticalTopic, string> = {
  stuck: 'paused in Pendentes for days',
  waiting: 'written down long ago, still not done',
  quick: 'short or overdue, done soon',
};
const TACTICAL_LEGEND = (['stuck', 'waiting', 'quick'] as const)
  .map((it) => `${it}: ${TACTICAL[it]}`)
  .join('; ');

const PRIORITISE =
  'Pick the one topic that matters most to this person now: the Work Quality topic above, a tactical candidate when it matters more, or another topic when they have been turning this one down. Even one refusal counts: weigh it, there is no fixed rule. A tactical suggestion proposes one gesture they could make by hand on that one task (start it, give it an hour, move it to another day or to Para depois, or drop it), as a plan. Set topic to what you chose.';

/**
 * What the turn is told of a day that is not a working one: no delivery's
 * task belongs on it, and offering to move one off it comes first.
 */
function restOf(mark: DayMark): string {
  const kind = mark.kind === 'off' ? 'a day off' : 'a light day';
  return `Today is ${kind} (${mark.reason ?? 'rest'}${mark.cycle === undefined ? '' : `, cycle day ${mark.cycle.day}, ${mark.cycle.phase}`}): no delivery's task belongs on it. When one of the main delivery's tasks sits on today, propose moving it to the next working day before anything else, and keep the words gentle.`;
}

/** What each topic asks of the turn. */
const TOPICS: Record<Topic, string> = {
  goal: 'No goal is running. Ask how much they want to bill by the end of the month, with choices of amounts.',
  reach:
    'The open deliveries due by the goal’s last day do not reach it. Propose the deliveries that close the gap (ask their names and values with choices when you cannot know them).',
  shape:
    'Some open deliveries miss a deadline, a value or a length. Propose the missing ones, asking with choices for what only the person knows.',
  tasks:
    'The main delivery has no open task. Propose its first tasks, on the day or in its backlog.',
  fits: 'The work owed by the end of the month does not fit the free hours. Propose what to move: a later deadline, less time, or a delivery dropped.',
  routine:
    'There is no routine. Propose one around the month’s work with new_routine (an hour, the days, a checklist of its steps) and a preview block; set_work_day in the same plan when the working day should open or close at other hours for it. Ask with choices first when the hour or the days are only the person’s to say.',
  pace: 'The goal is behind its pace. Propose the next task of the delivery that brings in the most, at an hour today.',
  keep: 'Everything is defined and on pace. Propose the next task of the main delivery, or nothing but a short word of encouragement.',
};

/** A goal's last day, `YYYY-MM-DD` (its view's `end` is the day after). */
function lastDayOf(goal: GoalView): string {
  const end = new Date(`${goal.end}T12:00:00Z`);
  end.setUTCDate(end.getUTCDate() - 1);
  return end.toISOString().slice(0, 10);
}
