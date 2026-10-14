ALTER TABLE "routine" ADD COLUMN "fixed" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "task" ADD COLUMN "routine_id" uuid;--> statement-breakpoint
ALTER TABLE "task" ADD COLUMN "occurrence" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "task" ADD COLUMN "cancelled" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "task" ADD CONSTRAINT "task_routine_id_routine_id_fk" FOREIGN KEY ("routine_id") REFERENCES "public"."routine"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "task_routine_occurrence_idx" ON "task" USING btree ("routine_id","occurrence");--> statement-breakpoint
-- Every routine is flexible now, so the days of one still ahead move from the
-- calendar to the tasks, anchored at the hour they had. A day that was taken
-- off stays taken off.
INSERT INTO "task" ("user_id", "title", "notes", "minutes", "position", "not_before", "routine_id", "occurrence", "cancelled")
SELECT "user_id", "title", "notes",
       GREATEST(5, ROUND(EXTRACT(EPOCH FROM ("end_time" - "start_time")) / 60))::integer,
       0, "start_time", "routine_id", "occurrence", "cancelled"
FROM "event"
WHERE "routine_id" IS NOT NULL AND "task_id" IS NULL AND "started" = false AND "start_time" > now()
ON CONFLICT DO NOTHING;--> statement-breakpoint
DELETE FROM "event"
WHERE "routine_id" IS NOT NULL AND "task_id" IS NULL AND "started" = false AND "start_time" > now();
