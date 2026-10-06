import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  floorToMinute,
  Interval,
  nextFreeSlot,
} from './work-hours';
import { Zone } from './zone';

/** One task in the queue, as the layout sees it. */
export interface QueuedBlock {
  /** The task id. */
  id: string;
  minutes: number;
  /**
   * The earliest it may start, when the user asked for later.
   *
   * The cursor jumps to it rather than the block being fitted in earlier, so
   * the gap the user left before it stays a gap.
   */
  notBefore?: Date;
}

/**
 * Where a queue of tasks lands, laid out around whatever cannot move.
 *
 * One pass down the queue. Each block takes the first slot that fits after
 * the cursor, the cursor moves past it, and the next one starts looking from
 * there. The anchors are never assigned anywhere: they are the events on the
 * calendar, and the tasks flow into the gaps between them, including the
 * gaps that come *before* a fixed block later in the day.
 *
 * That is the whole scheduler, and nothing it works out is written down. A
 * task's hour is this function's answer on the read that asked, so adding,
 * dragging and finishing something only change the queue, and the next read
 * lays it out again. The queue has no end, and neither does the layout: a
 * task that does not fit today goes to tomorrow, and the one after it to the
 * day after that.
 */
export function relayout(
  queue: QueuedBlock[],
  anchors: Interval[],
  from: Date,
  zone: Zone,
): Map<string, Interval> {
  const placed = new Map<string, Interval>();
  let cursor = from;

  for (const block of queue) {
    const floor =
      block.notBefore !== undefined && block.notBefore > cursor
        ? block.notBefore
        : cursor;
    const slot = nextFreeSlot(floor, block.minutes, anchors, zone);
    placed.set(block.id, slot);
    // Five minutes apart, and not snapped to a grid of five. The day slides
    // a minute at a time while something is paused, and a grid would turn
    // that slide into jumps.
    cursor = floorToMinute(addMinutes(slot.end, BLOCK_GAP_MINUTES));
  }

  return placed;
}
