import { Hono } from "hono";
import { logger as requestLogger } from "hono/logger";
import type { AppEnv } from "./lib/app-env";
import { auth } from "./lib/auth";
import { handleError, handleNotFound } from "./lib/errors";
import { logger } from "./lib/logger";
import { rateLimit } from "./middleware/rate-limit";
import { documents } from "./routes/documents";
import { emailInvites, myEmailInvites } from "./routes/email-invites";
import { expenses } from "./routes/expenses";
import { invites } from "./routes/invites";
import { gallery } from "./routes/media";
import { packing } from "./routes/packing";
import { plan } from "./routes/plan";
import { polls } from "./routes/polls";
import { tasks } from "./routes/tasks";
import { trips } from "./routes/trips";
import { universalLinks } from "./routes/universal-links";

const app = new Hono<AppEnv>();

app.use(requestLogger((message) => logger.info(message)));
app.onError(handleError);
app.notFound(handleNotFound);

app.get("/", (c) => c.text("ok"));
app.use("/auth/*", rateLimit("auth"));
app.use("/auth/sign-in/*", rateLimit("signIn"));
app.use("/auth/sign-up/*", rateLimit("signUp"));
app.on(["GET", "POST"], "/auth/*", (c) => auth.handler(c.req.raw));
app.route("/trips", trips);
app.route("/trips", plan);
app.route("/trips", expenses);
app.route("/trips", gallery);
app.route("/trips", documents);
app.route("/trips", packing);
app.route("/trips", tasks);
app.route("/trips", polls);
app.route("/trips", emailInvites);
app.route("/invites", invites);
app.route("/email-invites", myEmailInvites);
app.route("/", universalLinks);

export default app;
