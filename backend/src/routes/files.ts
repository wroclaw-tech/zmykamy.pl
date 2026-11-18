import { type Context, Hono } from "hono";
import type { AppEnv } from "../lib/app-env";
import { ApiError } from "../lib/errors";
import { checkSignature, FILES_PATH, getFile, writeFile } from "../lib/storage";

const RANGE_PATTERN = /^bytes=(\d*)-(\d*)$/;

const getKey = (c: Context<AppEnv>) => {
  let key = "";
  try {
    key = c.req.path.slice(FILES_PATH.length).split("/").map(decodeURIComponent).join("/");
  } catch {}
  if (!key) {
    throw new ApiError(404, "file_not_found", "File not found");
  }
  return key;
};

const assertSigned = (c: Context<AppEnv>, method: "GET" | "PUT", key: string) => {
  const check = checkSignature(method, key, c.req.query());
  if (check === "expired") {
    throw new ApiError(403, "url_expired", "The file URL has expired");
  }
  if (check === "invalid") {
    throw new ApiError(403, "invalid_signature", "The file URL is not valid");
  }
};

// Returns the inclusive byte range to send, or null for the whole file
const parseRange = (header: string | undefined, size: number) => {
  const match = header?.match(RANGE_PATTERN);
  if (!match || (!match[1] && !match[2])) {
    return null;
  }
  const [start, end] = match[1]
    ? [Number(match[1]), match[2] ? Math.min(Number(match[2]), size - 1) : size - 1]
    : [Math.max(size - Number(match[2]), 0), size - 1];
  if (start > end || start >= size) {
    throw new ApiError(416, "range_not_satisfiable", "The requested range is not satisfiable");
  }
  return { start, end };
};

export const files = new Hono<AppEnv>()
  .put("/*", async (c) => {
    const key = getKey(c);
    const contentType = c.req.header("Content-Type") ?? "";
    if (c.req.query("type") !== contentType) {
      throw new ApiError(403, "invalid_signature", "The file URL is not valid");
    }
    assertSigned(c, "PUT", key);
    await writeFile(key, c.req.raw, contentType);
    return c.body(null, 200);
  })
  .get("/*", async (c) => {
    const key = getKey(c);
    assertSigned(c, "GET", key);
    const file = getFile(key);
    const stat = await file.stat().catch(() => {
      throw new ApiError(404, "file_not_found", "File not found");
    });
    c.header("Content-Type", stat.type || "application/octet-stream");
    c.header("Accept-Ranges", "bytes");
    c.header("ETag", stat.etag);
    c.header("Cache-Control", "private, max-age=3600");

    let range: ReturnType<typeof parseRange>;
    try {
      range = parseRange(c.req.header("Range"), stat.size);
    } catch (error) {
      c.header("Content-Range", `bytes */${stat.size}`);
      throw error;
    }
    if (!range) {
      c.header("Content-Length", String(stat.size));
      return stat.size > 0 ? c.body(file.stream(), 200) : c.body(null, 200);
    }
    c.header("Content-Range", `bytes ${range.start}-${range.end}/${stat.size}`);
    c.header("Content-Length", String(range.end - range.start + 1));
    return c.body(file.slice(range.start, range.end + 1).stream(), 206);
  });
