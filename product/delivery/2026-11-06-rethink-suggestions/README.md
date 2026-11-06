# Rethink agentic suggestions

## 1. The ask

> The initial proposal of agentic suggestions was to complete the schedule
> of a person based on tiers. But the agent must be abe to intelligentely
> know that if the user refuses the same question (for example, setting the
> goal), maybe the user should not suggest things like this.
>
> So the agent can also suggest tactically, ie, things that can be solved
> soon, things that are stuck a long time on pending, or things that are a
> long time in the queue.
>
> Also, a UI neat: add the suggestion inside the Now section, before the now
> card. when we dismiss, it returns to normal.

The brief (the `/create` plan, ~1.5 % of the week):

- The server gives the model past refusals: the last ~10 suggestions of the
  person, each with its topic (`focus`) and whether it was dismissed, taken
  or answered. Even 1 dismissal counts. No hard rule, no pause timer: the
  model weighs it as a tradeoff.
- The server adds tactical candidates to the suggestion request, each
  naming one task: (a) quick to solve (short, or an overdue anchor), (b) in
  Pendentes for 3 days or more, (c) in the queue or Para depois for 7 days
  or more. The thresholds are constants.
- The request tells the model to pick the one most important topic: the
  tier topic, or a tactical candidate if it matters more, or a different
  topic when the person keeps refusing one. Each tactical suggestion
  proposes one gesture the person could make by hand, through the existing
  plan and answer tool.
- The app moves `SuggestionCard` below the Agora heading, the first child
  before the now card. Dismissed or taken, it disappears and Agora shows its
  normal card, with no animation.
- One server spec covers history and tactical candidates in the request.

Not doing: no new table, no hard rule for repeat refusals, no new tactical
verbs, no changes to the welcome's words or the notification copy, no
animation, no `eval:agent` run.

## 2. The plan

- **History.** `agent_suggestion` keeps one row per person (`user_id` is
  unique), so the past cannot be read from other rows. The row gains one
  nullable `history` jsonb column: on `put`, the row being replaced is
  folded into the new row's history (topic, kind, outcome, when), newest
  first, at most 10. `SuggestionStore.recent(userId, limit)` reads the
  current row and its history. One additive migration, no new table.
- **Tactical candidates.** `tacticalOf` in `work-quality.ts` reads the
  day's tasks: `stuck` (in Pendentes 3 days or more, `pending_at`),
  `waiting` (in the queue or Para depois 7 days or more, `created_at`, now
  carried on `Task`), `quick` (15 min or less, or an anchor whose hour has
  passed). Begun tasks, routine days and done ones are left out.
- **The request.** `requestOf(quality, { history, tactical, now })` adds
  both lists and the prioritising instruction; the answer tool gains an
  optional `topic` the model sets when it chose another one, stored as the
  suggestion's `focus`.
- **The basis** hashes the tactical candidates too, so a changed day makes
  a new suggestion.
