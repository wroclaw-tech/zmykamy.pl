import { relations, sql } from "drizzle-orm";
import {
  check,
  date,
  doublePrecision,
  index,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uuid,
} from "drizzle-orm/pg-core";
import { user } from "./auth";

export const trip = pgTable(
  "trip",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    name: text("name").notNull(),
    destinationName: text("destination_name"),
    destinationCountry: text("destination_country"),
    destinationLatitude: doublePrecision("destination_latitude"),
    destinationLongitude: doublePrecision("destination_longitude"),
    startDate: date("start_date").notNull(),
    endDate: date("end_date").notNull(),
    currency: text("currency").notNull(),
    coverImageKey: text("cover_image_key"),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at")
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => [check("trip_date_range_check", sql`${table.endDate} >= ${table.startDate}`)],
);

export const tripMember = pgTable(
  "trip_member",
  {
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    role: text("role", { enum: ["organizer", "participant"] }).notNull(),
    joinedAt: timestamp("joined_at").defaultNow().notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.tripId, table.userId] }),
    index("trip_member_userId_idx").on(table.userId),
  ],
);

export const tripRelations = relations(trip, ({ many }) => ({
  members: many(tripMember),
}));

export const tripMemberRelations = relations(tripMember, ({ one }) => ({
  trip: one(trip, {
    fields: [tripMember.tripId],
    references: [trip.id],
  }),
  user: one(user, {
    fields: [tripMember.userId],
    references: [user.id],
  }),
}));
