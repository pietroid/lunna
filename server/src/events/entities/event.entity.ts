import { ChecklistItem, RoutineDays } from '../../calendar/calendar.types';
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
  /**
   * How many minutes it has run past its planned end with nobody saying it
   * was over ("atrasado N min"), when it has. Its end is dragged along with
   * the clock meanwhile, and the queue after it slides.
   */
  overtimeMinutes?: number;
  /**
   * ISO 8601, the hour a task not yet begun is anchored at, when it is.
   *
   * An anchored task keeps that hour and the queue flows around it; it only
   * slides when something really happening runs into it. Absent for a task
   * that takes its turn in the queue.
   */
  notBefore?: string;
  /** Which days it repeats on, when it is an instance of a routine. */
  routine?: RoutineDays;
  /** The artifact a task belongs to, named so the card can say so. */
  artifact?: CardArtifact;
  /**
   * A routine's day's own list (breakfast: the coffee, the dishes), each
   * item ticked off or not, when the routine has one.
   */
  checklist?: ChecklistItem[];
}

/**
 * A task waiting in the backlog: "Para depois".
 *
 * It has an order and a length and no hour, so it carries none of a card's
 * hours. It reaches the calendar only once it is dragged into the queue.
 */
/** The artifact a task belongs to, as a card names it. */
export interface CardArtifact {
  id: string;
  title: string;
}

export class BacklogCard {
  id: string;
  kind: 'task';
  title: string;
  section: 'backlog';
  /** How long the work takes. */
  durationMinutes: number;
  /** The same as [durationMinutes]: nothing in the backlog was begun. */
  workMinutes: number;
  notes: string;
  /** Which days it repeats on, when it is a day of a routine. */
  routine?: RoutineDays;
  artifact?: CardArtifact;
  checklist?: ChecklistItem[];
}

/**
 * A task that was finished, as the archive in Menu draws it.
 *
 * Shaped like a card so the app reads it as one: its start and its end are
 * both the moment it was done, which is the hour the archive shows and
 * files it under ([day]).
 */
export class DoneCard {
  id: string;
  kind: 'task';
  title: string;
  notes: string;
  /** ISO 8601, when it was finished. */
  doneAt: string;
  /** The same as [doneAt]. */
  startTime: string;
  /** The same as [doneAt]. */
  endTime: string;
  /** "2026-09-21", the day it was done on, in the person's zone. */
  day: string;
  /** How long it was meant to take. */
  durationMinutes: number;
  workMinutes: number;
  artifact?: CardArtifact;
}

/**
 * The day, as the screen draws it.
 *
 * Both views of it at once, from one read, so the list and the calendar
 * can never tell different stories.
 */
export class Timeline {
  /**
   * Every task still to do, in the order of their hours: what is running
   * first, then the rest, each at the hour the layout gives it. All of them,
   * however far ahead the last one lands.
   */
  tasks: TimelineCard[];
  /** Every task in the backlog, in its order, with no hours. */
  backlog: BacklogCard[];
  /**
   * Everything the calendar draws, earliest first, from now to the end of
   * the last day asked for: the events and the tasks that fall in it.
   */
  cards: TimelineCard[];
  /**
   * When this person's working day runs, "07:00" to "22:00", so the
   * calendar draws its free stretches inside the same hours the queue is
   * laid out in.
   */
  workDay: { start: string; end: string };
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
  /** Its day's list, with what is ticked off now. */
  checklist?: ChecklistItem[];
}

/** What the creation sheet said when the user wrote down a task. */
export interface TaskRequest {
  title: string;
  minutes: number;
  /**
   * Whether it goes into the backlog, which is where a task goes unless the
   * request says otherwise.
   */
  backlog: boolean;
  /**
   * ISO 8601, the hour it is anchored at, when it goes straight onto the
   * day at one. Meaningless in the backlog, which has no hours.
   */
  notBefore?: string;
  /**
   * Where in the list of tasks it goes, counted as [TimingAction.index]
   * counts, when it goes straight into the queue at a place rather than at
   * its end.
   */
  index?: number;
  /** The artifact it belongs to, checked against the person's own. */
  artifactId?: string;
}

/** What the detail screen can change about a task. */
export interface TaskEdit {
  /**
   * ISO 8601, a new hour to anchor a task not yet begun at. The queue then
   * flows around it.
   */
  startTime?: string;
  title?: string;
  /** The work, pauses left out. */
  workMinutes?: number;
  notes?: string;
  /** Its day's list, with what is ticked off now. */
  checklist?: ChecklistItem[];
}
