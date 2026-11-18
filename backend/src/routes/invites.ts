import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db";
import { tripInvite, tripMember } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { ApiError } from "../lib/errors";
import { parseInviteCode } from "../lib/invite";
import { validate } from "../lib/validation";
import { rateLimit } from "../middleware/rate-limit";
import { requireAuth } from "../middleware/require-auth";
import { inviteSlugParamSchema } from "../schemas/trip";
import { findTrip, respondWithTrip } from "./trips";

export const findInvitedTrip = async (slug: string) => {
  const invite = await db.query.tripInvite.findFirst({
    where: eq(tripInvite.code, parseInviteCode(slug)),
  });
  const record = invite ? await findTrip(invite.tripId) : undefined;
  if (!record) {
    throw new ApiError(404, "invite_not_found", "Invite not found");
  }
  return record;
};

export const invites = new Hono<AppEnv>()
  .get(
    "/:slug",
    rateLimit("invitePreview"),
    validate("param", inviteSlugParamSchema),
    async (c) => {
      const record = await findInvitedTrip(c.req.valid("param").slug);
      const organizer = record.members.find((member) => member.role === "organizer");
      return c.json({
        tripId: record.id,
        name: record.name,
        destination: record.destinationName
          ? { name: record.destinationName, country: record.destinationCountry }
          : null,
        startDate: record.startDate,
        endDate: record.endDate,
        organizerName: organizer?.user.name ?? null,
        memberCount: record.members.length,
      });
    },
  )
  .post(
    "/:slug/join",
    requireAuth,
    rateLimit("inviteJoin", "user"),
    validate("param", inviteSlugParamSchema),
    async (c) => {
      const userId = c.get("user").id;
      const record = await findInvitedTrip(c.req.valid("param").slug);
      await db
        .insert(tripMember)
        .values({ tripId: record.id, userId, role: "participant" })
        .onConflictDoNothing();
      return c.json(await respondWithTrip(record.id, userId));
    },
  );
