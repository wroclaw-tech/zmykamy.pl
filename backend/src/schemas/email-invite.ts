import { z } from "zod";

export const MAX_EMAILS_PER_REQUEST = 10;

export const sendEmailInvitesSchema = z.object({
  emails: z
    .array(z.string().trim().toLowerCase().max(254).pipe(z.email()))
    .min(1)
    .max(MAX_EMAILS_PER_REQUEST),
});

export const emailInviteParamSchema = z.object({ id: z.uuid(), inviteId: z.uuid() });
