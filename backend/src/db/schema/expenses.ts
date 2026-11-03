import { relations, sql } from "drizzle-orm";
import {
  check,
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
import { PLAN_ICONS } from "./plan";
import { trip } from "./trips";

export const expense = pgTable(
  "expense",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    title: text("title").notNull(),
    amount: integer("amount").notNull(),
    date: date("date").notNull(),
    icon: text("icon", { enum: PLAN_ICONS }).notNull().default("savings"),
    paidBy: text("paid_by")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    createdBy: text("created_by").references(() => user.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    updatedAt: timestamp("updated_at")
      .defaultNow()
      .$onUpdate(() => new Date())
      .notNull(),
  },
  (table) => [
    check("expense_amount_check", sql`${table.amount} > 0`),
    index("expense_tripId_date_idx").on(table.tripId, table.date),
  ],
);

export const expenseShare = pgTable(
  "expense_share",
  {
    expenseId: uuid("expense_id")
      .notNull()
      .references(() => expense.id, { onDelete: "cascade" }),
    userId: text("user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    amount: integer("amount").notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.expenseId, table.userId] }),
    check("expense_share_amount_check", sql`${table.amount} >= 0`),
  ],
);

export const settlementPayment = pgTable(
  "settlement_payment",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tripId: uuid("trip_id")
      .notNull()
      .references(() => trip.id, { onDelete: "cascade" }),
    fromUserId: text("from_user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    toUserId: text("to_user_id")
      .notNull()
      .references(() => user.id, { onDelete: "cascade" }),
    amount: integer("amount").notNull(),
    createdBy: text("created_by").references(() => user.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    check("settlement_payment_amount_check", sql`${table.amount} > 0`),
    check("settlement_payment_users_check", sql`${table.fromUserId} <> ${table.toUserId}`),
    index("settlement_payment_tripId_idx").on(table.tripId),
  ],
);

export const expenseRelations = relations(expense, ({ one, many }) => ({
  trip: one(trip, { fields: [expense.tripId], references: [trip.id] }),
  payer: one(user, { fields: [expense.paidBy], references: [user.id], relationName: "payer" }),
  author: one(user, { fields: [expense.createdBy], references: [user.id], relationName: "author" }),
  shares: many(expenseShare),
}));

export const expenseShareRelations = relations(expenseShare, ({ one }) => ({
  expense: one(expense, { fields: [expenseShare.expenseId], references: [expense.id] }),
  user: one(user, { fields: [expenseShare.userId], references: [user.id] }),
}));

export const settlementPaymentRelations = relations(settlementPayment, ({ one }) => ({
  trip: one(trip, { fields: [settlementPayment.tripId], references: [trip.id] }),
  from: one(user, {
    fields: [settlementPayment.fromUserId],
    references: [user.id],
    relationName: "paymentFrom",
  }),
  to: one(user, {
    fields: [settlementPayment.toUserId],
    references: [user.id],
    relationName: "paymentTo",
  }),
}));
