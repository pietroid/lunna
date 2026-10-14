import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  floorToMinute,
  Interval,
  nextFreeSlot,
  WorkDay,
} from './work-hours';
import { Zone } from './zone';

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
 */
export function relayout(
  blocks: QueuedBlock[],
  anchors: Interval[],
  from: Date,
  zone: Zone,
  day?: WorkDay,
): Map<string, Interval> {
  const placed = new Map<string, Interval>();
  const busy = [...anchors];

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
  }

  let cursor = from;
  for (const block of blocks) {
    if (block.anchor !== undefined) continue;

    const slot = nextFreeSlot(cursor, block.minutes, busy, zone, day);
    placed.set(block.id, slot);
    // Five minutes apart, and not snapped to a grid of five. The day slides
    // a minute at a time while something is paused, and a grid would turn
    // that slide into jumps.
    cursor = floorToMinute(addMinutes(slot.end, BLOCK_GAP_MINUTES));
  }

  return placed;
}
