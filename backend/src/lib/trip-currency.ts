import { eq } from "drizzle-orm";
import { db } from "../db";
import { expense, expenseShare, settlementPayment } from "../db/schema";
import { resolveAmount } from "./expense-amount";
import { convertAmount, getExchangeRate } from "./exchange-rates";
import { splitEvenly } from "./settlement";

type Transaction = Parameters<Parameters<typeof db.transaction>[0]>[0];

// Converts every expense and payment of the trip to the new currency. Rates are fetched
// up front so a failed NBP request leaves the trip untouched; the result is applied in `tx`.
export const prepareCurrencyChange = async (tripId: string, from: string, to: string) => {
  const [expenses, payments] = await Promise.all([
    db.query.expense.findMany({
      where: eq(expense.tripId, tripId),
      with: { shares: { columns: { userId: true } } },
    }),
    db.query.settlementPayment.findMany({ where: eq(settlementPayment.tripId, tripId) }),
  ]);

  const convertedExpenses = await Promise.all(
    expenses.map(async (record) => {
      const money = await resolveAmount(to, {
        amount: record.originalAmount ?? record.amount,
        currency: record.originalCurrency ?? from,
        date: record.date,
        exchangeRate: null,
      });
      const userIds = record.shares.map((share) => share.userId);
      return { id: record.id, money, shares: splitEvenly(money.amount, userIds) };
    }),
  );

  const convertedPayments = await Promise.all(
    payments.map(async (payment) => {
      const day = payment.createdAt.toISOString().slice(0, 10);
      const { rate } = await getExchangeRate(from, to, day);
      return { id: payment.id, amount: Math.max(1, convertAmount(payment.amount, from, to, rate)) };
    }),
  );

  return async (tx: Transaction) => {
    for (const { id, money, shares } of convertedExpenses) {
      await tx.update(expense).set(money).where(eq(expense.id, id));
      await tx.delete(expenseShare).where(eq(expenseShare.expenseId, id));
      if (shares.length > 0) {
        await tx.insert(expenseShare).values(shares.map((share) => ({ ...share, expenseId: id })));
      }
    }
    for (const { id, amount } of convertedPayments) {
      await tx.update(settlementPayment).set({ amount }).where(eq(settlementPayment.id, id));
    }
  };
};
