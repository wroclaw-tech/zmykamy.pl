import { z } from "zod";
import { currencySchema } from "./user";

const isoDateSchema = z.iso.date();

const destinationSchema = z.object({
  name: z.string().trim().min(1).max(120),
  country: z.string().trim().min(1).max(120).nullable(),
  latitude: z.number().min(-90).max(90).nullable(),
  longitude: z.number().min(-180).max(180).nullable(),
});

const hasValidDateRange = ({ startDate, endDate }: { startDate?: string; endDate?: string }) =>
  !startDate || !endDate || startDate <= endDate;

const dateRangeIssue = { message: "endDate must not be before startDate", path: ["endDate"] };

export const tripIdParamSchema = z.object({ id: z.uuid() });

export const createTripSchema = z
  .object({
    name: z.string().trim().min(1).max(60),
    destination: destinationSchema.nullable().default(null),
    startDate: isoDateSchema,
    endDate: isoDateSchema,
    currency: currencySchema,
  })
  .refine(hasValidDateRange, dateRangeIssue);

export const updateTripSchema = z
  .object({
    name: z.string().trim().min(1).max(60),
    destination: destinationSchema.nullable(),
    startDate: isoDateSchema,
    endDate: isoDateSchema,
    currency: currencySchema,
    coverImageKey: z.string().min(1).nullable(),
  })
  .partial()
  .refine((body) => Object.keys(body).length > 0, "At least one field is required")
  .refine(hasValidDateRange, dateRangeIssue);
