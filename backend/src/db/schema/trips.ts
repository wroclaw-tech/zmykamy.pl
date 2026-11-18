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
  uniqueIndex,
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

export const tripInvite = pgTable("trip_invite", {
  tripId: uuid("trip_id")
    .primaryKey()
    .references(() => trip.id, { onDelete: "cascade" }),
  code: text("code").notNull().unique(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const tripEmailInvite = pgTable(
  "trip_email_invite",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    email: text("email").notNull(),
    invitedBy: text("invited_by").references(() => user.id, { onDelete: "set null" }),
    sentAt: timestamp("sent_at").defaultNow().notNull(),
    joinedAt: timestamp("joined_at"),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    uniqueIndex("trip_email_invite_tripId_email_idx").on(table.tripId, table.email),
    index("trip_email_invite_email_idx").on(table.email),
  ],
);

export const tripRelations = relations(trip, ({ many, one }) => ({
  members: many(tripMember),
  invite: one(tripInvite),
  emailInvites: many(tripEmailInvite),
}));

export const tripEmailInviteRelations = relations(tripEmailInvite, ({ one }) => ({
  trip: one(trip, { fields: [tripEmailInvite.tripId], references: [trip.id] }),
  inviter: one(user, { fields: [tripEmailInvite.invitedBy], references: [user.id] }),
}));

export const tripInviteRelations = relations(tripInvite, ({ one }) => ({
  trip: one(trip, {
    fields: [tripInvite.tripId],
    references: [trip.id],
  }),
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
