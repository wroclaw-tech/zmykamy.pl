import { relations } from "drizzle-orm";
import {
  doublePrecision,
  index,
  integer,
  pgTable,
  text,
  timestamp,
  uuid,
} from "drizzle-orm/pg-core";
import { user } from "./auth";
import { trip } from "./trips";

export const MEDIA_KINDS = ["photo", "video"] as const;

export const media = pgTable(
  "media",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    kind: text("kind", { enum: MEDIA_KINDS }).notNull(),
    key: text("key").notNull(),
    thumbnailKey: text("thumbnail_key").notNull(),
    contentType: text("content_type").notNull(),
    width: integer("width").notNull(),
    height: integer("height").notNull(),
    durationSeconds: doublePrecision("duration_seconds"),
    takenAt: timestamp("taken_at", { withTimezone: true }).notNull(),
    uploadedBy: text("uploaded_by").references(() => user.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [index("media_tripId_takenAt_idx").on(table.tripId, table.takenAt)],
);

export const mediaRelations = relations(media, ({ one }) => ({
  trip: one(trip, { fields: [media.tripId], references: [trip.id] }),
  uploader: one(user, { fields: [media.uploadedBy], references: [user.id] }),
}));
