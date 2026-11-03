import { eq, inArray } from "drizzle-orm";
import { db } from "../db";
import { expense, settlementPayment } from "../db/schema";
import { computeBalances } from "./settlement";

export const getTripLedger = async (tripId: string) => {
  const [expenses, payments] = await Promise.all([
    db.query.expense.findMany({ where: eq(expense.tripId, tripId), with: { shares: true } }),
    db.query.settlementPayment.findMany({ where: eq(settlementPayment.tripId, tripId) }),
  ]);
  return { expenses, payments };
};

export const getTripBalances = async (tripId: string) => {
  const { expenses, payments } = await getTripLedger(tripId);
  return computeBalances(expenses, payments);
};

export const getBalancesByTrip = async (tripIds: string[]) => {
  const result = new Map<string, Map<string, number>>();
  if (tripIds.length === 0) {
    return result;
  }
  const [expenses, payments] = await Promise.all([
    db.query.expense.findMany({ where: inArray(expense.tripId, tripIds), with: { shares: true } }),
    db.query.settlementPayment.findMany({ where: inArray(settlementPayment.tripId, tripIds) }),
  ]);
  for (const tripId of tripIds) {
    result.set(
      tripId,
      computeBalances(
        expenses.filter((record) => record.tripId === tripId),
        payments.filter((record) => record.tripId === tripId),
      ),
    );
  }
  return result;
};
