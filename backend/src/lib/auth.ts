import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { bearer } from "better-auth/plugins";
import { db } from "../db";
import * as schema from "../db/schema";
import { THEME_PALETTES, termsVersionSchema, themePaletteSchema } from "./user-fields";

export const auth = betterAuth({
  basePath: "/auth",
  database: drizzleAdapter(db, { provider: "pg", schema }),
  emailAndPassword: {
    enabled: true,
  },
  user: {
    additionalFields: {
      themePalette: {
        type: [...THEME_PALETTES],
        required: false,
        validator: { input: themePaletteSchema },
      },
      termsVersion: {
        type: "string",
        required: false,
        validator: { input: termsVersionSchema },
      },
      termsAcceptedAt: {
        type: "date",
        required: false,
        input: false,
      },
    },
  },
  databaseHooks: {
    user: {
      create: {
        before: async (newUser) => ({
          data: {
            ...newUser,
            termsAcceptedAt: newUser.termsVersion ? new Date() : null,
          },
        }),
      },
    },
  },
  plugins: [bearer()],
});
