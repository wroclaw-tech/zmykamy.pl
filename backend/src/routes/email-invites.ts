import { and, desc, eq, inArray, isNotNull, isNull, lte } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db";
import { tripEmailInvite, tripMember } from "../db/schema";
import type { AppEnv, AuthUser } from "../lib/app-env";
import { mailer } from "../lib/email";
import { ApiError, RateLimitError } from "../lib/errors";
import { renderInviteEmail } from "../lib/invite-email";
import { logger } from "../lib/logger";
import { RATE_LIMITS, consumeRateLimit } from "../lib/rate-limit";
import { validate } from "../lib/validation";
import { requireAuth } from "../middleware/require-auth";
import { emailInviteParamSchema, sendEmailInvitesSchema } from "../schemas/email-invite";
import { tripIdParamSchema } from "../schemas/trip";
import { getOrCreateInviteCode, getOrganizerTrip, toInviteResponse } from "./trips";

const RESEND_COOLDOWN_MS = 15 * 60 * 1000;

type EmailInvite = typeof tripEmailInvite.$inferSelect;
type InvitedTrip = Awaited<ReturnType<typeof getOrganizerTrip>>;

const toEmailInviteResponse = (invite: EmailInvite) => ({
  id: invite.id,
  email: invite.email,
  status: invite.joinedAt ? ("joined" as const) : ("sent" as const),
  sentAt: invite.sentAt,
  joinedAt: invite.joinedAt,
});

const getEmailInvite = async (tripId: string, inviteId: string) => {
  const invite = await db.query.tripEmailInvite.findFirst({
    where: and(eq(tripEmailInvite.id, inviteId), eq(tripEmailInvite.tripId, tripId)),
  });
  if (!invite) {
    throw new ApiError(404, "email_invite_not_found", "Invitation not found");
  }
  return invite;
};

const consumeSendLimits = (tripId: string, userId: string, count: number) =>
  Promise.all(
    Array.from({ length: count }, async () => {
      await consumeRateLimit(`emailInviteTrip:${tripId}`, RATE_LIMITS.emailInviteTrip);
      await consumeRateLimit(`emailInviteUser:${userId}`, RATE_LIMITS.emailInviteUser);
    }),
  );

const sendInviteEmails = async (record: InvitedTrip, inviter: AuthUser, emails: string[]) => {
  const { url } = toInviteResponse(record, await getOrCreateInviteCode(record.id));
  const content = renderInviteEmail({
    tripName: record.name,
    startDate: record.startDate,
    endDate: record.endDate,
    inviterName: inviter.name,
    url,
  });
  const results = await Promise.allSettled(emails.map((to) => mailer.send({ to, ...content })));
  results.forEach((result) => {
    if (result.status === "rejected") {
      logger.error("Failed to send an invitation e-mail", {
        error: result.reason,
        tripId: record.id,
      });
    }
  });
  return emails.filter((_, index) => results[index]!.status === "rejected");
};

const getMyPendingInvites = async (user: AuthUser) => {
  const memberships = await db.query.tripMember.findMany({
    columns: { tripId: true },
    where: eq(tripMember.userId, user.id),
  });
  const memberTripIds = new Set(memberships.map((membership) => membership.tripId));
  const invites = await db.query.tripEmailInvite.findMany({
    where: and(
      eq(tripEmailInvite.email, user.email.toLowerCase()),
      isNull(tripEmailInvite.joinedAt),
    ),
    with: { trip: true, inviter: { columns: { name: true } } },
    orderBy: desc(tripEmailInvite.sentAt),
  });
  return invites.filter((invite) => !memberTripIds.has(invite.tripId));
};

export const markEmailInviteJoined = (tripId: string, email: string) =>
  db
    .update(tripEmailInvite)
    .set({ joinedAt: new Date() })
    .where(
      and(
        eq(tripEmailInvite.tripId, tripId),
        eq(tripEmailInvite.email, email.toLowerCase()),
        isNull(tripEmailInvite.joinedAt),
      ),
    );

