CREATE TABLE "trip_email_invite" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"trip_id" uuid NOT NULL,
	"email" text NOT NULL,
	"invited_by" text,
	"sent_at" timestamp DEFAULT now() NOT NULL,
	"joined_at" timestamp,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "trip_email_invite" ADD CONSTRAINT "trip_email_invite_trip_id_trip_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trip"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trip_email_invite" ADD CONSTRAINT "trip_email_invite_invited_by_user_id_fk" FOREIGN KEY ("invited_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "trip_email_invite_tripId_email_idx" ON "trip_email_invite" USING btree ("trip_id","email");--> statement-breakpoint
CREATE INDEX "trip_email_invite_email_idx" ON "trip_email_invite" USING btree ("email");