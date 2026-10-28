/**
 * Calendar days as the API writes them (`YYYY-MM-DD`), counted as days and
 * never as instants: which day it is in the person's zone is worked out
 * once ([isoDayIn]), and everything here is arithmetic on the date alone.
 */

function parts(day: string): [number, number, number] {
  const [year, month, date] = day.split('-').map(Number);
  return [year, month, date];
}

function format(at: Date): string {
  return at.toISOString().slice(0, 10);
}

/** [day] moved by [days], which may be negative. */
export function addDays(day: string, days: number): string {
  const [year, month, date] = parts(day);
  return format(new Date(Date.UTC(year, month - 1, date + days)));
}

/** How many days from [from] to [to]: 0 on the same day. */
export function daysBetween(from: string, to: string): number {
  const [y1, m1, d1] = parts(from);
  const [y2, m2, d2] = parts(to);
  return Math.round(
    (Date.UTC(y2, m2 - 1, d2) - Date.UTC(y1, m1 - 1, d1)) / 86_400_000,
  );
}

/** The last day of [day]'s month. */
export function endOfMonth(day: string): string {
  const [year, month] = parts(day);
  return format(new Date(Date.UTC(year, month, 0)));
}
