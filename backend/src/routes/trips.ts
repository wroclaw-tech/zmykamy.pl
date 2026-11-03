import { and, eq } from "drizzle-orm";
import { Hono } from "hono";
import type { z } from "zod";
import { db } from "../db";
import { trip, tripInvite, tripMember } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { ApiError } from "../lib/errors";
import { generateInviteCode, toInviteSlug, toInviteUrl } from "../lib/invite";
import { logger } from "../lib/logger";
import { deleteFile, fileExists, getDownloadUrl, getUploadUrl } from "../lib/storage";
import { validate } from "../lib/validation";
import { requireAuth } from "../middleware/require-auth";
import {
  createTripSchema,
  tripIdParamSchema,
  tripMemberParamSchema,
  updateTripSchema,
} from "../schemas/trip";

const COVER_CONTENT_TYPE = "image/jpeg";

type Destination = z.infer<typeof createTripSchema>["destination"];
type TripRole = (typeof tripMember.$inferSelect)["role"];

const ROLE_ORDER: Record<TripRole, number> = { organizer: 0, participant: 1 };

export const findTrip = (id: string) =>
  db.query.trip.findFirst({
    where: eq(trip.id, id),
    with: { members: { with: { user: true } } },
  });

type TripWithMembers = NonNullable<Awaited<ReturnType<typeof findTrip>>>;

const getMemberBalance = () => 0;

const getInviteLabel = (record: { name: string; destinationName: string | null }) =>
  record.destinationName ?? record.name;

const toInviteResponse = (record: TripWithMembers, code: string) => ({
  code: toInviteSlug(getInviteLabel(record), code),
  url: toInviteUrl(getInviteLabel(record), code),
});

const getOrCreateInviteCode = async (tripId: string) => {
  await db.insert(tripInvite).values({ tripId, code: generateInviteCode() }).onConflictDoNothing();
  const invite = await db.query.tripInvite.findFirst({ where: eq(tripInvite.tripId, tripId) });
  return invite!.code;
};

const toDestinationColumns = (destination: Destination) => ({
  destinationName: destination?.name ?? null,
  destinationCountry: destination?.country ?? null,
  destinationLatitude: destination?.latitude ?? null,
  destinationLongitude: destination?.longitude ?? null,
});

export const toTripResponse = (record: TripWithMembers, userId: string) => {
  const members = record.members.toSorted(
    (a, b) =>
      ROLE_ORDER[a.role] - ROLE_ORDER[b.role] || a.joinedAt.getTime() - b.joinedAt.getTime(),
  );
  return {
    id: record.id,
    name: record.name,
    destination: record.destinationName
      ? {
          name: record.destinationName,
          country: record.destinationCountry,
          latitude: record.destinationLatitude,
          longitude: record.destinationLongitude,
        }
      : null,
    startDate: record.startDate,
    endDate: record.endDate,
    currency: record.currency,
    coverUrl: record.coverImageKey ? getDownloadUrl(record.coverImageKey) : null,
    myRole: members.find((member) => member.userId === userId)?.role,
    members: members.map((member) => ({
      userId: member.userId,
      name: member.user.name,
      image: member.user.image,
      role: member.role,
      balance: getMemberBalance(),
    })),
  };
};

const getMemberTrip = async (id: string, userId: string) => {
  const record = await findTrip(id);
  if (!record?.members.some((member) => member.userId === userId)) {
    throw new ApiError(404, "trip_not_found", "Trip not found");
  }
  return record;
};

const getOrganizerTrip = async (id: string, userId: string) => {
  const record = await getMemberTrip(id, userId);
  const role = record.members.find((member) => member.userId === userId)?.role;
  if (role !== "organizer") {
    throw new ApiError(403, "forbidden", "Only organizers can manage this trip");
  }
  return record;
};

const getCoverKeyPrefix = (tripId: string) => `trips/${tripId}/cover/`;

const assertUploadedCover = async (tripId: string, key: string) => {
  if (!key.startsWith(getCoverKeyPrefix(tripId)) || !(await fileExists(key))) {
    throw new ApiError(400, "invalid_cover_key", "Cover image was not uploaded for this trip");
  }
};

const deleteCover = async (key: string | null) => {
  if (!key) {
    return;
  }
  try {
    await deleteFile(key);
  } catch (error) {
    logger.warn("Failed to delete trip cover", { key, error });
  }
};

