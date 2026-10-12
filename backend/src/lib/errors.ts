import type { ErrorHandler, NotFoundHandler } from "hono";
import { HTTPException } from "hono/http-exception";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import { logger } from "./logger";

export class ApiError extends HTTPException {
  readonly code: string;

  constructor(status: ContentfulStatusCode, code: string, message: string) {
    super(status, { message });
    this.code = code;
  }
}

export const handleError: ErrorHandler = (error, c) => {
  if (error instanceof ApiError) {
    return c.json({ error: { code: error.code, message: error.message } }, error.status);
  }
  if (error instanceof HTTPException) {
    return c.json({ error: { code: "http_error", message: error.message } }, error.status);
  }
  logger.error("Unhandled error", { error, method: c.req.method, path: c.req.path });
  return c.json({ error: { code: "internal_error", message: "Internal server error" } }, 500);
};

export const handleNotFound: NotFoundHandler = (c) =>
  c.json({ error: { code: "not_found", message: "Route not found" } }, 404);
