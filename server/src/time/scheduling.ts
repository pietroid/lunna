import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  floorToMinute,
  Interval,
  nextFreeSlot,
} from './work-hours';
import { Zone } from './zone';

/** One thing on the day, as the layout sees it. */
export interface PlannedBlock {
  /** A thread slug, or an event id. */
  id: string;
  minutes: number;
  /** Whether its hour is the point of it, and so cannot be moved. */
  fixed: boolean;
  interval: Interval;
  /**
   * The earliest it may start, when the user asked for later.
   *
   * The cursor jumps to it rather than the block being fitted in earlier, so
   * the gap the user left before it stays a gap.
   */
  notBefore?: Date;
}

/**
 * Where a flexible queue lands, laid out around whatever cannot move.
 *
 * One pass down the queue. Each flexible block takes the first slot that fits
 * after the cursor, the cursor moves past it, and the next one starts looking
 * from there. Fixed blocks and calendar events are never assigned anywhere:
 * they are only obstacles, so the flexible ones flow into the gaps between
 * them, including the gaps that come *before* a fixed block later in the day.
 *
 * That is the whole scheduler. Adding something, dragging something, and
 * closing the hole left by something that was solved are all this function
 * with a different queue, which is why there is no second copy of the rules
 * anywhere and no guard that has to agree with them.
 */
export function relayout(
  queue: PlannedBlock[],
  anchors: Interval[],
  from: Date,
  zone: Zone,
): Map<string, Interval> {
  const placed = new Map<string, Interval>();
  let cursor = from;

  for (const block of queue) {
    if (block.fixed) continue;

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

/** Whether [interval] is somewhere other than where it already was. */
export function moved(block: PlannedBlock, interval: Interval): boolean {
  return (
    block.interval.start.getTime() !== interval.start.getTime() ||
    block.interval.end.getTime() !== interval.end.getTime()
  );
}
