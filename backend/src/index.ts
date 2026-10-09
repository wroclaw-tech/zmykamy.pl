import { Hono } from "hono";
import { auth } from "./lib/auth";

const app = new Hono();

app.get("/", (c) => c.text("ok"));
app.on(["GET", "POST"], "/auth/*", (c) => auth.handler(c.req.raw));

export default app;
