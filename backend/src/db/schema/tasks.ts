import { relations } from "drizzle-orm";
import { date, index, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";
import { user } from "./auth";
import { trip } from "./trips";

export const tripTask = pgTable(
  "trip_task",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    assigneeId: text("assignee_id").references(() => user.id, { onDelete: "set null" }),
    dueDate: date("due_date"),
    completedAt: timestamp("completed_at"),
    createdBy: text("created_by").references(() => user.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at")
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => [index("trip_task_tripId_idx").on(table.tripId)],
);

export const tripTaskRelations = relations(tripTask, ({ one }) => ({
  trip: one(trip, { fields: [tripTask.tripId], references: [trip.id] }),
}));
