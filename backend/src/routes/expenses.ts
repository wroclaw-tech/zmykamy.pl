import { and, desc, eq, inArray } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db";
import { expense, expenseShare, settlementPayment, user } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { getTripLedger } from "../lib/balances";
import { ApiError } from "../lib/errors";
import { convertAtRate, inTripCurrency, resolveAmount } from "../lib/expense-amount";
import { getExchangeRate } from "../lib/exchange-rates";
import {
  computeBalances,
  countNaiveTransfers,
  minimizeTransfers,
  splitEvenly,
} from "../lib/settlement";
import { validate } from "../lib/validation";
import { requireAuth } from "../middleware/require-auth";
import {
  createExpenseSchema,
  createPaymentSchema,
  exchangeRateQuerySchema,
  expenseParamSchema,
  paymentParamSchema,
  updateExpenseSchema,
} from "../schemas/expense";
import { tripIdParamSchema } from "../schemas/trip";
import { getMemberTrip } from "./trips";

type MemberTrip = Awaited<ReturnType<typeof getMemberTrip>>;

type Person = { id: string; name: string };

const toPerson = (person: Person) => ({ userId: person.id, name: person.name });

const findExpense = (id: string, tripId: string) =>
  db.query.expense.findFirst({
    where: and(eq(expense.id, id), eq(expense.tripId, tripId)),
    with: { payer: true, author: true, shares: { with: { user: true } } },
  });

type ExpenseRecord = NonNullable<Awaited<ReturnType<typeof findExpense>>>;

const toExpenseResponse = (record: ExpenseRecord) => ({
  id: record.id,
  title: record.title,
  amount: record.amount,
  date: record.date,
  icon: record.icon,
  original:
    record.originalCurrency && record.originalAmount && record.exchangeRate && record.rateSource
      ? {
          currency: record.originalCurrency,
          amount: record.originalAmount,
          exchangeRate: record.exchangeRate,
          rateSource: record.rateSource,
          rateDate: record.rateDate,
          rateTable: record.rateTable,
        }
      : null,
  paidBy: toPerson(record.payer),
  shares: record.shares
    .toSorted((a, b) => a.userId.localeCompare(b.userId))
    .map((share) => ({ ...toPerson(share.user), amount: share.amount })),
  author: record.author ? toPerson(record.author) : null,
  createdAt: record.createdAt,
});

const getRole = (record: MemberTrip, userId: string) =>
  record.members.find((member) => member.userId === userId)?.role;

const assertMembers = (record: MemberTrip, userIds: string[]) => {
  const memberIds = new Set(record.members.map((member) => member.userId));
  if (!userIds.every((userId) => memberIds.has(userId))) {
    throw new ApiError(400, "not_a_member", "Everyone in the expense must be a trip member");
  }
};

const assertCanEditExpense = (record: MemberTrip, userId: string, current: ExpenseRecord) => {
  if (getRole(record, userId) !== "organizer" && current.createdBy !== userId) {
    throw new ApiError(403, "forbidden", "Only the author or an organizer can change this");
  }
};

const assertCanRecordPayment = (
  record: MemberTrip,
  userId: string,
  payment: { fromUserId: string; toUserId: string },
) => {
  const isParty = payment.fromUserId === userId || payment.toUserId === userId;
  if (!isParty && getRole(record, userId) !== "organizer") {
    throw new ApiError(
      403,
      "forbidden",
      "Only the people in a transfer or an organizer can do this",
    );
  }
};

const getExpenseOrThrow = async (id: string, tripId: string) => {
  const current = await findExpense(id, tripId);
  if (!current) {
    throw new ApiError(404, "expense_not_found", "Expense not found");
  }
  return current;
};

