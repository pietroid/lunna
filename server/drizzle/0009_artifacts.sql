CREATE TABLE "artifact" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"title" text NOT NULL,
	"notes" text DEFAULT '' NOT NULL,
	"type_id" uuid,
	"minutes" integer,
	"value" integer,
	"block_minutes" integer,
	"deadline" date,
	"position" double precision NOT NULL,
	"done_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "catalog_category" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"name" text NOT NULL,
	"position" double precision NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "catalog_type" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"category_id" uuid NOT NULL,
	"name" text NOT NULL,
	"minutes" integer NOT NULL,
	"price" integer,
	"block_minutes" integer,
	"position" double precision NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "goal" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" text NOT NULL,
	"kind" text NOT NULL,
	"type_id" uuid,
	"target" integer NOT NULL,
	"period" text NOT NULL,
	"starts" date NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "task" ADD COLUMN "artifact_id" uuid;--> statement-breakpoint
ALTER TABLE "artifact" ADD CONSTRAINT "artifact_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "artifact" ADD CONSTRAINT "artifact_type_id_catalog_type_id_fk" FOREIGN KEY ("type_id") REFERENCES "public"."catalog_type"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "catalog_category" ADD CONSTRAINT "catalog_category_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "catalog_type" ADD CONSTRAINT "catalog_type_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "catalog_type" ADD CONSTRAINT "catalog_type_category_id_catalog_category_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."catalog_category"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "goal" ADD CONSTRAINT "goal_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "goal" ADD CONSTRAINT "goal_type_id_catalog_type_id_fk" FOREIGN KEY ("type_id") REFERENCES "public"."catalog_type"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "artifact_user_idx" ON "artifact" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "catalog_category_user_idx" ON "catalog_category" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "catalog_type_user_idx" ON "catalog_type" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "goal_user_idx" ON "goal" USING btree ("user_id");--> statement-breakpoint
ALTER TABLE "task" ADD CONSTRAINT "task_artifact_id_artifact_id_fk" FOREIGN KEY ("artifact_id") REFERENCES "public"."artifact"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
-- Every project becomes a one-off delivery, with the same id, name, notes,
-- deadline and doneness, queued in the order it was written down.
INSERT INTO "artifact" ("id", "user_id", "title", "notes", "deadline", "done_at", "position", "created_at", "updated_at")
SELECT "id", "user_id", "title", "notes", "deadline", "done_at",
	ROW_NUMBER() OVER (PARTITION BY "user_id" ORDER BY "created_at", "id"),
	"created_at", "updated_at"
FROM "project";--> statement-breakpoint
UPDATE "task" SET "artifact_id" = "project_id" WHERE "project_id" IS NOT NULL;
