CREATE TABLE "agent_suggestion" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"focus" text NOT NULL,
	"text" text NOT NULL,
	"action_label" text,
	"plan_id" uuid,
	"opening" jsonb NOT NULL,
	"basis" text NOT NULL,
	"valid_until" timestamp with time zone NOT NULL,
	"taken_at" timestamp with time zone,
	"created_at" timestamp with time zone NOT NULL,
	CONSTRAINT "agent_suggestion_user_id_unique" UNIQUE("user_id")
);
--> statement-breakpoint
ALTER TABLE "agent_suggestion" ADD CONSTRAINT "agent_suggestion_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;