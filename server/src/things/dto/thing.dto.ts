/** A thing written down or changed. Anything left out stays. */
export class ThingDto {
  title?: string;
  durationMinutes?: number;
}

/** Where a drop left a thing, counted from the top of the list. */
export class MoveThingDto {
  index?: number;
}
