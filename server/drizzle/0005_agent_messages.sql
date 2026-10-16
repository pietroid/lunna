CREATE TABLE "agent_message" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"conversation_id" uuid NOT NULL,
	"role" text NOT NULL,
	"text" text NOT NULL,
	"steps" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"plan" jsonb,
	"plan_id" uuid,
	"plan_status" text,
	"voice_seconds" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "agent_message" ADD CONSTRAINT "agent_message_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "agent_message_user_created_idx" ON "agent_message" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "agent_message_conversation_idx" ON "agent_message" USING btree ("conversation_id");