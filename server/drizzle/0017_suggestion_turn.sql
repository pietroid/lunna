ALTER TABLE "agent_suggestion" ADD COLUMN "kind" text DEFAULT 'template' NOT NULL;--> statement-breakpoint
ALTER TABLE "agent_suggestion" ADD COLUMN "work_quality" integer;--> statement-breakpoint
ALTER TABLE "agent_suggestion" ADD COLUMN "follow_up" integer;--> statement-breakpoint
ALTER TABLE "agent_suggestion" ADD COLUMN "next_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "agent_suggestion" ADD COLUMN "dismissed_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "agent_suggestion" ADD COLUMN "answered_at" timestamp with time zone;--> statement-breakpoint
UPDATE "agent_suggestion" SET "next_at" = "valid_until";