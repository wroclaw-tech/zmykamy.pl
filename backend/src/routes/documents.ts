import { and, asc, desc, eq } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db";
import { planPoint, tripDocument, tripNote } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { ApiError } from "../lib/errors";
import { deleteFilesQuietly, fileExists, getDownloadUrl, getUploadUrl } from "../lib/storage";
import { validate } from "../lib/validation";
import { requireAuth } from "../middleware/require-auth";
import {
  createDocumentSchema,
  createNoteSchema,
  DOCUMENT_CONTENT_TYPES,
  documentParamSchema,
  documentUploadSchema,
  noteParamSchema,
  updateDocumentSchema,
  updateNoteSchema,
} from "../schemas/documents";
import { tripIdParamSchema } from "../schemas/trip";
import { getMemberTrip } from "./trips";

type MemberTrip = Awaited<ReturnType<typeof getMemberTrip>>;

type Category = (typeof tripDocument.$inferSelect)["category"];

type Author = { id: string; name: string } | null;

const DEFAULT_ICONS = {
  ticket: "confirmation_number",
  reservation: "bed",
  other: "info",
} as const satisfies Record<Category, string>;

const toAuthorResponse = (author: Author) =>
  author ? { userId: author.id, name: author.name } : null;

const getDocumentKeyPrefix = (tripId: string) => `trips/${tripId}/documents/`;

const findDocument = (id: string, tripId: string) =>
  db.query.tripDocument.findFirst({
    where: and(eq(tripDocument.id, id), eq(tripDocument.tripId, tripId)),
    with: { author: true },
  });

const findNote = (id: string, tripId: string) =>
  db.query.tripNote.findFirst({
    where: and(eq(tripNote.id, id), eq(tripNote.tripId, tripId)),
    with: { author: true },
  });

const toDocumentResponse = (record: typeof tripDocument.$inferSelect & { author: Author }) => ({
  id: record.id,
  title: record.title,
  category: record.category,
  icon: record.icon,
  kind: record.kind,
  url: record.url,
  fileUrl: record.key ? getDownloadUrl(record.key) : null,
  contentType: record.contentType,
  planPointId: record.planPointId,
  author: toAuthorResponse(record.author),
  createdAt: record.createdAt,
  updatedAt: record.updatedAt,
});

const toNoteResponse = (record: typeof tripNote.$inferSelect & { author: Author }) => ({
  id: record.id,
  title: record.title,
  text: record.text,
  pinned: record.pinned,
  author: toAuthorResponse(record.author),
  createdAt: record.createdAt,
  updatedAt: record.updatedAt,
});

const assertCanEdit = (record: MemberTrip, userId: string, createdBy: string | null) => {
  const role = record.members.find((member) => member.userId === userId)?.role;
  if (role !== "organizer" && createdBy !== userId) {
    throw new ApiError(403, "forbidden", "Only the author or an organizer can change this");
  }
};

const assertPlanPoint = async (tripId: string, planPointId: string | null | undefined) => {
  if (!planPointId) {
    return;
  }
  const point = await db.query.planPoint.findFirst({
    columns: { id: true },
    where: and(eq(planPoint.id, planPointId), eq(planPoint.tripId, tripId)),
  });
  if (!point) {
    throw new ApiError(400, "invalid_plan_point", "Plan point does not belong to this trip");
  }
};

const assertUploadedDocument = async (tripId: string, key: string) => {
  if (!key.startsWith(getDocumentKeyPrefix(tripId)) || !(await fileExists(key))) {
    throw new ApiError(400, "invalid_document_key", "Document was not uploaded for this trip");
  }
};

const getDocumentOrThrow = async (id: string, tripId: string) => {
  const current = await findDocument(id, tripId);
  if (!current) {
    throw new ApiError(404, "document_not_found", "Document not found");
  }
  return current;
};

const getNoteOrThrow = async (id: string, tripId: string) => {
  const current = await findNote(id, tripId);
  if (!current) {
    throw new ApiError(404, "note_not_found", "Note not found");
  }
  return current;
};

