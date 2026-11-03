CREATE TABLE "trip_document" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"trip_id" uuid NOT NULL,
	"title" text NOT NULL,
	"category" text NOT NULL,
	"icon" text NOT NULL,
	"kind" text NOT NULL,
	"key" text,
	"content_type" text,
	"url" text,
	"plan_point_id" uuid,
	"created_by" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "trip_document_source_check" CHECK (("trip_document"."kind" = 'file' and "trip_document"."key" is not null) or ("trip_document"."kind" = 'link' and "trip_document"."url" is not null))
);
--> statement-breakpoint
CREATE TABLE "trip_note" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"trip_id" uuid NOT NULL,
	"title" text NOT NULL,
	"text" text DEFAULT '' NOT NULL,
	"pinned" boolean DEFAULT false NOT NULL,
	"created_by" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "trip_document" ADD CONSTRAINT "trip_document_trip_id_trip_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trip"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trip_document" ADD CONSTRAINT "trip_document_plan_point_id_plan_point_id_fk" FOREIGN KEY ("plan_point_id") REFERENCES "public"."plan_point"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trip_document" ADD CONSTRAINT "trip_document_created_by_user_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trip_note" ADD CONSTRAINT "trip_note_trip_id_trip_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trip"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "trip_note" ADD CONSTRAINT "trip_note_created_by_user_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "trip_document_tripId_idx" ON "trip_document" USING btree ("trip_id");--> statement-breakpoint
CREATE INDEX "trip_note_tripId_idx" ON "trip_note" USING btree ("trip_id");