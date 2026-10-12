import { Hono } from "hono";
import type { AppEnv } from "../lib/app-env";
import { requireAuth } from "../middleware/require-auth";

export const profileRoutes = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/", (c) => c.json({ user: c.get("user") }));
