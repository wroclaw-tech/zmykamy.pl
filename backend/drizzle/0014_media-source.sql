ALTER TABLE "media" ADD COLUMN "source" text;--> statement-breakpoint
ALTER TABLE "media" ADD COLUMN "external_id" text;--> statement-breakpoint
CREATE UNIQUE INDEX "media_tripId_source_externalId_idx" ON "media" USING btree ("trip_id","source","external_id");