import { z } from "zod";

export const MIN_POLL_OPTIONS = 2;
export const MAX_POLL_OPTIONS = 10;

const optionSchema = z.object({
  name: z.string().trim().min(1).max(80),
  description: z.string().trim().min(1).max(120).nullable().default(null),
});

export const pollParamSchema = z.object({ id: z.uuid(), pollId: z.uuid() });

export const createPollSchema = z.object({
  question: z.string().trim().min(1).max(120),
  options: z.array(optionSchema).min(MIN_POLL_OPTIONS).max(MAX_POLL_OPTIONS),
  closesAt: z.iso
    .datetime({ offset: true })
    .transform((closesAt) => new Date(closesAt))
    .refine((closesAt) => closesAt > new Date(), "closesAt must be in the future")
    .nullable()
    .default(null),
});

export const voteSchema = z.object({ optionId: z.uuid() });

export const resolvePollSchema = z.object({
  optionId: z.uuid().optional(),
  planDate: z.iso.date().nullable().default(null),
});