export const documents = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/:id/documents", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    await getMemberTrip(id, c.get("user").id);
    const records = await db.query.tripDocument.findMany({
      where: eq(tripDocument.tripId, id),
      with: { author: true },
      orderBy: [asc(tripDocument.createdAt)],
    });
    return c.json({ documents: records.map(toDocumentResponse) });
  })
  .post(
    "/:id/documents/upload-url",
    validate("param", tripIdParamSchema),
    validate("json", documentUploadSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      await getMemberTrip(id, c.get("user").id);
      const { contentType } = c.req.valid("json");
      const key = `${getDocumentKeyPrefix(id)}${crypto.randomUUID()}.${DOCUMENT_CONTENT_TYPES[contentType]}`;
      return c.json({ key, uploadUrl: getUploadUrl(key, contentType) });
    },
  )
  .post(
    "/:id/documents",
    validate("param", tripIdParamSchema),
    validate("json", createDocumentSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const userId = c.get("user").id;
      const body = c.req.valid("json");
      await getMemberTrip(id, userId);
      await assertPlanPoint(id, body.planPointId);
      if (body.kind === "file") {
        await assertUploadedDocument(id, body.key);
      }
      const [created] = await db
        .insert(tripDocument)
        .values({
          ...body,
          icon: body.icon ?? DEFAULT_ICONS[body.category],
          tripId: id,
          createdBy: userId,
        })
        .returning({ id: tripDocument.id });
      return c.json(toDocumentResponse((await findDocument(created!.id, id))!), 201);
    },
  )
  .patch(
    "/:id/documents/:documentId",
    validate("param", documentParamSchema),
    validate("json", updateDocumentSchema),
    async (c) => {
      const { id, documentId } = c.req.valid("param");
      const userId = c.get("user").id;
      const body = c.req.valid("json");
      const record = await getMemberTrip(id, userId);
      const current = await getDocumentOrThrow(documentId, id);
      assertCanEdit(record, userId, current.createdBy);
      await assertPlanPoint(id, body.planPointId);
      if (body.url && current.kind !== "link") {
        throw new ApiError(400, "not_a_link", "Only link documents have a url");
      }
      await db.update(tripDocument).set(body).where(eq(tripDocument.id, documentId));
      return c.json(toDocumentResponse((await findDocument(documentId, id))!));
    },
  )
  .delete("/:id/documents/:documentId", validate("param", documentParamSchema), async (c) => {
    const { id, documentId } = c.req.valid("param");
    const userId = c.get("user").id;
    const record = await getMemberTrip(id, userId);
    const current = await getDocumentOrThrow(documentId, id);
    assertCanEdit(record, userId, current.createdBy);
    await db.delete(tripDocument).where(eq(tripDocument.id, documentId));
    await deleteFilesQuietly([current.key]);
    return c.body(null, 204);
  })
  .get("/:id/notes", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    await getMemberTrip(id, c.get("user").id);
    const records = await db.query.tripNote.findMany({
      where: eq(tripNote.tripId, id),
      with: { author: true },
      orderBy: [desc(tripNote.pinned), desc(tripNote.updatedAt)],
    });
    return c.json({ notes: records.map(toNoteResponse) });
  })
  .post(
    "/:id/notes",
    validate("param", tripIdParamSchema),
    validate("json", createNoteSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const userId = c.get("user").id;
      await getMemberTrip(id, userId);
      const [created] = await db
        .insert(tripNote)
        .values({ ...c.req.valid("json"), tripId: id, createdBy: userId })
        .returning({ id: tripNote.id });
      return c.json(toNoteResponse((await findNote(created!.id, id))!), 201);
    },
  )
  .patch(
    "/:id/notes/:noteId",
    validate("param", noteParamSchema),
    validate("json", updateNoteSchema),
    async (c) => {
      const { id, noteId } = c.req.valid("param");
      const userId = c.get("user").id;
      const record = await getMemberTrip(id, userId);
      assertCanEdit(record, userId, (await getNoteOrThrow(noteId, id)).createdBy);
      await db.update(tripNote).set(c.req.valid("json")).where(eq(tripNote.id, noteId));
      return c.json(toNoteResponse((await findNote(noteId, id))!));
    },
  )
  .delete("/:id/notes/:noteId", validate("param", noteParamSchema), async (c) => {
    const { id, noteId } = c.req.valid("param");
    const userId = c.get("user").id;
    const record = await getMemberTrip(id, userId);
    assertCanEdit(record, userId, (await getNoteOrThrow(noteId, id)).createdBy);
    await db.delete(tripNote).where(eq(tripNote.id, noteId));
    return c.body(null, 204);
  });