export const emailInvites = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/:id/email-invites", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    await getOrganizerTrip(id, c.get("user").id);
    const invites = await db.query.tripEmailInvite.findMany({
      where: eq(tripEmailInvite.tripId, id),
      orderBy: desc(tripEmailInvite.sentAt),
    });
    return c.json(invites.map(toEmailInviteResponse));
  })
  .post(
    "/:id/email-invites",
    validate("param", tripIdParamSchema),
    validate("json", sendEmailInvitesSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const user = c.get("user");
      const record = await getOrganizerTrip(id, user.id);
      const emails = [...new Set(c.req.valid("json").emails)];
      const memberEmails = new Set(record.members.map((member) => member.user.email.toLowerCase()));
      const alreadyMembers = emails.filter((email) => memberEmails.has(email));
      const candidates = emails.filter((email) => !memberEmails.has(email));
      const pending = candidates.length
        ? await db.query.tripEmailInvite.findMany({
            columns: { email: true },
            where: and(
              eq(tripEmailInvite.tripId, id),
              inArray(tripEmailInvite.email, candidates),
              isNull(tripEmailInvite.joinedAt),
            ),
          })
        : [];
      const pendingEmails = new Set(pending.map((invite) => invite.email));
      const toSend = candidates.filter((email) => !pendingEmails.has(email));
      await consumeSendLimits(id, user.id, toSend.length);
      const now = new Date();
      const created = toSend.length
        ? await db
            .insert(tripEmailInvite)
            .values(toSend.map((email) => ({ tripId: id, email, invitedBy: user.id, sentAt: now })))
            .onConflictDoUpdate({
              target: [tripEmailInvite.tripId, tripEmailInvite.email],
              set: { invitedBy: user.id, sentAt: now, joinedAt: null },
              setWhere: isNotNull(tripEmailInvite.joinedAt),
            })
            .returning()
        : [];
      const failed = await sendInviteEmails(
        record,
        user,
        created.map((invite) => invite.email),
      );
      if (failed.length) {
        await db
          .delete(tripEmailInvite)
          .where(and(eq(tripEmailInvite.tripId, id), inArray(tripEmailInvite.email, failed)));
      }
      const createdEmails = new Set(created.map((invite) => invite.email));
      return c.json(
        {
          invites: created
            .filter((invite) => !failed.includes(invite.email))
            .map(toEmailInviteResponse),
          alreadyMembers,
          alreadyInvited: candidates.filter((email) => !createdEmails.has(email)),
          failed,
        },
        201,
      );
    },
  )
  .post(
    "/:id/email-invites/:inviteId/resend",
    validate("param", emailInviteParamSchema),
    async (c) => {
      const { id, inviteId } = c.req.valid("param");
      const user = c.get("user");
      const record = await getOrganizerTrip(id, user.id);
      const invite = await getEmailInvite(id, inviteId);
      if (invite.joinedAt) {
        throw new ApiError(409, "email_invite_joined", "This person has already joined the trip");
      }
      const now = new Date();
      const [claimed] = await db
        .update(tripEmailInvite)
        .set({ sentAt: now, invitedBy: user.id })
        .where(
          and(
            eq(tripEmailInvite.id, invite.id),
            lte(tripEmailInvite.sentAt, new Date(now.getTime() - RESEND_COOLDOWN_MS)),
          ),
        )
        .returning();
      if (!claimed) {
        throw new RateLimitError(
          Math.max(
            Math.ceil((invite.sentAt.getTime() + RESEND_COOLDOWN_MS - now.getTime()) / 1000),
            1,
          ),
        );
      }
      try {
        await consumeSendLimits(id, user.id, 1);
        if ((await sendInviteEmails(record, user, [invite.email])).length) {
          throw new ApiError(502, "email_not_sent", "Could not send the invitation e-mail");
        }
      } catch (error) {
        await db
          .update(tripEmailInvite)
          .set({ sentAt: invite.sentAt, invitedBy: invite.invitedBy })
          .where(eq(tripEmailInvite.id, invite.id));
        throw error;
      }
      return c.json(toEmailInviteResponse(claimed));
    },
  )
  .delete("/:id/email-invites/:inviteId", validate("param", emailInviteParamSchema), async (c) => {
    const { id, inviteId } = c.req.valid("param");
    await getOrganizerTrip(id, c.get("user").id);
    await getEmailInvite(id, inviteId);
    await db.delete(tripEmailInvite).where(eq(tripEmailInvite.id, inviteId));
    return c.body(null, 204);
  });

export const myEmailInvites = new Hono<AppEnv>().use(requireAuth).get("/", async (c) => {
  const invites = await getMyPendingInvites(c.get("user"));
  return c.json(
    await Promise.all(
      invites.map(async (invite) => ({
        id: invite.id,
        code: toInviteResponse(invite.trip, await getOrCreateInviteCode(invite.tripId)).code,
        trip: {
          id: invite.trip.id,
          name: invite.trip.name,
          destination: invite.trip.destinationName
            ? { name: invite.trip.destinationName, country: invite.trip.destinationCountry }
            : null,
          startDate: invite.trip.startDate,
          endDate: invite.trip.endDate,
        },
        inviterName: invite.inviter?.name ?? null,
        sentAt: invite.sentAt,
      })),
    ),
  );
});
