import { S3Client } from "bun";
import { env } from "./env";

const UPLOAD_URL_TTL_SECONDS = 5 * 60;
const DOWNLOAD_URL_TTL_SECONDS = 60 * 60;

const client = new S3Client({
  endpoint: env.S3_ENDPOINT,
  region: env.S3_REGION,
  bucket: env.S3_BUCKET,
  accessKeyId: env.S3_ACCESS_KEY_ID,
  secretAccessKey: env.S3_SECRET_ACCESS_KEY,
});

export const getUploadUrl = (key: string, contentType: string) =>
  client.presign(key, { method: "PUT", expiresIn: UPLOAD_URL_TTL_SECONDS, type: contentType });

export const getDownloadUrl = (key: string) =>
  client.presign(key, { expiresIn: DOWNLOAD_URL_TTL_SECONDS });

export const fileExists = (key: string) => client.exists(key);

export const deleteFile = (key: string) => client.delete(key);