- **The welcome.** Shown first as before; once dismissed and its day is
  over, the next suggestion is a turn that knows it was refused, instead of
  the welcome again (the ask's own example: refusing to set the goal).
- **The app.** `SuggestionCard` moves under the Agora heading.
- **Proof.** Specs in `work-quality.spec.ts`, `pg-suggestion.store.spec.ts`
  and the suggestion block of `agent.controller.spec.ts`; `.tool/check`.

### Decided unattended

- **A `history` column, against the plan's "no schema change".** The table
  has one row per person (`user_id` unique), so the last 10 suggestions
  exist nowhere else. One nullable jsonb column was the smallest honest
  change; dropping the unique constraint would have changed what
  `current`, `pending` and the notifications read.
- **A dismissed welcome is not shown again.** After its day, the next
  suggestion is a turn told that the welcome was dismissed; the model may
  still ask for a goal, or pick something else. The welcome's words stay.
- **The model names its topic** with an optional `topic` on the answer
  tool, so `focus` records a tactical choice (`quick`, `stuck`, `waiting`)
  and the next request's history is right.
- **Thresholds:** 3 days in Pendentes, 7 days waiting, 15 minutes for
  quick; at most 3 candidates per kind.
- **The basis hashes only the chosen topic's candidates.** Hashing every
  candidate would hide a goal's card whenever a short task was added
  (a changed basis hides the card until `nextAt`). A tier suggestion keeps
  its old hash; a tactical one changes when its candidates do.
- **The memory task store leaves `createdAt` out**: it has no clock, and
  the machine's would make the end-to-end tests depend on today's date.
  `waiting` is proved by the unit spec; Postgres fills it from `created_at`.
- **A widget test instead of prints**: the card's look is unchanged and
  only its place moved, so the proof is a Plano test (the offer between
  the Agora heading and the now card, gone after its ✕).

## 3. What was built

No image: the card's look is unchanged and only its place moved, so the
proof is tests (see "Decided unattended"). `.tool/check`: app-analyze,
server-eslint, server-tsc and server-test all pass.

**The rule that matters.** The model sees its last suggestions and the
tasks that are stuck, waiting or quick, and picks the one topic that
matters most. Code still decides nothing about the pick; it only supplies
the facts.

**Server.**

- `agent_suggestion.history`, a nullable jsonb column (migration
  `server/drizzle/0021_old_star_brand.sql`). `put` folds the replaced
  suggestion into the new one's history (focus, kind, outcome `taken`,
  `dismissed`, `answered` or `unanswered`, createdAt), newest first, at most
  10 (`HISTORY_LIMIT`). `SuggestionStore.recent(userId, limit)` is the
  current one plus its history; `pastOf` in `suggestion.store.ts`; the Pg and
  Memory stores both.
- `tacticalOf(tasks, backlog, begun, now)` in `work-quality.ts`: `stuck`
  (in Pendentes 3 days or more, `STUCK_PENDING_DAYS`), `waiting` (queue or
  Para depois, not pending, written 7 days ago or more, `WAITING_DAYS`) and
  `quick` (in the queue, 15 minutes or less, `QUICK_MINUTES`, or an anchor
  whose hour passed). It skips begun, done, cancelled and routine days; at
  most 3 per kind. The Pg task store now carries `Task.createdAt`.
- `requestOf(quality, { history, tactical, now })` adds the last
  suggestions with their ages, the candidates with a legend, and the
  prioritising instruction.
- The answer tool gains an optional `topic`; the stored `focus` is
  `topic ?? quality.topic`.
- `basisOf(quality, tactical)` hashes the tactical candidates of the
  suggestion's own focus only, so tier suggestions keep their old hashes.
- No new routes: `GET /agent/suggestion` answers as before.
- The welcome: once dismissed and past its `nextAt`, the next suggestion is
  a turn told it was dismissed.

**App.** `SuggestionCard` moves in `app/lib/plan/view/home_page.dart` from
above the Agora heading to just under it, before the now card. The card is
unchanged; taken or dismissed it disappears.

**Tests.**

- `work-quality.spec.ts`: 9 specs, incl. tactical candidates and the request.
- `pg-suggestion.store.spec.ts`: 4 specs, incl. history and `recent`.
- `agent.controller.spec.ts`: "puts the welcome away" now expects a turn
  after the welcome's day, with "dismissed" and "goal" in the request.
- `app/test/plan/home_page_test.dart`: new "draws the offer inside Agora,
  before its card, and ✕ leaves Agora" (30 pass).

**Differs from the plan**, all under "Decided unattended": a schema column
was added (the plan said none) because `user_id` is unique; a dismissed
welcome no longer repeats; the basis hashes only the chosen topic's
candidates; a widget test replaces prints.

**Next steps.** Run `npm run eval:agent` once to see how the model weighs
refusals and tactical candidates. Maybe show the tactical topic in
PostHog's suggestion event.

## 4. How to turn it on

Nothing to set. The migration runs on server boot. Existing rows have no
history and start one with their next suggestion.

## 5. Cost and time

Measured by the queue: see the pull request.
