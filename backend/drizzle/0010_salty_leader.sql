ALTER TABLE "expense" ADD COLUMN "original_currency" text;--> statement-breakpoint
ALTER TABLE "expense" ADD COLUMN "original_amount" integer;--> statement-breakpoint
ALTER TABLE "expense" ADD COLUMN "exchange_rate" double precision;--> statement-breakpoint
ALTER TABLE "expense" ADD COLUMN "rate_source" text;--> statement-breakpoint
ALTER TABLE "expense" ADD COLUMN "rate_date" date;--> statement-breakpoint
ALTER TABLE "expense" ADD CONSTRAINT "expense_original_check" CHECK (("expense"."original_currency" IS NULL AND "expense"."original_amount" IS NULL AND "expense"."exchange_rate" IS NULL AND "expense"."rate_source" IS NULL)
        OR ("expense"."original_currency" IS NOT NULL AND "expense"."original_amount" > 0 AND "expense"."exchange_rate" > 0 AND "expense"."rate_source" IS NOT NULL));