import { z } from "zod";
import { MEDIA_KINDS } from "../db/schema";

export const MEDIA_CONTENT_TYPES = {
  "image/jpeg": "jpg",
  "video/mp4": "mp4",
  "video/quicktime": "mov",
} as const;

const contentTypeSchema = z.enum(
  Object.keys(MEDIA_CONTENT_TYPES) as [keyof typeof MEDIA_CONTENT_TYPES],
);

const isMatchingKind = (body: { kind: string; contentType: string }) =>
  body.contentType.startsWith(body.kind === "photo" ? "image/" : "video/");

const kindIssue = { message: "contentType does not match kind", path: ["contentType"] };

export const mediaParamSchema = z.object({ id: z.uuid(), mediaId: z.uuid() });

export const mediaUploadSchema = z
  .object({ kind: z.enum(MEDIA_KINDS), contentType: contentTypeSchema })
  .refine(isMatchingKind, kindIssue);

export const createMediaSchema = z
  .object({
    kind: z.enum(MEDIA_KINDS),
    contentType: contentTypeSchema,
    key: z.string().min(1),
    thumbnailKey: z.string().min(1),
    width: z.int().positive().max(20_000),
    height: z.int().positive().max(20_000),
    durationSeconds: z
      .number()
      .nonnegative()
      .max(24 * 60 * 60)
      .nullable()
      .default(null),
    takenAt: z.iso.datetime({ offset: true }),
  })
  .refine(isMatchingKind, kindIssue);
