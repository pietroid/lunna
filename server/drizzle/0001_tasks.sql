CREATE TABLE "task" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"title" text NOT NULL,
	"notes" text DEFAULT '' NOT NULL,
	"minutes" integer NOT NULL,
	"position" double precision NOT NULL,
	"not_before" timestamp with time zone,
	"done_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "event" ADD COLUMN "task_id" uuid;--> statement-breakpoint
ALTER TABLE "task" ADD CONSTRAINT "task_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "task_user_position_idx" ON "task" USING btree ("user_id","position");--> statement-breakpoint
ALTER TABLE "event" ADD CONSTRAINT "event_task_id_task_id_fk" FOREIGN KEY ("task_id") REFERENCES "public"."task"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
-- A flexible block was an event with an hour of its own. It is a task now,
-- with no hour until it is begun, and the old ones are dropped rather than
-- carried over: fixed blocks and the days of routines are all that stay.
DELETE FROM "event" WHERE "fixed" = false AND "routine_id" IS NULL;
