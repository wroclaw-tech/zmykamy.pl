import { z } from "zod";
import { PLAN_ICONS } from "../db/schema";

const iconSchema = z.enum(PLAN_ICONS);

const optionalText = (max: number) => z.string().trim().max(max).nullable();

export const planPointParamSchema = z.object({ id: z.uuid(), pointId: z.uuid() });

export const tripInfoParamSchema = z.object({ id: z.uuid(), infoId: z.uuid() });

const planPointFields = {
  date: z.iso.date(),
  time: z.iso.time({ precision: -1 }),
  title: z.string().trim().min(1).max(120),
  description: optionalText(1000),
  place: optionalText(200),
  latitude: z.number().min(-90).max(90).nullable(),
  longitude: z.number().min(-180).max(180).nullable(),
  icon: iconSchema,
};

const hasCoordinatePair = ({
  latitude,
  longitude,
}: {
  latitude?: number | null;
  longitude?: number | null;
}) =>
  (latitude === undefined) === (longitude === undefined) &&
  (latitude === null) === (longitude === null);

const coordinatePairIssue = {
  message: "latitude and longitude must be set together",
  path: ["longitude"],
};

export const createPlanPointSchema = z
  .object({
    ...planPointFields,
    description: planPointFields.description.default(null),
    place: planPointFields.place.default(null),
    latitude: planPointFields.latitude.default(null),
    longitude: planPointFields.longitude.default(null),
    icon: planPointFields.icon.default("location_on"),
  })
  .refine(hasCoordinatePair, coordinatePairIssue);

export const updatePlanPointSchema = z
  .object(planPointFields)
  .partial()
  .refine((body) => Object.keys(body).length > 0, "At least one field is required")
  .refine(hasCoordinatePair, coordinatePairIssue);

const tripInfoFields = {
  title: z.string().trim().min(1).max(60),
  text: z.string().trim().max(4000),
  icon: iconSchema,
};

export const createTripInfoSchema = z.object({
  ...tripInfoFields,
  text: tripInfoFields.text.default(""),
  icon: tripInfoFields.icon.default("info"),
});

export const updateTripInfoSchema = z
  .object(tripInfoFields)
  .partial()
  .refine((body) => Object.keys(body).length > 0, "At least one field is required");
