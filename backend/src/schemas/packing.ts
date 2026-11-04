import { z } from "zod";

export const PACKING_SCOPES = ["personal", "shared"] as const;

const nameSchema = z.string().trim().min(1).max(80);
const assigneeIdSchema = z.string().min(1).nullable();

export const packingItemParamSchema = z.object({ id: z.uuid(), itemId: z.uuid() });

export const createPackingItemSchema = z
  .object({
    scope: z.enum(PACKING_SCOPES),
    name: nameSchema,
    assigneeId: assigneeIdSchema.default(null),
  })
  .refine(({ scope, assigneeId }) => scope === "shared" || assigneeId === null, {
    message: "Personal items cannot be assigned",
    path: ["assigneeId"],
  });

export const updatePackingItemSchema = z
  .object({
    name: nameSchema,
    assigneeId: assigneeIdSchema,
    isPacked: z.boolean(),
  })
  .partial()
  .refine((body) => Object.keys(body).length > 0, "At least one field is required");
