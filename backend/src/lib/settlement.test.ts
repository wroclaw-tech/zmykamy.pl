import { describe, expect, test } from "bun:test";
import {
  computeBalances,
  countNaiveTransfers,
  minimizeTransfers,
  splitEvenly,
  type Transfer,
} from "./settlement";

const balancesOf = (entries: Record<string, number>) => new Map(Object.entries(entries));

const applyTransfers = (balances: Map<string, number>, transfers: Transfer[]) => {
  const result = new Map(balances);
  for (const { from, to, amount } of transfers) {
    result.set(from, result.get(from)! + amount);
    result.set(to, result.get(to)! - amount);
  }
  return result;
};

const expectSettled = (balances: Map<string, number>, transfers: Transfer[]) => {
  expect([...applyTransfers(balances, transfers).values()].every((value) => value === 0)).toBe(
    true,
  );
  expect(transfers.every((transfer) => transfer.amount > 0)).toBe(true);
};

describe("splitEvenly", () => {
  test("splits an amount that divides evenly", () => {
    expect(splitEvenly(9600, ["a", "b", "c", "d"])).toEqual([
      { userId: "a", amount: 2400 },
      { userId: "b", amount: 2400 },
      { userId: "c", amount: 2400 },
      { userId: "d", amount: 2400 },
    ]);
  });

  test("gives the remainder to the first users by id", () => {
    expect(splitEvenly(100, ["c", "a", "b"])).toEqual([
      { userId: "a", amount: 34 },
      { userId: "b", amount: 33 },
      { userId: "c", amount: 33 },
    ]);
  });

  test("ignores duplicate users", () => {
    expect(splitEvenly(10, ["a", "a", "b"])).toEqual([
      { userId: "a", amount: 5 },
      { userId: "b", amount: 5 },
    ]);
  });
});

describe("computeBalances", () => {
  test("credits the payer and debits every share", () => {
    const balances = computeBalances([
      { paidBy: "a", amount: 90, shares: splitEvenly(90, ["a", "b", "c"]) },
      { paidBy: "b", amount: 30, shares: splitEvenly(30, ["a", "b"]) },
    ]);
    expect(Object.fromEntries(balances)).toEqual({ a: 45, b: -15, c: -30 });
  });

  test("counts recorded payments", () => {
    const balances = computeBalances(
      [{ paidBy: "a", amount: 100, shares: splitEvenly(100, ["a", "b"]) }],
      [{ fromUserId: "b", toUserId: "a", amount: 50 }],
    );
    expect(Object.fromEntries(balances)).toEqual({ a: 0, b: 0 });
  });

  test("keeps the total at zero", () => {
    const balances = computeBalances([
      { paidBy: "a", amount: 1001, shares: splitEvenly(1001, ["a", "b", "c"]) },
      { paidBy: "c", amount: 77, shares: splitEvenly(77, ["b", "c"]) },
    ]);
    expect([...balances.values()].reduce((sum, value) => sum + value, 0)).toBe(0);
  });
});

describe("countNaiveTransfers", () => {
  test("counts shares of people other than the payer", () => {
    expect(
      countNaiveTransfers([
        { paidBy: "a", amount: 90, shares: splitEvenly(90, ["a", "b", "c"]) },
        { paidBy: "b", amount: 30, shares: splitEvenly(30, ["c"]) },
      ]),
    ).toBe(3);
  });
});

describe("minimizeTransfers", () => {
  test("returns nothing when everyone is settled", () => {
    expect(minimizeTransfers(balancesOf({ a: 0, b: 0 }))).toEqual([]);
    expect(minimizeTransfers(new Map())).toEqual([]);
  });

  test("settles one debtor with one creditor", () => {
    expect(minimizeTransfers(balancesOf({ a: 500, b: -500 }))).toEqual([
      { from: "b", to: "a", amount: 500 },
    ]);
  });

  test("settles a group of k people in k - 1 transfers", () => {
    const balances = balancesOf({ a: 700, b: -300, c: -250, d: -150 });
    const transfers = minimizeTransfers(balances);
    expectSettled(balances, transfers);
    expect(transfers).toHaveLength(3);
  });

  test("finds independent pairs a greedy match would miss", () => {
    const balances = balancesOf({ a: 500, b: 300, c: -300, d: -500 });
    const transfers = minimizeTransfers(balances);
    expectSettled(balances, transfers);
    expect(transfers).toEqual([
      { from: "d", to: "a", amount: 500 },
      { from: "c", to: "b", amount: 300 },
    ]);
  });

  test("beats largest-first matching on split groups", () => {
    const balances = balancesOf({ a: 6, b: 4, c: 3, d: -5, e: -5, f: -3 });
    const transfers = minimizeTransfers(balances);
    expectSettled(balances, transfers);
    expect(transfers).toHaveLength(4);
  });

  test("settles the trip from the design in five transfers", () => {
    const balances = computeBalances([
      {
        paidBy: "ola",
        amount: 540000,
        shares: splitEvenly(540000, ["ty", "ola", "michal", "zuza", "bartek", "natalia"]),
      },
      {
        paidBy: "michal",
        amount: 438000,
        shares: splitEvenly(438000, ["ty", "ola", "michal", "zuza", "bartek", "natalia"]),
      },
      {
        paidBy: "zuza",
        amount: 120400,
        shares: splitEvenly(120400, ["ty", "ola", "michal", "zuza", "bartek", "natalia"]),
      },
      {
        paidBy: "ty",
        amount: 84800,
        shares: splitEvenly(84800, ["ty", "ola", "michal", "zuza", "bartek", "natalia"]),
      },
      {
        paidBy: "bartek",
        amount: 22200,
        shares: splitEvenly(22200, ["ty", "ola", "michal", "zuza", "bartek", "natalia"]),
      },
      {
        paidBy: "natalia",
        amount: 8400,
        shares: splitEvenly(8400, ["ty", "ola", "michal", "zuza", "bartek", "natalia"]),
      },
    ]);
    const transfers = minimizeTransfers(balances);
    expectSettled(balances, transfers);
    expect(transfers.length).toBeLessThanOrEqual(5);
  });

  test("is deterministic regardless of insertion order", () => {
    const forward = minimizeTransfers(balancesOf({ a: 10, b: 20, c: -15, d: -15 }));
    const backward = minimizeTransfers(balancesOf({ d: -15, c: -15, b: 20, a: 10 }));
    expect(forward).toEqual(backward);
  });

  test("still settles everyone in large groups", () => {
    const entries: Record<string, number> = {};
    for (let index = 0; index < 20; index++) {
      entries[`user-${String(index).padStart(2, "0")}`] =
        index % 2 === 0 ? 100 + index : -(100 + index - 1);
    }
    const balances = balancesOf(entries);
    const transfers = minimizeTransfers(balances);
    expectSettled(balances, transfers);
    expect(transfers.length).toBeLessThanOrEqual(19);
  });
});
