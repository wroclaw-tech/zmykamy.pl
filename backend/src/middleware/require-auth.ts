import { createMiddleware } from "hono/factory";
import type { AppEnv } from "../lib/app-env";
import { auth } from "../lib/auth";
import { ApiError } from "../lib/errors";

export const requireAuth = createMiddleware<AppEnv>(async (c, next) => {
  const authSession = await auth.api.getSession({ headers: c.req.raw.headers });
  if (!authSession) {
    throw new ApiError(401, "unauthorized", "Authentication required");
  }
  c.set("user", authSession.user);
  c.set("session", authSession.session);
  await next();
});
