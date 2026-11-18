ALTER TABLE "plan_point" ADD COLUMN "latitude" double precision;--> statement-breakpoint
ALTER TABLE "plan_point" ADD COLUMN "longitude" double precision;--> statement-breakpoint
ALTER TABLE "plan_point" ADD CONSTRAINT "plan_point_coordinates_check" CHECK (("plan_point"."latitude" IS NULL) = ("plan_point"."longitude" IS NULL));