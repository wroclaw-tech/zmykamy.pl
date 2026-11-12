import { afterEach, beforeAll, beforeEach, describe, expect, test } from "bun:test";
import { eq } from "drizzle-orm";
import { db } from "../db";
import { trip, tripMember, user } from "../db/schema";
import app from "../index";
import { clearExchangeRateCache } from "../lib/exchange-rates";
import { createTrip, createUser, mockNbp, request, type TestUser } from "./test-helpers";

beforeAll(() => {
  if (!process.env.DATABASE_URL?.endsWith("_test")) {
    throw new Error("Tests must run against the test database, run `bun run test`");
  }
});

beforeEach(async () => {
  await db.delete(trip);
  await db.delete(user);
});

type Settlement = {
  balances: { userId: string; balance: number }[];
  transfers: {
    from: { userId: string };
    to: { userId: string };
    amount: number;
    paymentDetails: { blikPhone: string | null; iban: string | null } | null;
  }[];
  payments: { id: string; amount: number }[];
  naiveTransferCount: number;
};

const setup = async () => {
  const kuba = await createUser("Kuba");
  const ola = await createUser("Ola");
  const zuza = await createUser("Zuza");
  const { id } = await createTrip(kuba);
  await db.insert(tripMember).values([
    { tripId: id, userId: ola.id, role: "participant" },
    { tripId: id, userId: zuza.id, role: "participant" },
  ]);
  return { kuba, ola, zuza, id };
};

const dinner = (paidBy: string, participants: string[]) => ({
  title: "Kolacja w Time Out",
  amount: 9000,
  date: "2027-05-13",
  icon: "restaurant",
  paidBy,
  participants,
});

const addExpense = async (as: TestUser, tripId: string, body: unknown) => {
  const response = await request(`/trips/${tripId}/expenses`, as, { method: "POST", body });
  return (await response.json()) as { id: string };
};

const getSettlement = async (as: TestUser, tripId: string) =>
  (await (await request(`/trips/${tripId}/settlement`, as)).json()) as Settlement;

const balanceOf = (settlement: Settlement, userId: string) =>
  settlement.balances.find((entry) => entry.userId === userId)?.balance;

describe("expense access", () => {
  test("requires authentication", async () => {
    const { id } = await setup();
    expect((await app.request(`/trips/${id}/expenses`)).status).toBe(401);
  });

  test("hides expenses and the settlement from non-members", async () => {
    const { kuba, id } = await setup();
    const stranger = await createUser("Bartek");
    const responses = await Promise.all([
      request(`/trips/${id}/expenses`, stranger),
      request(`/trips/${id}/settlement`, stranger),
      request(`/trips/${id}/expenses`, stranger, {
        method: "POST",
        body: dinner(kuba.id, [kuba.id]),
      }),
    ]);
    expect(responses.map((response) => response.status)).toEqual([404, 404, 404]);
  });
});

