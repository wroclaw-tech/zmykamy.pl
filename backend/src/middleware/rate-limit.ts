import { createMiddleware } from "hono/factory";
import type { AppEnv } from "../lib/app-env";
import { RATE_LIMITS, consumeRateLimit, getClientIp } from "../lib/rate-limit";

export const rateLimit = (name: keyof typeof RATE_LIMITS, by: "ip" | "user" = "ip") =>
  createMiddleware<AppEnv>(async (c, next) => {
    const id = by === "user" ? c.get("user").id : getClientIp(c);
    await consumeRateLimit(`${name}:${id}`, RATE_LIMITS[name]);
    await next();
  });
