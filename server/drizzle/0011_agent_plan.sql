CREATE TABLE "agent_plan" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"group_id" uuid,
	"body" jsonb NOT NULL,
	"applied" jsonb,
	"created_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
ALTER TABLE "agent_plan" ADD CONSTRAINT "agent_plan_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "agent_plan_user_created_idx" ON "agent_plan" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE INDEX "agent_plan_group_idx" ON "agent_plan" USING btree ("group_id");