describe("expenses", () => {
  test("creates an expense split evenly between the chosen members", async () => {
    const { kuba, ola, zuza, id } = await setup();
    const response = await request(`/trips/${id}/expenses`, ola, {
      method: "POST",
      body: { ...dinner(kuba.id, [kuba.id, ola.id, zuza.id]), amount: 10000 },
    });

    expect(response.status).toBe(201);
    const body = (await response.json()) as {
      shares: { userId: string; amount: number }[];
    } & Record<string, unknown>;
    expect(body).toMatchObject({
      title: "Kolacja w Time Out",
      amount: 10000,
      date: "2027-05-13",
      icon: "restaurant",
      paidBy: { userId: kuba.id, name: "Kuba" },
      author: { userId: ola.id, name: "Ola" },
    });
    expect(body.shares.map((share) => share.amount).toSorted()).toEqual([3333, 3333, 3334]);
    expect(body.shares.reduce((sum, share) => sum + share.amount, 0)).toBe(10000);
  });

  test("rejects payers and participants outside the trip", async () => {
    const { kuba, id } = await setup();
    const stranger = await createUser("Bartek");
    const responses = await Promise.all([
      request(`/trips/${id}/expenses`, kuba, {
        method: "POST",
        body: dinner(stranger.id, [kuba.id]),
      }),
      request(`/trips/${id}/expenses`, kuba, {
        method: "POST",
        body: dinner(kuba.id, [kuba.id, stranger.id]),
      }),
    ]);
    expect(responses.map((response) => response.status)).toEqual([400, 400]);
  });

  test("rejects invalid amounts and empty splits", async () => {
    const { kuba, id } = await setup();
    const responses = await Promise.all([
      request(`/trips/${id}/expenses`, kuba, {
        method: "POST",
        body: { ...dinner(kuba.id, [kuba.id]), amount: 0 },
      }),
      request(`/trips/${id}/expenses`, kuba, {
        method: "POST",
        body: { ...dinner(kuba.id, [kuba.id]), amount: 12.5 },
      }),
      request(`/trips/${id}/expenses`, kuba, { method: "POST", body: dinner(kuba.id, []) }),
    ]);
    expect(responses.map((response) => response.status)).toEqual([400, 400, 400]);
  });

  test("lists expenses newest day first", async () => {
    const { kuba, id } = await setup();
    await addExpense(kuba, id, { ...dinner(kuba.id, [kuba.id]), date: "2027-05-12" });
    await addExpense(kuba, id, { ...dinner(kuba.id, [kuba.id]), date: "2027-05-14" });
    const { expenses } = (await (await request(`/trips/${id}/expenses`, kuba)).json()) as {
      expenses: { date: string }[];
    };
    expect(expenses.map((expense) => expense.date)).toEqual(["2027-05-14", "2027-05-12"]);
  });

  test("recomputes shares when the amount or participants change", async () => {
    const { kuba, ola, zuza, id } = await setup();
    const { id: expenseId } = await addExpense(kuba, id, dinner(kuba.id, [kuba.id, ola.id]));

    const response = await request(`/trips/${id}/expenses/${expenseId}`, kuba, {
      method: "PATCH",
      body: { amount: 600, participants: [ola.id, zuza.id, kuba.id] },
    });
    expect(response.status).toBe(200);
    const { shares } = (await response.json()) as { shares: { amount: number }[] };
    expect(shares.map((share) => share.amount)).toEqual([200, 200, 200]);

    const renamed = await request(`/trips/${id}/expenses/${expenseId}`, kuba, {
      method: "PATCH",
      body: { title: "Kolacja" },
    });
    expect(((await renamed.json()) as { shares: unknown[] }).shares).toHaveLength(3);
  });

  test("lets only the author or an organizer change an expense", async () => {
    const { kuba, ola, zuza, id } = await setup();
    const { id: byOla } = await addExpense(ola, id, dinner(ola.id, [ola.id, zuza.id]));

    const byZuza = await request(`/trips/${id}/expenses/${byOla}`, zuza, {
      method: "PATCH",
      body: { title: "Moja kolacja" },
    });
    const byOrganizer = await request(`/trips/${id}/expenses/${byOla}`, kuba, {
      method: "PATCH",
      body: { title: "Kolacja" },
    });
    const deleted = await request(`/trips/${id}/expenses/${byOla}`, ola, { method: "DELETE" });

    expect([byZuza.status, byOrganizer.status, deleted.status]).toEqual([403, 200, 204]);
  });

  test("returns 404 for an expense from another trip", async () => {
    const { kuba, id } = await setup();
    const { id: otherTrip } = await createTrip(kuba);
    const { id: expenseId } = await addExpense(kuba, otherTrip, dinner(kuba.id, [kuba.id]));
    const response = await request(`/trips/${id}/expenses/${expenseId}`, kuba, {
      method: "DELETE",
    });
    expect(response.status).toBe(404);
  });
});

type ExpenseResponse = {
  amount: number;
  shares: { amount: number }[];
  original: {
    currency: string;
    amount: number;
    exchangeRate: number;
    rateSource: "nbp" | "custom";
    rateDate: string | null;
    rateTable: "A" | "B" | "A/B" | null;
  } | null;
};

