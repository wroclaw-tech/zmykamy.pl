import { relations, sql } from "drizzle-orm";
import { boolean, check, index, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { user } from "./auth";
import { trip } from "./trips";

export const packingItem = pgTable(
  "packing_item",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    ownerId: text("owner_id").references(() => user.id, { onDelete: "cascade" }),
    assigneeId: text("assignee_id").references(() => user.id, { onDelete: "set null" }),
    name: text("name").notNull(),
    isPacked: boolean("is_packed").default(false).notNull(),
    createdBy: text("created_by").references(() => user.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at")
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => [
    index("packing_item_tripId_idx").on(table.tripId),
    check(
      "packing_item_personal_unassigned_check",
      sql`${table.ownerId} IS NULL OR ${table.assigneeId} IS NULL`,
    ),
  ],
);

export const packingItemRelations = relations(packingItem, ({ one }) => ({
  trip: one(trip, { fields: [packingItem.tripId], references: [trip.id] }),
}));
