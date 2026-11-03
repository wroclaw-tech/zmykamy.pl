import { relations } from "drizzle-orm";
import { date, index, pgTable, text, time, timestamp, uuid } from "drizzle-orm/pg-core";
import { user } from "./auth";
import { trip } from "./trips";

export const PLAN_ICONS = [
  "location_on",
  "info",
  "flight",
  "flight_takeoff",
  "flight_land",
  "train",
  "tram",
  "directions_car",
  "local_taxi",
  "bed",
  "key",
  "luggage",
  "confirmation_number",
  "restaurant",
  "coffee",
  "bakery_dining",
  "music_note",
  "castle",
  "park",
  "storefront",
  "shopping_cart",
  "photo_camera",
  "how_to_vote",
  "savings",
  "star",
] as const;

export type PlanIcon = (typeof PLAN_ICONS)[number];

export const planPoint = pgTable(
  "plan_point",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    date: date("date").notNull(),
    time: time("time").notNull(),
    title: text("title").notNull(),
    description: text("description"),
    place: text("place"),
    icon: text("icon", { enum: PLAN_ICONS }).notNull().default("location_on"),
    createdBy: text("created_by").references(() => user.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at")
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => [index("plan_point_tripId_date_idx").on(table.tripId, table.date)],
);

export const tripInfo = pgTable(
  "trip_info",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    text: text("text").notNull().default(""),
    icon: text("icon", { enum: PLAN_ICONS }).notNull().default("info"),
    createdBy: text("created_by").references(() => user.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at")
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => [index("trip_info_tripId_idx").on(table.tripId)],
);

export const planPointRelations = relations(planPoint, ({ one }) => ({
  trip: one(trip, { fields: [planPoint.tripId], references: [trip.id] }),
  author: one(user, { fields: [planPoint.createdBy], references: [user.id] }),
}));

export const tripInfoRelations = relations(tripInfo, ({ one }) => ({
  trip: one(trip, { fields: [tripInfo.tripId], references: [trip.id] }),
  author: one(user, { fields: [tripInfo.createdBy], references: [user.id] }),
}));
