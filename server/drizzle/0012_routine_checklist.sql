ALTER TABLE "event" ADD COLUMN "checklist" jsonb;--> statement-breakpoint
ALTER TABLE "routine" ADD COLUMN "checklist" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "task" ADD COLUMN "checklist" jsonb;