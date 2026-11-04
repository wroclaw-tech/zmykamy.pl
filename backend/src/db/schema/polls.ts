import { relations } from "drizzle-orm";
import {
  type AnyPgColumn,
  date,
  index,
  integer,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uuid,
} from "drizzle-orm/pg-core";
import { user } from "./auth";
import { trip } from "./trips";

export const poll = pgTable(
  "poll",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    question: text("question").notNull(),
    createdBy: text("created_by").references(() => user.id, { onDelete: "set null" }),
    closesAt: timestamp("closes_at"),
    resolvedAt: timestamp("resolved_at"),
    winningOptionId: uuid("winning_option_id").references((): AnyPgColumn => pollOption.id, {
      onDelete: "set null",
    }),
    planDate: date("plan_date"),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [index("poll_tripId_idx").on(table.tripId)],
);

export const pollOption = pgTable(
  "poll_option",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    pollId: uuid("poll_id")
      .notNull()
      .references(() => poll.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    description: text("description"),
    position: integer("position").notNull(),
  },
  (table) => [index("poll_option_pollId_idx").on(table.pollId)],
);

export const pollVote = pgTable(
  "poll_vote",
  {
    pollId: uuid("poll_id")
      .notNull()
      .references(() => poll.id, { onDelete: "cascade" }),
    optionId: uuid("option_id")
      .notNull()
      .references(() => pollOption.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.pollId, table.userId] }),
    index("poll_vote_optionId_idx").on(table.optionId),
  ],
);

export const pollRelations = relations(poll, ({ many, one }) => ({
  trip: one(trip, { fields: [poll.tripId], references: [trip.id] }),
  options: many(pollOption),
  votes: many(pollVote),
}));

export const pollOptionRelations = relations(pollOption, ({ one }) => ({
  poll: one(poll, { fields: [pollOption.pollId], references: [poll.id] }),
}));

export const pollVoteRelations = relations(pollVote, ({ one }) => ({
  poll: one(poll, { fields: [pollVote.pollId], references: [poll.id] }),
  option: one(pollOption, { fields: [pollVote.optionId], references: [pollOption.id] }),
}));
