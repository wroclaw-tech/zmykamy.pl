CREATE TABLE "trip_invite" (
	"trip_id" uuid PRIMARY KEY NOT NULL,
	"code" text NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "trip_invite_code_unique" UNIQUE("code")
);
--> statement-breakpoint
ALTER TABLE "trip_invite" ADD CONSTRAINT "trip_invite_trip_id_trip_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trip"("id") ON DELETE cascade ON UPDATE no action;