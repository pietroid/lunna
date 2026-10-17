-- A project's tasks are no longer parked off the day: each one waiting in
-- its project goes to the end of its person's backlog, in the order it had.
WITH "ends" AS (
	SELECT "user_id", MAX("position") AS "last"
	FROM "task"
	WHERE "backlog" AND NOT "parked"
	GROUP BY "user_id"
), "moved" AS (
	SELECT "id", "user_id",
		ROW_NUMBER() OVER (PARTITION BY "user_id" ORDER BY "position", "created_at") AS "n"
	FROM "task"
	WHERE "parked"
)
UPDATE "task"
SET "backlog" = true,
	"not_before" = NULL,
	"position" = COALESCE("ends"."last", -1) + "moved"."n"
FROM "moved"
LEFT JOIN "ends" ON "ends"."user_id" = "moved"."user_id"
WHERE "task"."id" = "moved"."id";--> statement-breakpoint
ALTER TABLE "task" DROP COLUMN "parked";
