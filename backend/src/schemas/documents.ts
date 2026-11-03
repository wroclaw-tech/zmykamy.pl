import { z } from "zod";
import { DOCUMENT_CATEGORIES, PLAN_ICONS } from "../db/schema";

export const DOCUMENT_CONTENT_TYPES = {
  "application/pdf": "pdf",
  "image/jpeg": "jpg",
  "image/png": "png",
} as const;

const contentTypeSchema = z.enum(
  Object.keys(DOCUMENT_CONTENT_TYPES) as [keyof typeof DOCUMENT_CONTENT_TYPES],
);

const titleSchema = z.string().trim().min(1).max(120);

const linkSchema = z.url({ protocol: /^https?$/ }).max(2000);

const fields = {
  title: titleSchema,
  category: z.enum(DOCUMENT_CATEGORIES),
  icon: z.enum(PLAN_ICONS).optional(),
  planPointId: z.uuid().nullable().default(null),
};

export const documentParamSchema = z.object({ id: z.uuid(), documentId: z.uuid() });

export const noteParamSchema = z.object({ id: z.uuid(), noteId: z.uuid() });

export const documentUploadSchema = z.object({ contentType: contentTypeSchema });

export const createDocumentSchema = z.discriminatedUnion("kind", [
  z.object({
    ...fields,
    kind: z.literal("file"),
    key: z.string().min(1),
    contentType: contentTypeSchema,
  }),
  z.object({ ...fields, kind: z.literal("link"), url: linkSchema }),
]);

export const updateDocumentSchema = z
  .object({
    title: titleSchema,
    category: z.enum(DOCUMENT_CATEGORIES),
    icon: z.enum(PLAN_ICONS),
    planPointId: z.uuid().nullable(),
    url: linkSchema,
  })
  .partial()
  .refine((body) => Object.keys(body).length > 0, "At least one field is required");

const noteFields = {
  title: z.string().trim().min(1).max(80),
  text: z.string().trim().max(4000),
  pinned: z.boolean(),
};

export const createNoteSchema = z.object({
  ...noteFields,
  text: noteFields.text.default(""),
  pinned: noteFields.pinned.default(false),
});

export const updateNoteSchema = z
  .object(noteFields)
  .partial()
  .refine((body) => Object.keys(body).length > 0, "At least one field is required");
