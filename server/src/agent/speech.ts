/** Anything shaped like a board ref: `t3`, `e1`, `b12`, `d1`, `p2`, `k1`, `g1`. */
const REF = /\b([tebdpkg]\d{1,3})\b/gi;

/** The scheduler's word for Para depois. */
const BACKLOG = /\b(o |no |do |ao )?backlog\b/gi;

/** What can name a ref: the board, or anything that knows its titles. */
export interface Titles {
  title(ref: string): string | undefined;
}

/**
 * [text] as the person may read it: every ref the board knows replaced by
 * its card's title, and the scheduler's "backlog" by the app's own name for
 * it. [leaks] is how many words had to be replaced, which the turn logs.
 *
 * Deterministic, and run on everything the model writes for the person
 * (the caption, a heading, a choice's label, a plain-text answer): the
 * prompt asks the model not to leak, and this is what guarantees it.
 */
export function speakable(
  text: string,
  board: Titles,
): { text: string; leaks: number } {
  let leaks = 0;
  const said = text
    .replace(REF, (ref: string) => {
      const title = board.title(ref);
      if (title === undefined) return ref;
      leaks++;
      return title;
    })
    .replace(BACKLOG, (_word: string, article: string | undefined) => {
      leaks++;
      const of = article?.trim().toLowerCase();
      return of === undefined ? 'Para depois' : `${of} Para depois`;
    })
    .replace(/\s+/g, ' ')
    .trim();

  return { text: said, leaks };
}

/** Whether [text] still has a ref the person should never see. */
export function leaksRef(text: string): boolean {
  return new RegExp(REF.source, 'i').test(text);
}
