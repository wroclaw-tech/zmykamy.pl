import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { APIError } from "better-auth/api";
import { bearer } from "better-auth/plugins";
import { db } from "../db";
import * as schema from "../db/schema";
import {
  DATE_FORMATS,
  LANGUAGES,
  THEME_PALETTES,
  WEEK_STARTS,
  blikPhoneSchema,
  currencySchema,
  dateFormatSchema,
  ibanSchema,
  languageSchema,
  personNameSchema,
  phoneSchema,
  termsVersionSchema,
  themePaletteSchema,
  userNameSchema,
  weekStartSchema,
} from "../schemas/user";
import { getDeviceName } from "./device-name";
import { getIpLocation } from "./geolocation";

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
  rateLimit: {
    enabled: false,
  },
  user: {
    changeEmail: {
      enabled: true,
      updateEmailWithoutVerification: true,
    },
    deleteUser: {
      enabled: true,
    },
    additionalFields: {
      firstName: {
        type: "string",
        required: false,
        validator: { input: personNameSchema.nullable() },
      },
      lastName: {
        type: "string",
        required: false,
        validator: { input: personNameSchema.nullable() },
      },
      phone: {
        type: "string",
        required: false,
        validator: { input: phoneSchema.nullable() },
      },
      blikPhone: {
        type: "string",
        required: false,
        validator: { input: blikPhoneSchema.nullable() },
      },
      iban: {
        type: "string",
        required: false,
        validator: { input: ibanSchema.nullable() },
      },
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
      language: {
        type: [...LANGUAGES],
        required: false,
        defaultValue: "pl",
        validator: { input: languageSchema },
      },
      defaultCurrency: {
        type: "string",
        required: false,
        defaultValue: "PLN",
        validator: { input: currencySchema },
      },
      dateFormat: {
        type: [...DATE_FORMATS],
        required: false,
        defaultValue: "dd.MM.yyyy",
        validator: { input: dateFormatSchema },
      },
      weekStart: {
        type: [...WEEK_STARTS],
        required: false,
        defaultValue: "monday",
        validator: { input: weekStartSchema },
      },
    },
  },
  session: {
    additionalFields: {
      deviceName: {
        type: "string",
        required: false,
        input: false,
      },
      city: {
        type: "string",
        required: false,
        input: false,
      },
      countryCode: {
        type: "string",
        required: false,
        input: false,
      },
    },
  },
  databaseHooks: {
    session: {
      create: {
        before: async (newSession, context) => {
          const { city, countryCode } = await getIpLocation(newSession.ipAddress);
          return {
            data: {
              ...newSession,
              deviceName: getDeviceName(context?.headers ?? context?.request?.headers),
              city,
              countryCode,
            },
          };
        },
      },
    },
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
