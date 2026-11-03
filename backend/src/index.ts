import { Hono } from "hono";
import { logger as requestLogger } from "hono/logger";
import type { AppEnv } from "./lib/app-env";
import { auth } from "./lib/auth";
import { handleError, handleNotFound } from "./lib/errors";
import { logger } from "./lib/logger";
import { invites } from "./routes/invites";
import { trips } from "./routes/trips";
import { universalLinks } from "./routes/universal-links";

const app = new Hono<AppEnv>();

app.use(requestLogger((message) => logger.info(message)));
app.onError(handleError);
app.notFound(handleNotFound);

app.get("/", (c) => c.text("ok"));
app.on(["GET", "POST"], "/auth/*", (c) => auth.handler(c.req.raw));
app.route("/trips", trips);
app.route("/invites", invites);
app.route("/", universalLinks);

export default app;
