import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { APIError } from "better-auth/api";
import { bearer } from "better-auth/plugins";
import { db } from "../db";
import * as schema from "../db/schema";
import {
  THEME_PALETTES,
  termsVersionSchema,
  themePaletteSchema,
  userNameSchema,
} from "../schemas/user";

const getValidatedUserName = (name: unknown) => {
  const result = userNameSchema.safeParse(name);
  if (!result.success) {
    throw new APIError("BAD_REQUEST", {
      code: "VALIDATION_ERROR",
      message: result.error.issues[0]?.message ?? "Invalid name",
    });
  }
  return result.data;
};

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
        validator: { input: themePaletteSchema.nullable() },
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
            name: getValidatedUserName(newUser.name),
            termsAcceptedAt: newUser.termsVersion ? new Date() : null,
          },
        }),
      },
      update: {
        before: async (userUpdate, context) => {
          const currentTermsVersion = context?.context.session?.user.termsVersion;
          const isNewTermsVersion =
            Boolean(userUpdate.termsVersion) && userUpdate.termsVersion !== currentTermsVersion;
          return {
            data: {
              ...(userUpdate.name !== undefined
                ? { name: getValidatedUserName(userUpdate.name) }
                : {}),
              ...(isNewTermsVersion ? { termsAcceptedAt: new Date() } : {}),
            },
          };
        },
      },
    },
  },
  plugins: [bearer()],
});
