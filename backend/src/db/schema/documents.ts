import { relations, sql } from "drizzle-orm";
import { boolean, check, index, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { user } from "./auth";
import { PLAN_ICONS, planPoint } from "./plan";
import { trip } from "./trips";

export const DOCUMENT_CATEGORIES = ["ticket", "reservation", "other"] as const;

export const DOCUMENT_KINDS = ["file", "link"] as const;

export const tripDocument = pgTable(
  "trip_document",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    category: text("category", { enum: DOCUMENT_CATEGORIES }).notNull(),
    icon: text("icon", { enum: PLAN_ICONS }).notNull(),
    kind: text("kind", { enum: DOCUMENT_KINDS }).notNull(),
    key: text("key"),
    contentType: text("content_type"),
    url: text("url"),
    planPointId: uuid("plan_point_id").references(() => planPoint.id, { onDelete: "set null" }),
    createdBy: text("created_by").references(() => user.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at")
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => [
    check(
      "trip_document_source_check",
      sql`(${table.kind} = 'file' and ${table.key} is not null) or (${table.kind} = 'link' and ${table.url} is not null)`,
    ),
    index("trip_document_tripId_idx").on(table.tripId),
  ],
);

export const tripNote = pgTable(
  "trip_note",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    text: text("text").notNull().default(""),
    pinned: boolean("pinned").notNull().default(false),
    createdBy: text("created_by").references(() => user.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at")
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => [index("trip_note_tripId_idx").on(table.tripId)],
);

export const tripDocumentRelations = relations(tripDocument, ({ one }) => ({
  trip: one(trip, { fields: [tripDocument.tripId], references: [trip.id] }),
  author: one(user, { fields: [tripDocument.createdBy], references: [user.id] }),
  planPoint: one(planPoint, { fields: [tripDocument.planPointId], references: [planPoint.id] }),
}));

export const tripNoteRelations = relations(tripNote, ({ one }) => ({
  trip: one(trip, { fields: [tripNote.tripId], references: [trip.id] }),
  author: one(user, { fields: [tripNote.createdBy], references: [user.id] }),
}));
