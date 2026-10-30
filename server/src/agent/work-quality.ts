import { createHash } from 'crypto';
import type {
  ArtifactsAnswer,
  ArtifactView,
  GoalView,
} from '../artifacts/artifact.types';

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
  /** The share of the running goal's days gone, 0–1. */
  timeGone: number;
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
      return { score, topic: level, goal, counted, facts: facts() };
    }
    score++;
  }
  return { score, topic: 'keep', goal, counted, facts: {} };
}

/**
 * What a suggestion about [quality] is made from, hashed: its topic and its
 * facts. A change to the very thing it is about hides it; a change to
 * anything else leaves it.
 */
export function basisOf(quality: WorkQuality): string {
  return createHash('sha256')
    .update(JSON.stringify([quality.topic, quality.facts]))
    .digest('hex');
}

/** The request the server writes for a turn about [quality]: the person asked nothing. */
export function requestOf(quality: WorkQuality): string {
  return [
    'Nobody asked: this is the suggestion the app shows on its home, written by the server for the person.',
    `Topic (Work Quality level ${quality.score + 1} of 7, never named to the person): ${quality.topic}. ${TOPICS[quality.topic]}`,
    `Facts: ${JSON.stringify(quality.facts)}`,
    'Propose the one next step: a plan when one fits (with a preview block when it makes a goal or a delivery), choices when the person must say something first. The caption is the whole message on the card, at most 80 characters, speaking to the person. Set followUp to the hours until you look again: 3 when a step is under way today, 24 when the next step is tomorrow’s.',
  ].join('\n');
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
    'There is no routine, and you cannot write one: say in the caption that a routine around the month’s work (an hour, the days, a checklist) goes in Rotina, in the account menu, and propose no plan.',
  pace: 'The goal is behind its pace. Propose the next task of the delivery that brings in the most, at an hour today.',
  keep: 'Everything is defined and on pace. Propose the next task of the main delivery, or nothing but a short word of encouragement.',
};

/** A goal's last day, `YYYY-MM-DD` (its view's `end` is the day after). */
function lastDayOf(goal: GoalView): string {
  const end = new Date(`${goal.end}T12:00:00Z`);
  end.setUTCDate(end.getUTCDate() - 1);
  return end.toISOString().slice(0, 10);
}
