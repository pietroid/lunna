CREATE TABLE "link_preview" (
	"url" text PRIMARY KEY NOT NULL,
	"title" text,
	"site" text,
	"image" text,
	"failed" boolean DEFAULT false NOT NULL,
	"fetched_at" timestamp with time zone NOT NULL
);