// Returns the money columns after an edit, or null when they stay as stored. Values are
// compared rather than checking which fields were sent, because clients send the whole form.
const resolveUpdatedAmount = async (
  tripCurrency: string,
  current: ExpenseRecord,
  patch: { amount?: number; currency?: string; exchangeRate?: number | null; date?: string },
) => {
  // Clients from before foreign currencies send `amount` in the trip currency without `currency`
  if (patch.amount !== undefined && patch.currency === undefined) {
    if (patch.amount !== current.amount) {
      return inTripCurrency(patch.amount);
    }
    patch = { ...patch, amount: undefined };
  }
  const storedCurrency = current.originalCurrency ?? tripCurrency;
  const storedAmount = current.originalAmount ?? current.amount;
  const currency = patch.currency ?? storedCurrency;
  const amount = patch.amount ?? storedAmount;
  const date = patch.date ?? current.date;

  if (currency === tripCurrency) {
    return current.originalCurrency === null && amount === current.amount
      ? null
      : inTripCurrency(amount);
  }
  const sameCurrency = currency === current.originalCurrency;
  const customRate =
    patch.exchangeRate !== undefined
      ? patch.exchangeRate
      : sameCurrency && current.rateSource === "custom"
        ? current.exchangeRate
        : null;

  if (customRate !== null) {
    const unchanged =
      sameCurrency &&
      current.rateSource === "custom" &&
      current.exchangeRate === customRate &&
      amount === storedAmount;
    return unchanged
      ? null
      : resolveAmount(tripCurrency, { amount, currency, date, exchangeRate: customRate });
  }
  // Keep the stored NBP rate while the day stays the same, so a newer table doesn't reprice it
  if (sameCurrency && current.rateSource === "nbp" && date === current.date) {
    return amount === storedAmount
      ? null
      : convertAtRate(tripCurrency, amount, currency, {
          exchangeRate: current.exchangeRate!,
          rateSource: "nbp",
          rateDate: current.rateDate,
          rateTable: current.rateTable,
        });
  }
  return resolveAmount(tripCurrency, { amount, currency, date, exchangeRate: null });
};

