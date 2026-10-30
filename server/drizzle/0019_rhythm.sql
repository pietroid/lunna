CREATE TABLE "cycle_start" (
	"user_id" text NOT NULL,
	"day" date NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "day_off" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"day" date NOT NULL,
	"title" text DEFAULT '' NOT NULL,
	"kind" text DEFAULT 'off' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "rhythm" (
	"user_id" text PRIMARY KEY NOT NULL,
	"saturday_kind" text DEFAULT 'off' NOT NULL,
	"sunday_kind" text DEFAULT 'off' NOT NULL,
	"light_minutes" integer DEFAULT 180 NOT NULL,
	"cycle_length" integer DEFAULT 28 NOT NULL,
	"period_length" integer DEFAULT 5 NOT NULL,
	"period_kind" text DEFAULT 'light' NOT NULL,
	"next_start" date,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "cycle_start" ADD CONSTRAINT "cycle_start_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "day_off" ADD CONSTRAINT "day_off_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "rhythm" ADD CONSTRAINT "rhythm_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "cycle_start_user_day_idx" ON "cycle_start" USING btree ("user_id","day");--> statement-breakpoint
CREATE UNIQUE INDEX "day_off_user_day_idx" ON "day_off" USING btree ("user_id","day");