describe("foreign currency expenses", () => {
  let fetchSpy: ReturnType<typeof mockNbp>;

  beforeEach(() => {
    clearExchangeRateCache();
    fetchSpy = mockNbp();
  });

  afterEach(() => fetchSpy.mockRestore());

  const addForeign = async (as: TestUser, tripId: string, extra: Record<string, unknown>) => {
    const response = await request(`/trips/${tripId}/expenses`, as, {
      method: "POST",
      body: { ...dinner(as.id, [as.id]), ...extra },
    });
    return {
      status: response.status,
      body: (await response.json()) as ExpenseResponse & { id: string },
    };
  };

  test("converts to the trip currency at the NBP mid rate", async () => {
    const { kuba, ola, id } = await setup();
    const { status, body } = await addForeign(kuba, id, {
      amount: 42500,
      currency: "PLN",
      participants: [kuba.id, ola.id],
    });
    expect(status).toBe(201);
    expect(body.amount).toBe(10000);
    expect(body.shares.map((share) => share.amount)).toEqual([5000, 5000]);
    expect(body.original).toMatchObject({
      currency: "PLN",
      amount: 42500,
      rateSource: "nbp",
      rateDate: "2026-05-08",
      rateTable: "A",
    });
    expect(body.original!.exchangeRate).toBeCloseTo(1 / 4.25);
  });

  test("persists mixed-table attribution in the expense list", async () => {
    const { kuba, id } = await setup();
    const { status, body } = await addForeign(kuba, id, { amount: 1000000, currency: "VND" });
    expect(status).toBe(201);
    expect(body.original?.rateTable).toBe("A/B");
    const response = await request(`/trips/${id}/expenses`, kuba);
    const listed = (await response.json()) as { expenses: ExpenseResponse[] };
    expect(listed.expenses[0]?.original?.rateTable).toBe("A/B");
  });

  test("uses a custom rate when given", async () => {
    const { kuba, id } = await setup();
    const { body } = await addForeign(kuba, id, {
      amount: 10000,
      currency: "USD",
      exchangeRate: 0.9,
    });
    expect(body.amount).toBe(9000);
    expect(body.original).toMatchObject({
      rateSource: "custom",
      exchangeRate: 0.9,
      rateDate: null,
      rateTable: null,
    });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  test("stores amounts in the trip currency as they are", async () => {
    const { kuba, id } = await setup();
    const { body } = await addForeign(kuba, id, { currency: "EUR" });
    expect(body.amount).toBe(9000);
    expect(body.original).toBeNull();
  });

  test("rejects currencies without an NBP rate", async () => {
    const { kuba, id } = await setup();
    const { status, body } = await addForeign(kuba, id, { currency: "XAU" });
    expect(status).toBe(422);
    expect(body).toMatchObject({ error: { code: "unsupported_currency" } });
  });

  test("recomputes the amount on edits", async () => {
    const { kuba, id } = await setup();
    const { body: created } = await addForeign(kuba, id, { amount: 10000, currency: "USD" });
    expect(created.amount).toBe(9412);
    const patch = async (body: unknown) =>
      (await (
        await request(`/trips/${id}/expenses/${created.id}`, kuba, { method: "PATCH", body })
      ).json()) as ExpenseResponse;

    expect((await patch({ amount: 20000 })).amount).toBe(18824);
    const custom = await patch({ exchangeRate: 1 });
    expect(custom.amount).toBe(20000);
    expect(custom.original?.rateTable).toBeNull();
    expect((await patch({ date: "2027-05-14" })).original).toMatchObject({
      rateSource: "custom",
      exchangeRate: 1,
    });
    expect((await patch({ exchangeRate: null })).original).toMatchObject({
      rateSource: "nbp",
      rateTable: "A",
    });
    const local = await patch({ currency: "EUR", amount: 5000 });
    expect(local.amount).toBe(5000);
    expect(local.original).toBeNull();
  });

  test("leaves the amount alone when only other fields change", async () => {
    const { kuba, id } = await setup();
    const { body: created } = await addForeign(kuba, id, { amount: 10000, currency: "USD" });
    fetchSpy.mockClear();
    await request(`/trips/${id}/expenses/${created.id}`, kuba, {
      method: "PATCH",
      body: { title: "Obiad" },
    });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  test("returns the rate for a day", async () => {
    const { kuba, id } = await setup();
    const response = await request(`/trips/${id}/exchange-rate?currency=usd&date=2026-05-10`, kuba);
    expect(response.status).toBe(200);
    const body = (await response.json()) as { from: string; to: string; rate: number };
    expect(body).toMatchObject({ from: "USD", to: "EUR", effectiveDate: "2026-05-08", table: "A" });
    expect(body.rate).toBeCloseTo(4 / 4.25);
  });
});

describe("settlement", () => {
  test("balances expenses and suggests the fewest transfers", async () => {
    const { kuba, ola, zuza, id } = await setup();
    await addExpense(kuba, id, dinner(kuba.id, [kuba.id, ola.id, zuza.id]));
    await addExpense(ola, id, { ...dinner(ola.id, [kuba.id, ola.id, zuza.id]), amount: 3000 });

    const settlement = await getSettlement(zuza, id);
    expect(balanceOf(settlement, kuba.id)).toBe(5000);
    expect(balanceOf(settlement, ola.id)).toBe(-1000);
    expect(balanceOf(settlement, zuza.id)).toBe(-4000);
    expect(settlement.naiveTransferCount).toBe(4);
    expect(
      settlement.transfers.map(({ from, to, amount }) => [from.userId, to.userId, amount]),
    ).toEqual([
      [zuza.id, kuba.id, 4000],
      [ola.id, kuba.id, 1000],
    ]);
  });

  test("shares the recipient's payment details only with the payer", async () => {
    const { kuba, ola, id } = await setup();
    await db
      .update(user)
      .set({ blikPhone: "+48512345678", iban: "PL61109010140000071219812874" })
      .where(eq(user.id, kuba.id));
    await addExpense(kuba, id, dinner(kuba.id, [kuba.id, ola.id]));

    const asPayer = await getSettlement(ola, id);
    const asRecipient = await getSettlement(kuba, id);
    expect(asPayer.transfers[0]?.paymentDetails).toEqual({
      blikPhone: "+48512345678",
      iban: "PL61109010140000071219812874",
    });
    expect(asRecipient.transfers[0]?.paymentDetails).toBeNull();
  });

  test("records and undoes a payment", async () => {
    const { kuba, ola, id } = await setup();
    await addExpense(kuba, id, dinner(kuba.id, [kuba.id, ola.id]));

    const paid = await request(`/trips/${id}/settlement/payments`, ola, {
      method: "POST",
      body: { fromUserId: ola.id, toUserId: kuba.id, amount: 4500 },
    });
    expect(paid.status).toBe(201);
    const afterPayment = (await paid.json()) as Settlement;
    expect(afterPayment.transfers).toEqual([]);
    expect(afterPayment.payments).toHaveLength(1);
    expect(balanceOf(afterPayment, ola.id)).toBe(0);

    const undone = await request(
      `/trips/${id}/settlement/payments/${afterPayment.payments[0]!.id}`,
      kuba,
      { method: "DELETE" },
    );
    expect(undone.status).toBe(200);
    expect(((await undone.json()) as Settlement).transfers).toHaveLength(1);
  });

  test("lets only the people in a transfer or an organizer record it", async () => {
    const { kuba, ola, zuza, id } = await setup();
    const body = { fromUserId: ola.id, toUserId: kuba.id, amount: 100 };
    const byZuza = await request(`/trips/${id}/settlement/payments`, zuza, {
      method: "POST",
      body,
    });
    const byOrganizer = await request(`/trips/${id}/settlement/payments`, kuba, {
      method: "POST",
      body: { fromUserId: ola.id, toUserId: zuza.id, amount: 100 },
    });
    const toSelf = await request(`/trips/${id}/settlement/payments`, ola, {
      method: "POST",
      body: { fromUserId: ola.id, toUserId: ola.id, amount: 100 },
    });
    expect([byZuza.status, byOrganizer.status, toSelf.status]).toEqual([403, 201, 400]);
  });

  test("shows balances on the trip and blocks leaving while unsettled", async () => {
    const { kuba, ola, id } = await setup();
    await addExpense(kuba, id, dinner(kuba.id, [kuba.id, ola.id]));

    const { members } = (await (await request(`/trips/${id}`, ola)).json()) as {
      members: { userId: string; balance: number }[];
    };
    expect(members.find((member) => member.userId === ola.id)?.balance).toBe(-4500);

    const leave = await request(`/trips/${id}/members/me`, ola, { method: "DELETE" });
    const remove = await request(`/trips/${id}/members/${ola.id}`, kuba, { method: "DELETE" });
    expect([leave.status, remove.status]).toEqual([409, 409]);
  });
});