const buildSettlement = async (record: MemberTrip, viewerId: string) => {
  const { expenses, payments } = await getTripLedger(record.id);
  const balances = computeBalances(expenses, payments);
  for (const member of record.members) {
    balances.set(member.userId, balances.get(member.userId) ?? 0);
  }
  const people = await db.query.user.findMany({
    where: inArray(user.id, [...balances.keys()]),
    columns: { id: true, name: true, blikPhone: true, iban: true },
  });
  const byId = new Map(people.map((person) => [person.id, person]));
  const personOf = (userId: string) => toPerson(byId.get(userId) ?? { id: userId, name: "?" });

  const toPaymentDetails = (userId: string) => {
    const person = byId.get(userId);
    return person && (person.blikPhone || person.iban)
      ? { blikPhone: person.blikPhone, iban: person.iban }
      : null;
  };

  return {
    balances: [...balances]
      .map(([userId, balance]) => ({ ...personOf(userId), balance }))
      .toSorted((a, b) => b.balance - a.balance || a.name.localeCompare(b.name)),
    transfers: minimizeTransfers(balances).map((transfer) => ({
      from: personOf(transfer.from),
      to: personOf(transfer.to),
      amount: transfer.amount,
      paymentDetails: transfer.from === viewerId ? toPaymentDetails(transfer.to) : null,
    })),
    payments: payments
      .toSorted((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .map((payment) => ({
        id: payment.id,
        from: personOf(payment.fromUserId),
        to: personOf(payment.toUserId),
        amount: payment.amount,
        createdAt: payment.createdAt,
      })),
    naiveTransferCount: countNaiveTransfers(expenses),
  };
};

export const expenses = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/:id/expenses", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    await getMemberTrip(id, c.get("user").id);
    const records = await db.query.expense.findMany({
      where: eq(expense.tripId, id),
      with: { payer: true, author: true, shares: { with: { user: true } } },
      orderBy: [desc(expense.date), desc(expense.createdAt)],
    });
    return c.json({ expenses: records.map(toExpenseResponse) });
  })
  .get(
    "/:id/exchange-rate",
    validate("param", tripIdParamSchema),
    validate("query", exchangeRateQuerySchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const { currency, date } = c.req.valid("query");
      const record = await getMemberTrip(id, c.get("user").id);
      const today = new Date().toISOString().slice(0, 10);
      const rate = await getExchangeRate(currency, record.currency, date ?? today);
      return c.json({ from: currency, to: record.currency, ...rate });
    },
  )
  .post(
    "/:id/expenses",
    validate("param", tripIdParamSchema),
    validate("json", createExpenseSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const userId = c.get("user").id;
      const { participants, currency, exchangeRate, amount, ...fields } = c.req.valid("json");
      const record = await getMemberTrip(id, userId);
      assertMembers(record, [fields.paidBy, ...participants]);
      const money = await resolveAmount(record.currency, {
        amount,
        currency: currency ?? record.currency,
        date: fields.date,
        exchangeRate: exchangeRate ?? null,
      });
      const expenseId = await db.transaction(async (tx) => {
        const [created] = await tx
          .insert(expense)
          .values({ ...fields, ...money, tripId: id, createdBy: userId })
          .returning({ id: expense.id });
        await tx.insert(expenseShare).values(
          splitEvenly(money.amount, participants).map((share) => ({
            ...share,
            expenseId: created!.id,
          })),
        );
        return created!.id;
      });
      return c.json(toExpenseResponse((await findExpense(expenseId, id))!), 201);
    },
  )
  .patch(
    "/:id/expenses/:expenseId",
    validate("param", expenseParamSchema),
    validate("json", updateExpenseSchema),
    async (c) => {
      const { id, expenseId } = c.req.valid("param");
      const userId = c.get("user").id;
      const { participants, currency, exchangeRate, amount, ...fields } = c.req.valid("json");
      const record = await getMemberTrip(id, userId);
      const current = await getExpenseOrThrow(expenseId, id);
      assertCanEditExpense(record, userId, current);
      assertMembers(record, [...(fields.paidBy ? [fields.paidBy] : []), ...(participants ?? [])]);

      const money = await resolveUpdatedAmount(record.currency, current, {
        amount,
        currency,
        exchangeRate,
        date: fields.date,
      });
      const changes = { ...fields, ...money };
      const shares =
        participants || (money && money.amount !== current.amount)
          ? splitEvenly(
              money?.amount ?? current.amount,
              participants ?? current.shares.map((share) => share.userId),
            )
          : null;
      await db.transaction(async (tx) => {
        if (Object.keys(changes).length > 0) {
          await tx.update(expense).set(changes).where(eq(expense.id, expenseId));
        }
        if (shares) {
          await tx.delete(expenseShare).where(eq(expenseShare.expenseId, expenseId));
          await tx.insert(expenseShare).values(shares.map((share) => ({ ...share, expenseId })));
        }
      });
      return c.json(toExpenseResponse((await findExpense(expenseId, id))!));
    },
  )
  .delete("/:id/expenses/:expenseId", validate("param", expenseParamSchema), async (c) => {
    const { id, expenseId } = c.req.valid("param");
    const userId = c.get("user").id;
    const record = await getMemberTrip(id, userId);
    assertCanEditExpense(record, userId, await getExpenseOrThrow(expenseId, id));
    await db.delete(expense).where(eq(expense.id, expenseId));
    return c.body(null, 204);
  })
  .get("/:id/settlement", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    const userId = c.get("user").id;
    return c.json(await buildSettlement(await getMemberTrip(id, userId), userId));
  })
  .post(
    "/:id/settlement/payments",
    validate("param", tripIdParamSchema),
    validate("json", createPaymentSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const userId = c.get("user").id;
      const body = c.req.valid("json");
      const record = await getMemberTrip(id, userId);
      assertMembers(record, [body.fromUserId, body.toUserId]);
      assertCanRecordPayment(record, userId, body);
      await db.insert(settlementPayment).values({ ...body, tripId: id, createdBy: userId });
      return c.json(await buildSettlement(record, userId), 201);
    },
  )
  .delete(
    "/:id/settlement/payments/:paymentId",
    validate("param", paymentParamSchema),
    async (c) => {
      const { id, paymentId } = c.req.valid("param");
      const userId = c.get("user").id;
      const record = await getMemberTrip(id, userId);
      const payment = await db.query.settlementPayment.findFirst({
        where: and(eq(settlementPayment.id, paymentId), eq(settlementPayment.tripId, id)),
      });
      if (!payment) {
        throw new ApiError(404, "payment_not_found", "Payment not found");
      }
      assertCanRecordPayment(record, userId, payment);
      await db.delete(settlementPayment).where(eq(settlementPayment.id, paymentId));
      return c.json(await buildSettlement(record, userId));
    },
  );
