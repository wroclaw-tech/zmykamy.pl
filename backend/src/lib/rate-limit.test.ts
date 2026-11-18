import { beforeAll, beforeEach, describe, expect, test } from "bun:test";
import { eq, sql } from "drizzle-orm";
import { db } from "../db";
import { rateLimit, trip, user } from "../db/schema";
import app from "../index";
import { createTrip, createUser, randomIp, request } from "../routes/test-helpers";
import { RateLimitError } from "./errors";
import { RATE_LIMITS, consumeRateLimit } from "./rate-limit";

beforeAll(() => {
  if (!process.env.DATABASE_URL?.endsWith("_test")) {
    throw new Error("Tests must run against the test database, run `bun run test`");
  }
});

beforeEach(async () => {
  await db.delete(trip);
  await db.delete(user);
});

const randomKey = () => `test:${crypto.randomUUID()}`;

const repeat = (times: number, send: () => Response | Promise<Response>) =>
  Promise.all(Array.from({ length: times }, send));

const expectRateLimited = async (response: Response, windowMs: number) => {
  expect(response.status).toBe(429);
  expect(await response.json()).toEqual({
    error: { code: "rate_limited", message: expect.any(String) },
  });
  const retryAfter = Number(response.headers.get("Retry-After"));
  expect(retryAfter).toBeGreaterThan(0);
  expect(retryAfter).toBeLessThanOrEqual(windowMs / 1000);
};

describe("consumeRateLimit", () => {
  const limit = { limit: 3, windowMs: 60_000 };

  test("allows requests up to the limit", async () => {
    const key = randomKey();
    for (let i = 0; i < limit.limit; i++) {
      await consumeRateLimit(key, limit);
    }

    const error = await consumeRateLimit(key, limit).catch((error: unknown) => error);
    expect(error).toBeInstanceOf(RateLimitError);
    expect((error as RateLimitError).retryAfter).toBeLessThanOrEqual(60);
  });

  test("counts concurrent requests exactly", async () => {
    const key = randomKey();

    const results = await Promise.allSettled(
      Array.from({ length: 10 }, () => consumeRateLimit(key, limit)),
    );

    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(limit.limit);
  });

  test("keeps keys separate", async () => {
    const key = randomKey();
    for (let i = 0; i < limit.limit; i++) {
      await consumeRateLimit(key, limit);
    }

    await expect(consumeRateLimit(randomKey(), limit)).resolves.toBeUndefined();
  });

  test("starts a new window once the old one expires", async () => {
    const key = randomKey();
    for (let i = 0; i < limit.limit; i++) {
      await consumeRateLimit(key, limit);
    }
    await db
      .update(rateLimit)
      .set({ resetAt: sql`now() - interval '1 second'` })
      .where(eq(rateLimit.key, key));

    await consumeRateLimit(key, limit);
    const [bucket] = await db.select().from(rateLimit).where(eq(rateLimit.key, key));
    expect(bucket!.count).toBe(1);
  });
});

describe("auth limits", () => {
  const authRequest = (path: string, ip: string) =>
    app.request(path, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Forwarded-For": ip },
      body: "{}",
    });

  test.each([
    ["/auth/sign-in/email", RATE_LIMITS.signIn],
    ["/auth/sign-up/email", RATE_LIMITS.signUp],
  ])("limits %s per client ip", async (path, { limit, windowMs }) => {
    const ip = randomIp();
    const responses = await repeat(limit, () => authRequest(path, `${randomIp()}, ${ip}`));
    expect(responses.every((response) => response.status !== 429)).toBe(true);

    await expectRateLimited(await authRequest(path, ip), windowMs);
    expect((await authRequest(path, randomIp())).status).not.toBe(429);
  });

  test("limits every other auth endpoint per client ip", async () => {
    const ip = randomIp();
    const { limit, windowMs } = RATE_LIMITS.auth;

    const responses = await repeat(limit, () => authRequest("/auth/change-password", ip));
    expect(responses.every((response) => response.status !== 429)).toBe(true);

    await expectRateLimited(await authRequest("/auth/change-password", ip), windowMs);
    expect((await authRequest("/auth/change-password", randomIp())).status).not.toBe(429);
  });
});

describe("invite limits", () => {
  test("limits the public preview per client ip", async () => {
    const ip = randomIp();
    const preview = (from: string) =>
      app.request("/invites/LIZ-AAAAAAAA", { headers: { "X-Forwarded-For": from } });
    const { limit, windowMs } = RATE_LIMITS.invitePreview;

    const responses = await repeat(limit, () => preview(ip));
    expect(responses.every((response) => response.status === 404)).toBe(true);

    await expectRateLimited(await preview(ip), windowMs);
    expect((await preview(randomIp())).status).toBe(404);
  });

  test("limits joining per user", async () => {
    const kuba = await createUser("Kuba");
    const ola = await createUser("Ola");
    const join = (as = kuba) => request("/invites/LIZ-AAAAAAAA/join", as, { method: "POST" });
    const { limit, windowMs } = RATE_LIMITS.inviteJoin;

    const responses = await repeat(limit, join);
    expect(responses.every((response) => response.status === 404)).toBe(true);

    await expectRateLimited(await join(), windowMs);
    expect((await join(ola)).status).toBe(404);
  });
});

describe("upload limits", () => {
  test("share one budget per user across uploads", async () => {
    const kuba = await createUser("Kuba");
    const ola = await createUser("Ola");
    const { id } = await createTrip(kuba);
    const { limit, windowMs } = RATE_LIMITS.upload;

    const responses = await repeat(limit, () =>
      request(`/trips/${id}/media/upload-url`, kuba, {
        method: "POST",
        body: { kind: "photo", contentType: "image/jpeg" },
      }),
    );
    expect(responses.every((response) => response.status === 200)).toBe(true);

    await expectRateLimited(
      await request(`/trips/${id}/documents/upload-url`, kuba, {
        method: "POST",
        body: { contentType: "application/pdf" },
      }),
      windowMs,
    );
    await expectRateLimited(
      await request(`/trips/${id}/cover/upload-url`, kuba, { method: "POST" }),
      windowMs,
    );
    expect((await request(`/trips/${id}/cover/upload-url`, ola, { method: "POST" })).status).toBe(
      404,
    );
  });
});
