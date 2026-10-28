ALTER TABLE "goal" ALTER COLUMN "period" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "goal" ADD COLUMN "deadline" date;--> statement-breakpoint
-- A goal that repeated over weeks or months becomes the stretch it is in
-- now (or its first, still ahead): from its Monday or 1st to its Sunday or
-- last day. "Now" is the database's day, which is the person's within a
-- few hours of midnight.
UPDATE "goal" SET
  "starts" = date_trunc("period", GREATEST("starts", current_date))::date,
  "deadline" = (
    date_trunc("period", GREATEST("starts", current_date))
      + CASE WHEN "period" = 'week' THEN interval '6 days'
             ELSE interval '1 month' - interval '1 day' END
  )::date;--> statement-breakpoint
ALTER TABLE "goal" ALTER COLUMN "deadline" SET NOT NULL;
