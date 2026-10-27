ALTER TABLE "artifact" ADD COLUMN "started_at" timestamp with time zone;--> statement-breakpoint
-- An open delivery some of whose work was begun or done was begun when its
-- first task was: the earliest hour any of its tasks began, or else the
-- earliest one was ticked off.
UPDATE "artifact" AS a SET "started_at" = w."first"
FROM (
  SELECT t."artifact_id", LEAST(MIN(e."start_time"), MIN(t."done_at")) AS "first"
  FROM "task" AS t
  LEFT JOIN "event" AS e ON e."task_id" = t."id"
  WHERE t."artifact_id" IS NOT NULL
    AND (e."id" IS NOT NULL OR t."done_at" IS NOT NULL)
  GROUP BY t."artifact_id"
) AS w
WHERE a."id" = w."artifact_id" AND a."done_at" IS NULL;
