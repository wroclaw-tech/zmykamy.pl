CREATE TABLE "expense" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"trip_id" uuid NOT NULL,
	"title" text NOT NULL,
	"amount" integer NOT NULL,
	"date" date NOT NULL,
	"icon" text DEFAULT 'savings' NOT NULL,
	"paid_by" text NOT NULL,
	"created_by" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "expense_amount_check" CHECK ("expense"."amount" > 0)
);
--> statement-breakpoint
CREATE TABLE "expense_share" (
	"expense_id" uuid NOT NULL,
	"user_id" text NOT NULL,
	"amount" integer NOT NULL,
	CONSTRAINT "expense_share_expense_id_user_id_pk" PRIMARY KEY("expense_id","user_id"),
	CONSTRAINT "expense_share_amount_check" CHECK ("expense_share"."amount" >= 0)
);
--> statement-breakpoint
CREATE TABLE "settlement_payment" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"trip_id" uuid NOT NULL,
	"from_user_id" text NOT NULL,
	"to_user_id" text NOT NULL,
	"amount" integer NOT NULL,
	"created_by" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "settlement_payment_amount_check" CHECK ("settlement_payment"."amount" > 0),
	CONSTRAINT "settlement_payment_users_check" CHECK ("settlement_payment"."from_user_id" <> "settlement_payment"."to_user_id")
);
--> statement-breakpoint
ALTER TABLE "expense" ADD CONSTRAINT "expense_trip_id_trip_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trip"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expense" ADD CONSTRAINT "expense_paid_by_user_id_fk" FOREIGN KEY ("paid_by") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expense" ADD CONSTRAINT "expense_created_by_user_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expense_share" ADD CONSTRAINT "expense_share_expense_id_expense_id_fk" FOREIGN KEY ("expense_id") REFERENCES "public"."expense"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expense_share" ADD CONSTRAINT "expense_share_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "settlement_payment" ADD CONSTRAINT "settlement_payment_trip_id_trip_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trip"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "settlement_payment" ADD CONSTRAINT "settlement_payment_from_user_id_user_id_fk" FOREIGN KEY ("from_user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "settlement_payment" ADD CONSTRAINT "settlement_payment_to_user_id_user_id_fk" FOREIGN KEY ("to_user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "settlement_payment" ADD CONSTRAINT "settlement_payment_created_by_user_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "expense_tripId_date_idx" ON "expense" USING btree ("trip_id","date");--> statement-breakpoint
CREATE INDEX "settlement_payment_tripId_idx" ON "settlement_payment" USING btree ("trip_id");