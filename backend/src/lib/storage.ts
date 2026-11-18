import { S3Client } from "bun";
import { timingSafeEqual } from "node:crypto";
import { logger } from "./logger";

const UPLOAD_URL_TTL_SECONDS = 5 * 60;
const DOWNLOAD_URL_TTL_SECONDS = 60 * 60;
export const FILES_PATH = "/files/";

const client = new S3Client({
  endpoint: process.env.S3_ENDPOINT,
  region: process.env.S3_REGION,
  bucket: process.env.S3_BUCKET,
  accessKeyId: process.env.S3_ACCESS_KEY_ID,
  secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
});

type FileMethod = "GET" | "PUT";

const sign = (method: FileMethod, key: string, expires: string, contentType: string) =>
  new Bun.CryptoHasher("sha256", process.env.BETTER_AUTH_SECRET!)
    .update(`files\n${method}\n${key}\n${expires}\n${contentType}`)
    .digest("base64url");

// The bucket isn't reachable from outside, so clients get signed URLs to the API's file proxy
const getSignedUrl = (method: FileMethod, key: string, ttlSeconds: number, contentType = "") => {
  const expires = String(Math.floor(Date.now() / 1000) + ttlSeconds);
  const path = key.split("/").map(encodeURIComponent).join("/");
  const url = new URL(`${FILES_PATH}${path}`, process.env.BETTER_AUTH_URL);
  url.searchParams.set("expires", expires);
  if (contentType) {
    url.searchParams.set("type", contentType);
  }
  url.searchParams.set("signature", sign(method, key, expires, contentType));
  return url.toString();
};

export const getUploadUrl = (key: string, contentType: string) =>
  getSignedUrl("PUT", key, UPLOAD_URL_TTL_SECONDS, contentType);

export const getDownloadUrl = (key: string) => getSignedUrl("GET", key, DOWNLOAD_URL_TTL_SECONDS);

export type SignatureCheck = "valid" | "invalid" | "expired";

export const checkSignature = (
  method: FileMethod,
  key: string,
  query: { expires?: string; type?: string; signature?: string },
): SignatureCheck => {
  if (!query.expires || !query.signature) {
    return "invalid";
  }
  const expected = Buffer.from(sign(method, key, query.expires, query.type ?? ""));
  const given = Buffer.from(query.signature);
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) {
    return "invalid";
  }
  return Number(query.expires) * 1000 < Date.now() ? "expired" : "valid";
};

export const getFile = (key: string) => client.file(key);

export const writeFile = (key: string, body: Request, contentType: string) =>
  client.write(key, body, { type: contentType });

export const fileExists = (key: string) => client.exists(key);

export const deleteFile = (key: string) => client.delete(key);

export const deleteFilesQuietly = async (keys: (string | null)[]) => {
  await Promise.all(
    keys
      .filter((key): key is string => Boolean(key))
      .map(async (key) => {
        try {
          await deleteFile(key);
        } catch (error) {
          logger.warn("Failed to delete file", { key, error });
        }
      }),
  );
};
