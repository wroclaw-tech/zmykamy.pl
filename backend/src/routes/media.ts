import { and, desc, eq } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db";
import { media } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { ApiError } from "../lib/errors";
import { deleteFilesQuietly, fileExists, getDownloadUrl, getUploadUrl } from "../lib/storage";
import { validate } from "../lib/validation";
import { rateLimit } from "../middleware/rate-limit";
import { requireAuth } from "../middleware/require-auth";
import {
  createMediaSchema,
  MEDIA_CONTENT_TYPES,
  mediaParamSchema,
  mediaUploadSchema,
} from "../schemas/media";
import { tripIdParamSchema } from "../schemas/trip";
import { getMemberTrip } from "./trips";

const THUMBNAIL_CONTENT_TYPE = "image/jpeg";

const getMediaKeyPrefix = (tripId: string) => `trips/${tripId}/media/`;

const findMedia = (id: string, tripId: string) =>
  db.query.media.findFirst({
    where: and(eq(media.id, id), eq(media.tripId, tripId)),
    with: { uploader: true },
  });

type MediaRecord = NonNullable<Awaited<ReturnType<typeof findMedia>>>;

const toMediaResponse = (record: MediaRecord) => ({
  id: record.id,
  kind: record.kind,
  url: getDownloadUrl(record.key),
  thumbnailUrl: getDownloadUrl(record.thumbnailKey),
  contentType: record.contentType,
  width: record.width,
  height: record.height,
  durationSeconds: record.durationSeconds,
  takenAt: record.takenAt,
  uploadedBy: record.uploader ? { userId: record.uploader.id, name: record.uploader.name } : null,
});

const assertUploaded = async (tripId: string, keys: string[]) => {
  const prefix = getMediaKeyPrefix(tripId);
  const uploaded = await Promise.all(
    keys.map(async (key) => key.startsWith(prefix) && (await fileExists(key))),
  );
  if (!uploaded.every(Boolean)) {
    throw new ApiError(400, "invalid_media_key", "Media was not uploaded for this trip");
  }
};

export const gallery = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/:id/media", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    await getMemberTrip(id, c.get("user").id);
    const records = await db.query.media.findMany({
      where: eq(media.tripId, id),
      with: { uploader: true },
      orderBy: [desc(media.takenAt), desc(media.createdAt)],
    });
    return c.json({ media: records.map(toMediaResponse) });
  })
  .post(
    "/:id/media/upload-url",
    rateLimit("upload", "user"),
    validate("param", tripIdParamSchema),
    validate("json", mediaUploadSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      await getMemberTrip(id, c.get("user").id);
      const { contentType } = c.req.valid("json");
      const name = `${getMediaKeyPrefix(id)}${crypto.randomUUID()}`;
      const key = `${name}.${MEDIA_CONTENT_TYPES[contentType]}`;
      const thumbnailKey = `${name}-thumb.jpg`;
      return c.json({
        key,
        uploadUrl: getUploadUrl(key, contentType),
        thumbnailKey,
        thumbnailUploadUrl: getUploadUrl(thumbnailKey, THUMBNAIL_CONTENT_TYPE),
      });
    },
  )
  .post(
    "/:id/media",
    validate("param", tripIdParamSchema),
    validate("json", createMediaSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const userId = c.get("user").id;
      const { takenAt, ...body } = c.req.valid("json");
      await getMemberTrip(id, userId);
      await assertUploaded(id, [body.key, body.thumbnailKey]);
      const [created] = await db
        .insert(media)
        .values({ ...body, takenAt: new Date(takenAt), tripId: id, uploadedBy: userId })
        .returning({ id: media.id });
      return c.json(toMediaResponse((await findMedia(created!.id, id))!), 201);
    },
  )
  .delete("/:id/media/:mediaId", validate("param", mediaParamSchema), async (c) => {
    const { id, mediaId } = c.req.valid("param");
    const userId = c.get("user").id;
    const record = await getMemberTrip(id, userId);
    const current = await findMedia(mediaId, id);
    if (!current) {
      throw new ApiError(404, "media_not_found", "Media not found");
    }
    const role = record.members.find((member) => member.userId === userId)?.role;
    if (role !== "organizer" && current.uploadedBy !== userId) {
      throw new ApiError(403, "forbidden", "Only the uploader or an organizer can delete this");
    }
    await db.delete(media).where(eq(media.id, mediaId));
    await deleteFilesQuietly([current.key, current.thumbnailKey]);
    return c.body(null, 204);
  });
