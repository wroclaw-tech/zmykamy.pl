import { Hono } from "hono";
import { logger as requestLogger } from "hono/logger";
import type { AppEnv } from "./lib/app-env";
import { auth } from "./lib/auth";
import { handleError, handleNotFound } from "./lib/errors";
import { logger } from "./lib/logger";
import { profileRoutes } from "./routes/profile";

const app = new Hono<AppEnv>();

app.use(requestLogger((message) => logger.info(message)));
app.onError(handleError);
app.notFound(handleNotFound);

app.get("/", (c) => c.text("ok"));
app.on(["GET", "POST"], "/auth/*", (c) => auth.handler(c.req.raw));
app.route("/profile", profileRoutes);

export default app;
