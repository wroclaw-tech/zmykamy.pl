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

export class RateLimitError extends ApiError {
  readonly retryAfter: number;

  constructor(retryAfter: number) {
    super(429, "rate_limited", "Too many requests, try again later");
    this.retryAfter = retryAfter;
  }
}

export const handleError: ErrorHandler = (error, c) => {
  if (error instanceof RateLimitError) {
    c.header("Retry-After", String(error.retryAfter));
  }
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
