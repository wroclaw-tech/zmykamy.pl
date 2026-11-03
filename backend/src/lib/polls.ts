import type { poll } from "../db/schema";

export type PollStatus = "open" | "closed" | "resolved";

export const getPollStatus = (
  record: Pick<typeof poll.$inferSelect, "resolvedAt" | "closesAt">,
  now = new Date(),
): PollStatus => {
  if (record.resolvedAt) {
    return "resolved";
  }
  return record.closesAt && record.closesAt <= now ? "closed" : "open";
};
