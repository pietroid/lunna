/** Where a drop left a card, counted from the top of the one list. */
export class MoveEventDto {
  index?: number;
  /** ISO 8601, the start of the gap it was dropped into, when it was. */
  after?: string;
  /** The length it was cut to so it fits that gap. */
  minutes?: number;
}
