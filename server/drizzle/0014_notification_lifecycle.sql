ALTER TABLE "routine" ALTER COLUMN "fixed" SET DEFAULT true;--> statement-breakpoint
ALTER TABLE "event" ADD COLUMN "confirmed_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "event" ADD COLUMN "closed_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "event" ADD COLUMN "overtime_from" timestamp with time zone;--> statement-breakpoint
-- Every routine is fixed now: the next read writes its days as events.
UPDATE "routine" SET "fixed" = true WHERE "fixed" = false;--> statement-breakpoint
-- The days of the flexible ones that nobody began were tasks; they go, and
-- the same days come back as events. A day begun or done is history.
DELETE FROM "task" AS t
WHERE t."routine_id" IS NOT NULL
  AND t."done_at" IS NULL
  AND NOT EXISTS (SELECT 1 FROM "event" AS e WHERE e."task_id" = t."id");--> statement-breakpoint
-- What already happened is settled: a block whose start or end is behind
-- us was answered by the old rules, so none of them wakes up in overtime.
UPDATE "event" SET "confirmed_at" = "start_time" WHERE "start_time" <= now();--> statement-breakpoint
UPDATE "event" SET "closed_at" = "end_time" WHERE "end_time" <= now();
