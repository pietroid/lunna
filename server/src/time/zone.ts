/**
 * Wall-clock arithmetic in a named timezone.
 *
 * Every hour in Focus is a wall-clock hour: the working day starts at seven
 * in the morning where the person is, "hoje" is their day and not the
 * server's, and "19:40" on a card is what their watch says. A `Date` is an
 * instant and knows none of that, and its `getHours` and `setHours` answer in
 * whatever zone the process happens to be running in. That is the whole of
 * how a block booked at eight in the evening ended up on tomorrow morning:
 * the container ran in UTC, so twenty past eight in São Paulo was twenty past
 * eleven to the arithmetic, and eleven is past the end of the day.
 *
 * So the zone is a parameter, never the ambient one. It comes from the
 * calendar, which is the only thing in the system with an opinion about what
 * day it is that the user can actually see, and it is threaded down to every
 * function that turns an instant into an hour or a date.
 *
 * Nothing here needs a dependency. `Intl` already holds the whole tz
 * database, including the historical offsets and every daylight-saving rule,
 * which is why offsets are read off a formatter rather than computed.
 */

/** An IANA timezone name, as Google gives it: "America/Sao_Paulo". */
export type Zone = string;

/**
 * The zone to use when the calendar's own is not known.
 *
 * The machine's zone rather than UTC. A deployment that never set TZ still
 * runs on a clock that knows the hour, and defaulting to UTC there is the bug
 * this file exists to remove rather than a safe neutral choice.
 */
export function systemZone(): Zone {
  const configured = process.env.TZ;
  if (configured !== undefined && configured !== '') return configured;

  return Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC';
}

/** A wall-clock reading: the numbers a clock and a calendar in [Zone] show. */
export interface Wall {
  year: number;
  /** 1-12, as written rather than as `Date` numbers months. */
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}

/**
 * One formatter per zone.
 *
 * Building an `Intl.DateTimeFormat` is the expensive part of every function
 * here, and a timeline rebuild asks the same zone a few hundred questions.
 */
const _formatters = new Map<Zone, Intl.DateTimeFormat>();

function formatterFor(zone: Zone): Intl.DateTimeFormat {
  const known = _formatters.get(zone);
  if (known !== undefined) return known;

  // 'en-CA' and h23 so the parts come back as plain two-digit numbers with no
  // era, no am/pm and no "24" for midnight.
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: zone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });

  _formatters.set(zone, formatter);
  return formatter;
}

/** What a clock in [zone] reads at the instant [at]. */
export function wallOf(at: Date, zone: Zone): Wall {
  const parts = new Map<string, string>();
  for (const part of formatterFor(zone).formatToParts(at)) {
    parts.set(part.type, part.value);
  }

  const read = (type: string): number => Number(parts.get(type) ?? '0');

  return {
    year: read('year'),
    month: read('month'),
    day: read('day'),
    hour: read('hour'),
    minute: read('minute'),
    second: read('second'),
  };
}

/** How far [zone] is from UTC at the instant [at], in milliseconds. */
function offsetAt(at: Date, zone: Zone): number {
  const wall = wallOf(at, zone);
  const asUtc = Date.UTC(
    wall.year,
    wall.month - 1,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  );

  // Seconds are the finest part the formatter gives, so the instant is
  // compared at second resolution and the milliseconds are dropped.
  return asUtc - Math.floor(at.getTime() / 1000) * 1000;
}

/**
 * The instant at which a clock in [zone] reads [wall].
 *
 * Two passes. The first guesses the offset by pricing the wall reading as if
 * it were UTC, the second prices it again at the instant that guess lands on,
 * which is what gets the hour right across a daylight-saving boundary where
 * the two offsets differ. On a wall time that a clock in that zone skips
 * entirely, this lands on the instant the day jumps to, which is the only
 * honest answer available.
 */
export function instantOf(wall: Wall, zone: Zone): Date {
  const asUtc = Date.UTC(
    wall.year,
    wall.month - 1,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  );

  const guess = asUtc - offsetAt(new Date(asUtc), zone);
  return new Date(asUtc - offsetAt(new Date(guess), zone));
}

/** The same day as [at] in [zone], at [hour] o'clock exactly. */
export function atHourIn(at: Date, hour: number, zone: Zone): Date {
  const wall = wallOf(at, zone);
  return instantOf({ ...wall, hour, minute: 0, second: 0 }, zone);
}

/**
 * [at] moved by [days] in [zone], keeping the hour it reads.
 *
 * Days rather than 24-hour spans: on the two days a year a zone's offset
 * changes, "tomorrow at seven" is 23 or 25 hours away, and adding a day's
 * worth of milliseconds would land on six or eight.
 */
export function addDaysIn(at: Date, days: number, zone: Zone): Date {
  const wall = wallOf(at, zone);
  return instantOf({ ...wall, day: wall.day + days }, zone);
}

/** Whether [a] and [b] fall on the same calendar day in [zone]. */
export function sameDayIn(a: Date, b: Date, zone: Zone): boolean {
  const left = wallOf(a, zone);
  const right = wallOf(b, zone);

  return (
    left.year === right.year &&
    left.month === right.month &&
    left.day === right.day
  );
}

/** "14:30", as a clock in [zone] reads [at]. */
export function formatTimeIn(at: Date, zone: Zone): string {
  const wall = wallOf(at, zone);
  const pad = (value: number): string => String(value).padStart(2, '0');

  return `${pad(wall.hour)}:${pad(wall.minute)}`;
}

/** "21-09-2026", the day [at] falls on in [zone]. */
export function formatDayIn(at: Date, zone: Zone): string {
  const wall = wallOf(at, zone);
  const pad = (value: number): string => String(value).padStart(2, '0');

  return `${pad(wall.day)}-${pad(wall.month)}-${wall.year}`;
}

/**
 * [at] as ISO 8601 with the offset [zone] has at that instant:
 * "2026-09-21T14:00:00-03:00".
 *
 * For anything handed to a device that fires on its own clock. An instant in
 * UTC is correct and still leaves the reader to work out which wall clock was
 * meant, which is the arithmetic this file exists to keep in one place.
 */
export function isoIn(at: Date, zone: Zone): string {
  const wall = wallOf(at, zone);
  const pad = (value: number): string => String(value).padStart(2, '0');
  const offsetMinutes = Math.round(offsetAt(at, zone) / 60_000);
  const sign = offsetMinutes < 0 ? '-' : '+';
  const abs = Math.abs(offsetMinutes);

  return (
    `${wall.year}-${pad(wall.month)}-${pad(wall.day)}` +
    `T${pad(wall.hour)}:${pad(wall.minute)}:${pad(wall.second)}` +
    `${sign}${pad(Math.floor(abs / 60))}:${pad(abs % 60)}`
  );
}
