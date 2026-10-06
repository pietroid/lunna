import {
  boolean,
  doublePrecision,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

/**
 * Everything Lunna keeps, in one Postgres database.
 *
 * Three parts. The first four tables are Better Auth's and follow its
 * schema exactly: who someone is, their sessions, the Google account behind
 * them, and the short-lived verification rows the OAuth dance needs. Then the
 * tasks: what there is to do, in the order it is to be done, with no hour of
 * their own. Then the calendar, which is Lunna's own and the only record of
 * when anything happens.
 */

const createdAt = () =>
  timestamp('created_at', { withTimezone: true }).notNull().defaultNow();
const updatedAt = () =>
  timestamp('updated_at', { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date());

// ---------------------------------------------------------------------------
// Better Auth
// ---------------------------------------------------------------------------

export const user = pgTable('user', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  emailVerified: boolean('email_verified').notNull().default(false),
  image: text('image'),
  /**
   * The IANA zone this person's day is measured in.
   *
   * Every hour Lunna reasons about is a wall-clock hour — the working day runs
   * seven to ten, "hoje" is a day, a card reads "19:40" — and all of that is
   * only right in one zone. It used to be the Google calendar's; now it is
   * the person's own.
   */
  timeZone: text('time_zone').notNull().default('America/Sao_Paulo'),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

export const session = pgTable(
  'session',
  {
    id: text('id').primaryKey(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    token: text('token').notNull().unique(),
    ipAddress: text('ip_address'),
    userAgent: text('user_agent'),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('session_user_id_idx').on(table.userId)],
);

export const account = pgTable(
  'account',
  {
    id: text('id').primaryKey(),
    accountId: text('account_id').notNull(),
    providerId: text('provider_id').notNull(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    accessToken: text('access_token'),
    refreshToken: text('refresh_token'),
    idToken: text('id_token'),
    accessTokenExpiresAt: timestamp('access_token_expires_at', {
      withTimezone: true,
    }),
    refreshTokenExpiresAt: timestamp('refresh_token_expires_at', {
      withTimezone: true,
    }),
    scope: text('scope'),
    password: text('password'),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('account_user_id_idx').on(table.userId)],
);

export const verification = pgTable(
  'verification',
  {
    id: text('id').primaryKey(),
    identifier: text('identifier').notNull(),
    value: text('value').notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('verification_identifier_idx').on(table.identifier)],
);

// ---------------------------------------------------------------------------
// Tasks
// ---------------------------------------------------------------------------

/**
 * Something to do, in its place in the queue.
 *
 * A task has no hour. Where it falls on the calendar is worked out on every
 * read, by laying the queue out around the events, so reordering is writing
 * one number and the calendar can never disagree with the list. It gets an
 * [event] row of its own only when it is begun, because only then is its
 * hour a fact.
 */
export const task = pgTable(
  'task',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    title: text('title').notNull(),
    /** Free text the user keeps on it. */
    notes: text('notes').notNull().default(''),
    /** How long the work takes, pauses left out. */
    minutes: integer('minutes').notNull(),
    /**
     * Its place in the queue, smallest first.
     *
     * Fractional, so a drag writes one row: the new place is halfway between
     * its new neighbours.
     */
    position: doublePrecision('position').notNull(),
    /** The earliest the layout may start it. */
    notBefore: timestamp('not_before', { withTimezone: true }),
    /** When it was finished. Null while there is still something to do. */
    doneAt: timestamp('done_at', { withTimezone: true }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('task_user_position_idx').on(table.userId, table.position)],
);

// ---------------------------------------------------------------------------
// Calendar
// ---------------------------------------------------------------------------

/**
 * A block that comes back on its days: every day, weekdays or the weekend.
 *
 * The first occurrence is stored as two instants, and its wall-clock hour in
 * the person's zone is every day's. Instances are written into [event] as the
 * timeline reaches them, so a day of a routine moves, pauses and finishes
 * like any other block.
 */
export const routine = pgTable(
  'routine',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    title: text('title').notNull(),
    startTime: timestamp('start_time', { withTimezone: true }).notNull(),
    endTime: timestamp('end_time', { withTimezone: true }).notNull(),
    /** 'daily' | 'weekdays' | 'weekend'. */
    days: text('days').notNull(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('routine_user_id_idx').on(table.userId)],
);

/**
 * One block of time on someone's day.
 *
 * The only record of when anything happens. Every column but the identity
 * ones is what the timeline's arithmetic reads and writes: the hour, whether
 * it may move, whether the user began it, and the pause bookkeeping.
 */
export const event = pgTable(
  'event',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    title: text('title').notNull(),
    startTime: timestamp('start_time', { withTimezone: true }).notNull(),
    endTime: timestamp('end_time', { withTimezone: true }).notNull(),
    /**
     * Whether Lunna booked it, and so may move it.
     *
     * Always true today. Kept for the day events arrive from an outside
     * calendar, which are drawn because the hour is not free but are never
     * moved, renamed or removed from here.
     */
    managed: boolean('managed').notNull().default(true),
    /** Whether the hour is the point of it, so a layout leaves it alone. */
    fixed: boolean('fixed').notNull().default(false),
    /** Whether the user said they began it. */
    started: boolean('started').notNull().default(false),
    /** When it was paused. Null while it runs. */
    pausedAt: timestamp('paused_at', { withTimezone: true }),
    /** Seconds of work still owed at the moment it was paused. */
    remainingSeconds: integer('remaining_seconds'),
    /** Seconds spent paused before the current pause. */
    pausedSeconds: integer('paused_seconds').notNull().default(0),
    /** The earliest a layout may start it. */
    notBefore: timestamp('not_before', { withTimezone: true }),
    /** Free text the user keeps on the block. */
    notes: text('notes').notNull().default(''),
    /** The task this is the hour of, when it is one that was begun. */
    taskId: uuid('task_id').references(() => task.id, {
      onDelete: 'set null',
    }),
    /** The routine this is a day of, when it is one. */
    routineId: uuid('routine_id').references(() => routine.id, {
      onDelete: 'set null',
    }),
    /** Which day of the routine: the instant the rule put it at. */
    occurrence: timestamp('occurrence', { withTimezone: true }),
    /**
     * A day of a routine that was taken off the day.
     *
     * Kept as a row rather than deleted, so the next read does not write the
     * same occurrence back.
     */
    cancelled: boolean('cancelled').notNull().default(false),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [
    index('event_user_start_idx').on(table.userId, table.startTime),
    uniqueIndex('event_routine_occurrence_idx').on(
      table.routineId,
      table.occurrence,
    ),
  ],
);

export const schema = {
  user,
  session,
  account,
  verification,
  routine,
  task,
  event,
};

export type EventRow = typeof event.$inferSelect;
export type NewEventRow = typeof event.$inferInsert;
export type RoutineRow = typeof routine.$inferSelect;
export type TaskRow = typeof task.$inferSelect;
