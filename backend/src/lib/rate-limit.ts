import { lt, sql } from "drizzle-orm";
import type { Context } from "hono";
import { getConnInfo } from "hono/bun";
import { db } from "../db";
import { rateLimit } from "../db/schema";
import { RateLimitError } from "./errors";
import { logger } from "./logger";

export type RateLimit = { limit: number; windowMs: number };

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;

export const RATE_LIMITS = {
  auth: { limit: 120, windowMs: MINUTE },
  signIn: { limit: 20, windowMs: 15 * MINUTE },
  signUp: { limit: 10, windowMs: HOUR },
  invitePreview: { limit: 60, windowMs: MINUTE },
  inviteJoin: { limit: 20, windowMs: 15 * MINUTE },
  upload: { limit: 300, windowMs: HOUR },
} satisfies Record<string, RateLimit>;

const CLEANUP_PROBABILITY = 0.01;

const deleteExpired = () =>
  db
    .delete(rateLimit)
    .where(lt(rateLimit.resetAt, sql`now()`))
    .catch((error) => logger.error("Failed to delete expired rate limits", { error }));

export const consumeRateLimit = async (key: string, { limit, windowMs }: RateLimit) => {
  const isExpired = sql`${rateLimit.resetAt} <= now()`;
  const [bucket] = await db
    .insert(rateLimit)
    .values({
      key,
      count: 1,
      resetAt: sql`now() + ${windowMs}::integer * interval '1 millisecond'`,
    })
    .onConflictDoUpdate({
      target: rateLimit.key,
      set: {
        count: sql`case when ${isExpired} then 1 else ${rateLimit.count} + 1 end`,
        resetAt: sql`case when ${isExpired} then excluded.reset_at else ${rateLimit.resetAt} end`,
      },
    })
    .returning({
      count: rateLimit.count,
      retryAfter: sql<number>`greatest(ceil(extract(epoch from ${rateLimit.resetAt} - now())), 1)::integer`,
    });
  if (Math.random() < CLEANUP_PROBABILITY) {
    void deleteExpired();
  }
  if (bucket!.count > limit) {
    throw new RateLimitError(bucket!.retryAfter);
  }
};

const getConnectionIp = (c: Context) => {
  try {
    return getConnInfo(c).remote.address;
  } catch {
    return undefined;
  }
};

export const getClientIp = (c: Context) =>
  c.req.header("x-forwarded-for")?.split(",").at(-1)?.trim() || getConnectionIp(c) || "unknown";
