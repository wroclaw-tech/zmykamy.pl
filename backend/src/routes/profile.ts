import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import { db } from "../db";
import { user } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { ApiError } from "../lib/errors";
import { termsVersionSchema, themePaletteSchema } from "../lib/user-fields";
import { validate } from "../lib/validation";
import { requireAuth } from "../middleware/require-auth";

const updateProfileSchema = z
  .object({
    name: z.string().trim().min(1).max(60),
    themePalette: themePaletteSchema.nullable(),
    termsVersion: termsVersionSchema,
  })
  .partial()
  .refine((fields) => Object.keys(fields).length > 0, "At least one field is required");

export const profileRoutes = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/", (c) => c.json({ user: c.get("user") }))
  .patch("/", validate("json", updateProfileSchema), async (c) => {
    const fields = c.req.valid("json");
    const [updatedUser] = await db
      .update(user)
      .set({ ...fields, ...(fields.termsVersion ? { termsAcceptedAt: new Date() } : {}) })
      .where(eq(user.id, c.get("user").id))
      .returning();
    if (!updatedUser) {
      throw new ApiError(404, "user_not_found", "User not found");
    }
    return c.json({ user: updatedUser });
  });
