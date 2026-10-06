import { RoutineDays } from '../../calendar/calendar.types';
import { StartNowGuard } from '../timing';

/**
 * Which heading a card sits under.
 *
 * A section is a stretch of clock, not a judgement. Nothing stores one and
 * nothing drags a card between them. "agora" is what is running; "dia" is
 * everything after it, under the day it falls on ([TimelineCard.day]), as
 * far ahead as the screen asks for.
 */
export type TimelineSection = 'agora' | 'dia';

/**
 * What a card is.
 *
 * A task is something to do, with a place in the queue and an hour the
 * queue gives it. An event is a block of time that is the point of itself:
 * a fixed block, a day of a routine, a meeting. The list shows only tasks;
 * the calendar shows both.
 */
export type CardKind = 'task' | 'event';

/** One card, on the list or on the calendar. */
export class TimelineCard {
  /**
   * The task id for a task, the event id for an event, and the id the API
   * addresses it by under `/tasks` or `/events`.
   */
  id: string;
  kind: CardKind;
  title: string;
  /** The heading it falls under, worked out from the clock when it was read. */
  section: TimelineSection;
  /** "2026-09-21", the day it starts on, in the person's zone. */
  day: string;
  /** ISO 8601 start. */
  startTime: string;
  /** ISO 8601 end. */
  endTime: string;
  durationMinutes: number;
  /** Whether the hour is the point of it. Never true of a task. */
  fixed: boolean;
  /**
   * Whether Lunna booked it.
   *
   * A card that is not managed is somebody else's meeting: it is drawn so the
   * screen says what the calendar says, and it cannot be dragged, finished or
   * talked to, because none of that is Lunna's to do with it.
   */
  managed: boolean;
  /** Free text the user keeps on it. */
  notes: string;
  /** ISO 8601, when it was paused. Absent while it runs or has not started. */
  pausedAt?: string;
  /** Seconds of work still owed, while paused. */
  remainingSeconds?: number;
  /** Seconds spent paused before the current pause. */
  pausedSeconds: number;
  /**
   * How long the work itself takes, pauses left out.
   *
   * [durationMinutes] is the span on the calendar, which a pause stretches.
   * This is what the user estimated and what a progress bar fills against.
   */
  workMinutes: number;
  /**
   * Whether it is a task the user has begun.
   *
   * A begun task has an hour of its own on the calendar, and is the one
   * that pauses, runs late and finishes.
   */
  started: boolean;
  /**
   * Whether its hour has come and it is waiting for the user to begin.
   *
   * Only a task ever waits. Until the user says so it sits at the current
   * minute, sliding with the clock, and the card asks rather than counting
   * down.
   */
  awaitingStart: boolean;
  /** ISO 8601, the earliest a layout may start it, when there is one. */
  notBefore?: string;
  /** Which days it repeats on, when it is an instance of a routine. */
  routine?: RoutineDays;
}

/**
 * The day, as the screen draws it.
 *
 * Both views of it at once, from one read, so the list and the calendar
 * can never tell different stories.
 */
export class Timeline {
  /**
   * Every task still to do, in queue order: what is running first, then
   * the queue, each at the hour the queue gives it. All of them, however
   * far ahead the last one lands.
   */
  tasks: TimelineCard[];
  /**
   * Everything the calendar draws, earliest first, from now to the end of
   * the last day asked for: the events and the tasks that fall in it.
   */
  cards: TimelineCard[];
  /**
   * The question a move raised, when it raised one. While it is here
   * nothing about the move has happened.
   */
  guard?: StartNowGuard;
}

/** What the creation sheet said when the user wrote down a fixed block. */
export interface EventRequest {
  title: string;
  durationMinutes: number;
  /** ISO 8601, the hour that is the point of it. */
  startTime: string;
}

/** What the detail screen can change about a fixed block. */
export interface EventEdit {
  title?: string;
  /** The work, pauses left out. */
  workMinutes?: number;
  /** ISO 8601. A new hour for it. */
  startTime?: string;
  /** Free text kept on the block. */
  notes?: string;
}

/** What the creation sheet said when the user wrote down a task. */
export interface TaskRequest {
  title: string;
  minutes: number;
  /**
   * ISO 8601, the earliest it may start, when it was written down from a
   * tap on empty room further down the day.
   */
  notBefore?: string;
}

/** What the detail screen can change about a task. */
export interface TaskEdit {
  title?: string;
  /** The work, pauses left out. */
  workMinutes?: number;
  notes?: string;
}