export const trips = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/", async (c) => {
    const userId = c.get("user").id;
    const memberships = await db.query.tripMember.findMany({
      where: eq(tripMember.userId, userId),
      with: { trip: { with: { members: { with: { user: true } } } } },
    });
    return c.json(memberships.map((membership) => toTripResponse(membership.trip, userId)));
  })
  .post("/", validate("json", createTripSchema), async (c) => {
    const userId = c.get("user").id;
    const { destination, ...fields } = c.req.valid("json");
    const tripId = await db.transaction(async (tx) => {
      const [created] = await tx
        .insert(trip)
        .values({ ...fields, ...toDestinationColumns(destination) })
        .returning({ id: trip.id });
      await tx.insert(tripMember).values({ tripId: created!.id, userId, role: "organizer" });
      return created!.id;
    });
    return c.json(toTripResponse((await findTrip(tripId))!, userId), 201);
  })
  .get("/:id", validate("param", tripIdParamSchema), async (c) => {
    const userId = c.get("user").id;
    const record = await getMemberTrip(c.req.valid("param").id, userId);
    return c.json(toTripResponse(record, userId));
  })
  .patch(
    "/:id",
    validate("param", tripIdParamSchema),
    validate("json", updateTripSchema),
    async (c) => {
      const userId = c.get("user").id;
      const { id } = c.req.valid("param");
      const current = await getOrganizerTrip(id, userId);
      const { destination, coverImageKey, ...fields } = c.req.valid("json");

      if ((fields.startDate ?? current.startDate) > (fields.endDate ?? current.endDate)) {
        throw new ApiError(400, "invalid_date_range", "endDate must not be before startDate");
      }
      if (coverImageKey) {
        await assertUploadedCover(id, coverImageKey);
      }

      await db
        .update(trip)
        .set({
          ...fields,
          ...(destination !== undefined ? toDestinationColumns(destination) : {}),
          ...(coverImageKey !== undefined ? { coverImageKey } : {}),
        })
        .where(eq(trip.id, id));

      if (coverImageKey !== undefined && coverImageKey !== current.coverImageKey) {
        await deleteCover(current.coverImageKey);
      }
      return c.json(toTripResponse((await findTrip(id))!, userId));
    },
  )
  .delete("/:id", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    const current = await getOrganizerTrip(id, c.get("user").id);
    await db.delete(trip).where(eq(trip.id, id));
    await deleteCover(current.coverImageKey);
    return c.body(null, 204);
  })
  .post("/:id/cover/upload-url", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    await getOrganizerTrip(id, c.get("user").id);
    const key = `${getCoverKeyPrefix(id)}${crypto.randomUUID()}.jpg`;
    return c.json({ uploadUrl: getUploadUrl(key, COVER_CONTENT_TYPE), key });
  })
  .get("/:id/invite", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    const record = await getMemberTrip(id, c.get("user").id);
    return c.json(toInviteResponse(record, await getOrCreateInviteCode(id)));
  })
  .post("/:id/invite/regenerate", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    const record = await getOrganizerTrip(id, c.get("user").id);
    const code = generateInviteCode();
    await db
      .insert(tripInvite)
      .values({ tripId: id, code })
      .onConflictDoUpdate({ target: tripInvite.tripId, set: { code, createdAt: new Date() } });
    return c.json(toInviteResponse(record, code));
  })
  .delete("/:id/members/me", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    const userId = c.get("user").id;
    const record = await getMemberTrip(id, userId);
    if (record.members.find((member) => member.userId === userId)?.role === "organizer") {
      throw new ApiError(409, "organizer_cannot_leave", "The organizer can only delete the trip");
    }
    await db
      .delete(tripMember)
      .where(and(eq(tripMember.tripId, id), eq(tripMember.userId, userId)));
    return c.body(null, 204);
  })
  .delete("/:id/members/:userId", validate("param", tripMemberParamSchema), async (c) => {
    const { id, userId } = c.req.valid("param");
    const record = await getOrganizerTrip(id, c.get("user").id);
    if (userId === c.get("user").id) {
      throw new ApiError(400, "cannot_remove_self", "The organizer cannot be removed");
    }
    if (!record.members.some((member) => member.userId === userId)) {
      throw new ApiError(404, "member_not_found", "Member not found");
    }
    await db
      .delete(tripMember)
      .where(and(eq(tripMember.tripId, id), eq(tripMember.userId, userId)));
    return c.body(null, 204);
  });
