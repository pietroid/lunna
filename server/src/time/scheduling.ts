import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  floorToMinute,
  Interval,
  nextFreeSlot,
  WorkDay,
} from './work-hours';
import { DayMark, Marks, NO_MARKS } from './day-kinds';
import { addDaysIn, isoDayIn, startOfDayIn, Zone } from './zone';

/** One task, as the layout sees it. */
export interface QueuedBlock {
  /** The task id. */
  id: string;
  minutes: number;
  /**
   * The hour it is anchored at, when it has one.
   *
   * An anchored block is not in the queue's turn-taking at all. It keeps its
   * hour, and the queue flows around it the way it flows around an event.
   * It is still flexible: something already there when its hour comes, a
   * running block that overran or an anchored block before it that was
   * pushed, pushes it later, and an hour the clock has passed is now.
   */
  anchor?: Date;
  /**
   * Whether it is a delivery's task: client work, which the queue never
   * puts on a light day.
   */
  artifact?: boolean;
}

/**
 * Where the tasks land, laid out around whatever is already there.
 *
 * Two passes. The anchored tasks go first, in the order of their hours: each
 * takes its hour, or the first slot that fits after it when something is in
 * the way, and is then in the way of everything after it. That is what
 * makes a flexible block flexible and a fixed one not: an event pushes a
 * lunch at noon later, and nothing pushes an event.
 *
 * Then the queue, one pass down it. Each block takes the first slot that
 * fits after the cursor, the cursor moves past it, and the next one starts
 * looking from there. The anchors are obstacles, so the queue fills the gaps
 * before a lunch at noon and hops over it rather than pushing it: a task
 * nobody has begun has not run into anything yet.
 *
 * That is the whole scheduler, and nothing it works out is written down. A
 * task's hour is this function's answer on the read that asked, so adding,
 * dragging and finishing something only change the queue, and the next read
 * lays it out again. The queue has no end, and neither does the layout: a
 * task that does not fit today goes to tomorrow, and the one after it to the
 * day after that.
 *
 * [marks] say what kind each date is. The queue puts nothing on a day off,
 * and on a light day only loose tasks, up to its budget; a delivery's task
 * hops over it to the next working day, the way it hops over a fixed block.
 * An anchored task keeps its hour whatever the day: the person put it
 * there.
 */
export function relayout(
  blocks: QueuedBlock[],
  anchors: Interval[],
  from: Date,
  zone: Zone,
  day?: WorkDay,
  marks: Marks = NO_MARKS,
): Map<string, Interval> {
  const placed = new Map<string, Interval>();
  const busy = [...anchors];
  // Minutes of tasks already on each light day, against its budget.
  const used = new Map<string, number>();
  const take = (slot: Interval, minutes: number) => {
    const date = isoDayIn(slot.start, zone);
    used.set(date, (used.get(date) ?? 0) + minutes);
  };

  const anchored = blocks
    .filter((block) => block.anchor !== undefined)
    .sort((a, b) => a.anchor!.getTime() - b.anchor!.getTime());
  for (const block of anchored) {
    // An hour the clock has passed is now: the block waits for the user at
    // the current minute, like the first task in the queue.
    const floor = block.anchor! > from ? block.anchor! : from;
    const slot = nextFreeSlot(floor, block.minutes, busy, zone, day);
    placed.set(block.id, slot);
    busy.push(slot);
    take(slot, block.minutes);
  }

  let cursor = from;
  for (const block of blocks) {
    if (block.anchor !== undefined) continue;

    const { slot, hopped } = queueSlot(
      cursor,
      block,
      busy,
      zone,
      day,
      marks,
      used,
    );
    placed.set(block.id, slot);
    take(slot, block.minutes);
    if (hopped) {
      // It hopped a day that would not take it, and stands in the way there
      // like an anchor. The cursor stays: the loose tasks after it still
      // fill the light day it hopped.
      busy.push(slot);
      continue;
    }
    // Five minutes apart, and not snapped to a grid of five. The day slides
    // a minute at a time while something is paused, and a grid would turn
    // that slide into jumps.
    cursor = floorToMinute(addMinutes(slot.end, BLOCK_GAP_MINUTES));
  }

  return placed;
}

/**
 * The first slot [block] may take in its turn: [nextFreeSlot]'s, on a day
 * that takes it. A day that does not is skipped whole, from its midnight.
 */
function queueSlot(
  from: Date,
  block: QueuedBlock,
  busy: Interval[],
  zone: Zone,
  day: WorkDay | undefined,
  marks: Marks,
  used: Map<string, number>,
): { slot: Interval; hopped: boolean } {
  let slot = nextFreeSlot(from, block.minutes, busy, zone, day);
  // A year of days, the most a rhythm could ever skip in a row.
  for (let attempt = 0; attempt < 366; attempt++) {
    const date = isoDayIn(slot.start, zone);
    if (takes(marks(date), block, used.get(date) ?? 0)) {
      return { slot, hopped: attempt > 0 };
    }
    const next = startOfDayIn(addDaysIn(slot.start, 1, zone), zone);
    slot = nextFreeSlot(next, block.minutes, busy, zone, day);
  }
  return { slot, hopped: true };
}

/** Whether a day marked [mark], with [used] minutes on it, takes [block]. */
function takes(mark: DayMark, block: QueuedBlock, used: number): boolean {
  if (mark.kind === 'work') return true;
  if (mark.kind === 'off' || block.artifact === true) return false;
  return used + block.minutes <= (mark.budgetMinutes ?? 0);
}
