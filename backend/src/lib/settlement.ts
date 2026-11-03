export type Share = { userId: string; amount: number };

export type Transfer = { from: string; to: string; amount: number };

type LedgerExpense = { paidBy: string; amount: number; shares: Share[] };

type LedgerPayment = { fromUserId: string; toUserId: string; amount: number };

const MAX_EXACT_SIZE = 15;

export const splitEvenly = (amount: number, userIds: string[]): Share[] => {
  const unique = [...new Set(userIds)].toSorted();
  const base = Math.floor(amount / unique.length);
  const remainder = amount - base * unique.length;
  return unique.map((userId, index) => ({ userId, amount: base + (index < remainder ? 1 : 0) }));
};

export const computeBalances = (expenses: LedgerExpense[], payments: LedgerPayment[] = []) => {
  const balances = new Map<string, number>();
  const add = (userId: string, amount: number) =>
    balances.set(userId, (balances.get(userId) ?? 0) + amount);
  for (const expense of expenses) {
    add(expense.paidBy, expense.amount);
    for (const share of expense.shares) {
      add(share.userId, -share.amount);
    }
  }
  for (const payment of payments) {
    add(payment.fromUserId, payment.amount);
    add(payment.toUserId, -payment.amount);
  }
  return balances;
};

export const countNaiveTransfers = (expenses: LedgerExpense[]) =>
  expenses.reduce(
    (count, expense) =>
      count +
      expense.shares.filter((share) => share.userId !== expense.paidBy && share.amount > 0).length,
    0,
  );

const settleGroup = (group: Share[]): Transfer[] => {
  const debtors = group.filter((entry) => entry.amount < 0).map((entry) => ({ ...entry }));
  const creditors = group.filter((entry) => entry.amount > 0).map((entry) => ({ ...entry }));
  const byAmount = (a: Share, b: Share) =>
    Math.abs(b.amount) - Math.abs(a.amount) || a.userId.localeCompare(b.userId);
  const transfers: Transfer[] = [];
  while (debtors.length > 0 && creditors.length > 0) {
    debtors.sort(byAmount);
    creditors.sort(byAmount);
    const debtor = debtors[0]!;
    const creditor = creditors[0]!;
    const amount = Math.min(-debtor.amount, creditor.amount);
    transfers.push({ from: debtor.userId, to: creditor.userId, amount });
    debtor.amount += amount;
    creditor.amount -= amount;
    if (debtor.amount === 0) {
      debtors.shift();
    }
    if (creditor.amount === 0) {
      creditors.shift();
    }
  }
  return transfers;
};

const findZeroSumGroups = (entries: Share[]): Share[][] => {
  const size = entries.length;
  const full = (1 << size) - 1;
  const sums = new Int32Array(full + 1);
  const groups = new Int8Array(full + 1);
  for (let mask = 1; mask <= full; mask++) {
    const lowest = 31 - Math.clz32(mask & -mask);
    sums[mask] = sums[mask ^ (1 << lowest)]! + entries[lowest]!.amount;
    let best = 0;
    for (let index = 0; index < size; index++) {
      if (mask & (1 << index)) {
        best = Math.max(best, groups[mask ^ (1 << index)]!);
      }
    }
    groups[mask] = best + (sums[mask] === 0 ? 1 : 0);
  }

  const removed: number[] = [];
  let mask = full;
  while (mask) {
    const closes = sums[mask] === 0 ? 1 : 0;
    for (let index = 0; index < size; index++) {
      const bit = 1 << index;
      if (mask & bit && groups[mask ^ bit]! + closes === groups[mask]) {
        removed.push(index);
        mask ^= bit;
        break;
      }
    }
  }

  const result: Share[][] = [];
  let current: Share[] = [];
  let built = 0;
  for (const index of removed.toReversed()) {
    current.push(entries[index]!);
    built |= 1 << index;
    if (sums[built] === 0) {
      result.push(current);
      current = [];
    }
  }
  if (current.length > 0) {
    result.push(current);
  }
  return result;
};

export const minimizeTransfers = (balances: Map<string, number>): Transfer[] => {
  const entries = [...balances]
    .filter(([, amount]) => amount !== 0)
    .map(([userId, amount]) => ({ userId, amount }))
    .toSorted((a, b) => a.userId.localeCompare(b.userId));
  if (entries.length === 0) {
    return [];
  }
  const groups = entries.length <= MAX_EXACT_SIZE ? findZeroSumGroups(entries) : [entries];
  return groups
    .flatMap(settleGroup)
    .toSorted((a, b) => b.amount - a.amount || a.from.localeCompare(b.from));
};
