ALTER TABLE "session" ADD COLUMN "device_name" text;--> statement-breakpoint
ALTER TABLE "session" ADD COLUMN "city" text;--> statement-breakpoint
ALTER TABLE "session" ADD COLUMN "country_code" text;--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "first_name" text;--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "last_name" text;--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "phone" text;--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "blik_phone" text;--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "iban" text;--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "language" text DEFAULT 'pl';--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "default_currency" text DEFAULT 'PLN';--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "date_format" text DEFAULT 'dd.MM.yyyy';--> statement-breakpoint
ALTER TABLE "user" ADD COLUMN "week_start" text DEFAULT 'monday';