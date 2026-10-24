import {
  boolean,
  date,
  doublePrecision,
  index,
  integer,
  jsonb,
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
  /**
   * When their working day starts and ends, in minutes after midnight in
   * [timeZone]. Nothing is laid out outside it. [dayEnd] may be 1440.
   */
  dayStart: integer('day_start').notNull().default(420),
  dayEnd: integer('day_end').notNull().default(1320),
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
/**
 * A shelf of the person's catalogue: Atendimentos, Conteúdo, Produtos.
 *
 * Everyone starts with an empty catalogue; it fills with their own.
 */
export const catalogCategory = pgTable(
  'catalog_category',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    /** Its place among the shelves, smallest first. */
    position: doublePrecision('position').notNull(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('catalog_category_user_idx').on(table.userId)],
);

/**
 * One kind of thing the person delivers (a natal chart, a Reels), on a
 * shelf: what one usually takes and is worth, so writing a delivery down is
 * picking its kind.
 */
export const catalogType = pgTable(
  'catalog_type',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    categoryId: uuid('category_id')
      .notNull()
      .references(() => catalogCategory.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    /** How long one takes, start to finish. */
    minutes: integer('minutes').notNull(),
    /** What one is worth, in whole reais. Null when it earns nothing. */
    price: integer('price'),
    /** The longest piece of it the day takes at once. Null: whole. */
    blockMinutes: integer('block_minutes'),
    /** Its place on its shelf, smallest first. */
    position: doublePrecision('position').notNull(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('catalog_type_user_idx').on(table.userId)],
);

/**
 * One delivery ("entrega"): something the person owes someone, or the
 * market, by a day. A name, notes, the tasks that point at it
 * (`task.artifact_id`), and, from its type or given by hand, a total time,
 * a value and how the day may cut it.
 *
 * The open ones are a queue of their own, in `position` order. The deadline
 * is a day, due by its end in the person's zone. Its value counts towards a
 * money goal on the day it is delivered (`done_at`).
 */
export const artifact = pgTable(
  'artifact',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    title: text('title').notNull(),
    /** Free text the user keeps on it. */
    notes: text('notes').notNull().default(''),
    /** Its kind in the catalogue. Null for a one-off delivery. */
    typeId: uuid('type_id').references(() => catalogType.id, {
      onDelete: 'set null',
    }),
    /** How long it takes in all. Null when nobody said. */
    minutes: integer('minutes'),
    /** What it is worth, in whole reais. */
    value: integer('value'),
    /** The longest piece of it the day takes at once. Null: whole. */
    blockMinutes: integer('block_minutes'),
    /** The day it is due by, `YYYY-MM-DD`. */
    deadline: date('deadline', { mode: 'string' }),
    /** Its place in the queue of deliveries, smallest first. */
    position: doublePrecision('position').notNull(),
    /** When it was delivered. Null while it is open. */
    doneAt: timestamp('done_at', { withTimezone: true }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('artifact_user_idx').on(table.userId)],
);

/**
 * A number to reach in a stretch of time, repeated stretch after stretch:
 * R$ 8.000 a month, three Reels a week.
 *
 * `kind` is `money` (the value of what was delivered in the stretch) or
 * `count` (how many of `type_id` were). `period` is `week` (Monday to
 * Sunday) or `month`. `starts` is the first day of its first stretch: a
 * goal whose stretch has not come yet is a future one.
 */
export const goal = pgTable(
  'goal',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    kind: text('kind').$type<'money' | 'count'>().notNull(),
    /** The kind counted, for a count goal. */
    typeId: uuid('type_id').references(() => catalogType.id, {
      onDelete: 'cascade',
    }),
    /** Whole reais, or deliveries. */
    target: integer('target').notNull(),
    period: text('period').$type<'week' | 'month'>().notNull(),
    /** `YYYY-MM-DD`, the first day of its first stretch. */
    starts: date('starts', { mode: 'string' }).notNull(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [index('goal_user_idx').on(table.userId)],
);

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
    /**
     * The hour it is anchored at, when it has one.
     *
     * A task with an hour keeps it, and the queue flows around it like it
     * flows around an event. Unlike an event it slides: whatever is really
     * happening before it and runs into it pushes it later, and once the hour
     * comes it waits for the user to begin it. Null for a task that simply
     * takes its turn in the queue.
     */
    notBefore: timestamp('not_before', { withTimezone: true }),
    /**
     * Whether it waits in the backlog ("Para depois") rather than in
     * the queue. A task in the backlog has an order and a length but no
     * hour: the layout never sees it until it is dragged into the queue.
     */
    backlog: boolean('backlog').notNull().default(false),
    /** The delivery it belongs to, when it belongs to one. */
    artifactId: uuid('artifact_id').references(() => artifact.id, {
      onDelete: 'set null',
    }),
    /** When it was finished. Null while there is still something to do. */
    doneAt: timestamp('done_at', { withTimezone: true }),
    /** The flexible routine this is a day of, when it is one. */
    routineId: uuid('routine_id').references(() => routine.id, {
      onDelete: 'set null',
    }),
    /** Which day of the routine: the instant the rule put it at. */
    occurrence: timestamp('occurrence', { withTimezone: true }),
    /**
     * A day of a routine that was taken off the day, or that its day ended
     * without.
     *
     * Kept as a row rather than deleted, so the next read does not write the
     * same occurrence back.
     */
    cancelled: boolean('cancelled').notNull().default(false),
    /**
     * The day's own list, for a day of a routine that has one: each item
     * of the routine's, and whether it was ticked off that day. Null for
     * everything else.
     */
    checklist: jsonb('checklist').$type<{ title: string; done: boolean }[]>(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (table) => [
    index('task_user_position_idx').on(table.userId, table.position),
    uniqueIndex('task_routine_occurrence_idx').on(
      table.routineId,
      table.occurrence,
    ),
  ],
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
    /**
     * Whether its hour is the point of it.
     *
     * A fixed routine writes its days down as [event] rows, which nothing
     * moves. A flexible one, the default, writes them down as [task] rows
     * anchored at the routine's hour: they keep it unless something already
     * happening runs into them, and they wait for the user to begin them.
     */
    fixed: boolean('fixed').notNull().default(false),
    /**
     * What each day of it is made of (breakfast: the coffee, the dishes, the
     * plants), in order. Copied into each day as it is written down, where
     * it is ticked off item by item. Empty for a routine that is one thing.
     */
    checklist: jsonb('checklist').$type<string[]>().notNull().default([]),
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
    /** The day's own list, as on [task], for a day of a fixed routine. */
    checklist: jsonb('checklist').$type<{ title: string; done: boolean }[]>(),
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

// ---------------------------------------------------------------------------
// The agent
// ---------------------------------------------------------------------------

/**
 * One message of a conversation with the agent.
 *
 * Kept for the person to read back, and for the agent to look up when it is
 * asked about them; a turn's context is only the conversation it is in. A
 * conversation is the messages sharing a [conversationId], which the server
 * hands out on its first turn.
 */
export const agentMessage = pgTable(
  'agent_message',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    conversationId: uuid('conversation_id').notNull(),
    /** `user` or `assistant`. */
    role: text('role').notNull(),
    text: text('text').notNull(),
    /** What the agent did, one short line each. Empty for the user's. */
    steps: jsonb('steps').$type<string[]>().notNull().default([]),
    /** The plan the answer proposed, as the app draws it. */
    plan: jsonb('plan').$type<unknown>(),
    planId: uuid('plan_id'),
    /** `proposed`, `applied` or `undone`. */
    planStatus: text('plan_status'),
    /** How long the user spoke for, when the message was said. */
    voiceSeconds: integer('voice_seconds'),
    createdAt: createdAt(),
  },
  (table) => [
    index('agent_message_user_created_idx').on(table.userId, table.createdAt),
    index('agent_message_conversation_idx').on(table.conversationId),
  ],
);

/**
 * A plan the agent proposed, kept until it is answered and, once applied,
 * with what undoing it writes back.
 *
 * In Postgres rather than memory because a plan may delete a delivery, and
 * an undo lost to a deploy would be a delivery lost. Read back for two hours
 * (`PLAN_TTL_MS`), then pruned.
 */
export const agentPlan = pgTable(
  'agent_plan',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    /** The plan a quick reply was offered beside. */
    groupId: uuid('group_id'),
    /** Its gestures, its card and what it took without being told. */
    body: jsonb('body').$type<unknown>().notNull(),
    /** Once applied: the undo and the ids it touched. */
    applied: jsonb('applied').$type<unknown>(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    index('agent_plan_user_created_idx').on(table.userId, table.createdAt),
    index('agent_plan_group_idx').on(table.groupId),
  ],
);

/**
 * What a link says about itself: its page's title, its site and its
 * picture, read once and kept for everyone, since a link's preview is the
 * same for all who paste it.
 */
export const linkPreview = pgTable('link_preview', {
  /** The link, as the notes write it. */
  url: text('url').primaryKey(),
  title: text('title'),
  site: text('site'),
  /** The page's picture, at its own address. */
  image: text('image'),
  /** The page could not be read; tried again a day later. */
  failed: boolean('failed').notNull().default(false),
  fetchedAt: timestamp('fetched_at', { withTimezone: true }).notNull(),
});

export const schema = {
  user,
  session,
  account,
  verification,
  routine,
  catalogCategory,
  catalogType,
  artifact,
  goal,
  task,
  event,
  agentMessage,
  agentPlan,
  linkPreview,
};

export type EventRow = typeof event.$inferSelect;
export type NewEventRow = typeof event.$inferInsert;
export type RoutineRow = typeof routine.$inferSelect;
export type TaskRow = typeof task.$inferSelect;
export type CatalogCategoryRow = typeof catalogCategory.$inferSelect;
export type CatalogTypeRow = typeof catalogType.$inferSelect;
export type ArtifactRow = typeof artifact.$inferSelect;
export type GoalRow = typeof goal.$inferSelect;
export type AgentMessageRow = typeof agentMessage.$inferSelect;
export type AgentPlanRow = typeof agentPlan.$inferSelect;
export type LinkPreviewRow = typeof linkPreview.$inferSelect;
