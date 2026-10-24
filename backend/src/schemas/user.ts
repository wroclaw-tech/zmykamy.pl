import { z } from "zod";

export const THEME_PALETTES = [
  "ocean",
  "beach",
  "cities",
  "mountains",
  "tropics",
  "festivals",
] as const;
export const LANGUAGES = ["pl", "en"] as const;
export const DATE_FORMATS = ["dd.MM.yyyy", "yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy"] as const;
export const WEEK_STARTS = ["monday", "sunday"] as const;

const SUPPORTED_CURRENCIES = new Set(Intl.supportedValuesOf("currency"));

const PHONE_PATTERN = /^\+[1-9]\d{6,14}$/;
const POLISH_PHONE_PATTERN = /^\+48\d{9}$/;
const IBAN_PATTERN = /^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$/;

const getWithoutSeparators = (value: string) => value.replace(/[\s\-().]/g, "");

const hasValidIbanChecksum = (iban: string) => {
  const rearranged = iban.slice(4) + iban.slice(0, 4);
  const digits = rearranged.replace(/[A-Z]/g, (letter) => String(letter.charCodeAt(0) - 55));
  let remainder = 0;
  for (const digit of digits) {
    remainder = (remainder * 10 + Number(digit)) % 97;
  }
  return remainder === 1;
};

export const userNameSchema = z.string().trim().min(1).max(60);
export const personNameSchema = z.string().trim().min(1).max(60);
export const phoneSchema = z
  .string()
  .transform(getWithoutSeparators)
  .refine((phone) => PHONE_PATTERN.test(phone), "Invalid phone number");
export const blikPhoneSchema = z
  .string()
  .transform(getWithoutSeparators)
  .refine((phone) => POLISH_PHONE_PATTERN.test(phone), "BLIK requires a +48 phone number");
export const ibanSchema = z
  .string()
  .transform((iban) => getWithoutSeparators(iban).toUpperCase())
  .refine((iban) => IBAN_PATTERN.test(iban) && hasValidIbanChecksum(iban), "Invalid IBAN");
export const themePaletteSchema = z.enum(THEME_PALETTES);
export const termsVersionSchema = z.string().trim().min(1).max(32);
export const languageSchema = z.enum(LANGUAGES);
export const currencySchema = z
  .string()
  .trim()
  .toUpperCase()
  .refine((currency) => SUPPORTED_CURRENCIES.has(currency), "Unsupported currency");
export const dateFormatSchema = z.enum(DATE_FORMATS);
export const weekStartSchema = z.enum(WEEK_STARTS);
