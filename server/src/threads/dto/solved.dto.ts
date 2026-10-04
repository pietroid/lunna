/**
 * Whether a thread is solved.
 *
 * Sent when a card is dragged aside on the home screen, and again with
 * `false` when it is pulled back out of the concluded list.
 */
export class SolvedDto {
  solved?: boolean;
}
