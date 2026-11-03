import { z } from "zod";
import { PLAN_ICONS } from "../db/schema";

const iconSchema = z.enum(PLAN_ICONS);

const optionalText = (max: number) => z.string().trim().max(max).nullable();

export const planPointParamSchema = z.object({ id: z.uuid(), pointId: z.uuid() });

export const tripInfoParamSchema = z.object({ id: z.uuid(), infoId: z.uuid() });

export const createPlanPointSchema = z.object({
  date: z.iso.date(),
  time: z.iso.time({ precision: -1 }),
  title: z.string().trim().min(1).max(120),
  description: optionalText(1000).default(null),
  place: optionalText(200).default(null),
  icon: iconSchema.default("location_on"),
});

export const updatePlanPointSchema = createPlanPointSchema
  .partial()
  .refine((body) => Object.keys(body).length > 0, "At least one field is required");

export const createTripInfoSchema = z.object({
  title: z.string().trim().min(1).max(60),
  text: z.string().trim().max(4000).default(""),
  icon: iconSchema.default("info"),
});

export const updateTripInfoSchema = createTripInfoSchema
  .partial()
  .refine((body) => Object.keys(body).length > 0, "At least one field is required");
